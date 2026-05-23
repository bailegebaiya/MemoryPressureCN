import Darwin
import Foundation

struct ProcessMemory: Identifiable, Equatable, Sendable {
    let pid: Int
    let name: String
    let executablePath: String
    let residentBytes: UInt64

    var id: Int {
        pid
    }
}

enum MemoryPressureLevel: String, Sendable {
    case low = "正常"
    case medium = "偏高"
    case high = "紧张"
}

struct MemorySnapshot: Equatable, Sendable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let availableBytes: UInt64
    let compressedBytes: UInt64
    let wiredBytes: UInt64
    let cachedBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64
    let pressureScore: Double
    let pressureLevel: MemoryPressureLevel
    let topProcesses: [ProcessMemory]
    let updatedAt: Date

    var pressurePercent: Int {
        Int((pressureScore * 100).rounded())
    }

    var usedPercent: Int {
        guard totalBytes > 0 else {
            return 0
        }

        return Int((Double(usedBytes) / Double(totalBytes) * 100).rounded())
    }

    static let placeholder = MemorySnapshot(
        totalBytes: ProcessInfo.processInfo.physicalMemory,
        usedBytes: 0,
        availableBytes: 0,
        compressedBytes: 0,
        wiredBytes: 0,
        cachedBytes: 0,
        swapUsedBytes: 0,
        swapTotalBytes: 0,
        pressureScore: 0,
        pressureLevel: .low,
        topProcesses: [],
        updatedAt: Date()
    )
}

struct MemoryStatsProvider: Sendable {
    func capture() -> MemorySnapshot {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let fallback = MemorySnapshot(
            totalBytes: totalBytes,
            usedBytes: 0,
            availableBytes: totalBytes,
            compressedBytes: 0,
            wiredBytes: 0,
            cachedBytes: 0,
            swapUsedBytes: 0,
            swapTotalBytes: 0,
            pressureScore: 0,
            pressureLevel: .low,
            topProcesses: topProcesses(limit: 12),
            updatedAt: Date()
        )

        guard let vm = readVirtualMemoryInfo() else {
            return fallback
        }

        let freeBytes = vm.bytes(for: vm.stats.free_count)
        let cachedBytes = vm.bytes(for: vm.stats.external_page_count)
        let compressedBytes = vm.bytes(for: vm.stats.compressor_page_count)
        let wiredBytes = vm.bytes(for: vm.stats.wire_count)
        let appBytes = vm.bytes(for: vm.stats.internal_page_count)
        let availableBytes = min(totalBytes, freeBytes + cachedBytes)
        let usedBytes = min(totalBytes, appBytes + wiredBytes + compressedBytes)
        let swap = readSwapUsage(fallbackUsedBytes: vm.bytes(for: vm.stats.swapped_count))
        let pressureScore = pressureScore(
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            cachedBytes: cachedBytes,
            compressedBytes: compressedBytes,
            swapUsedBytes: swap.used
        )

        return MemorySnapshot(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            availableBytes: availableBytes,
            compressedBytes: compressedBytes,
            wiredBytes: wiredBytes,
            cachedBytes: cachedBytes,
            swapUsedBytes: swap.used,
            swapTotalBytes: swap.total,
            pressureScore: pressureScore,
            pressureLevel: pressureLevel(for: pressureScore),
            topProcesses: topProcesses(limit: 12),
            updatedAt: Date()
        )
    }

    private func readVirtualMemoryInfo() -> VirtualMemoryInfo? {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return nil
        }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        return VirtualMemoryInfo(stats: stats, pageSize: UInt64(pageSize))
    }

    private func readSwapUsage(fallbackUsedBytes: UInt64) -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)

        guard result == 0 else {
            return (fallbackUsedBytes, 0)
        }

        return (usage.xsu_used, usage.xsu_total)
    }

    private func pressureScore(
        totalBytes: UInt64,
        freeBytes: UInt64,
        cachedBytes: UInt64,
        compressedBytes: UInt64,
        swapUsedBytes: UInt64
    ) -> Double {
        if let systemPressureScore = readSystemPressureScore() {
            return systemPressureScore
        }

        guard totalBytes > 0 else {
            return 0
        }

        let total = Double(totalBytes)
        let reclaimableRatio = Double(min(totalBytes, freeBytes + cachedBytes)) / total
        let compressedRatio = min(Double(compressedBytes) / total, 0.35)
        let swapRatio = min(Double(swapUsedBytes) / total, 0.35)
        let score = 1 - reclaimableRatio + compressedRatio * 0.25 + swapRatio * 0.60

        return min(max(score, 0), 1)
    }

    private func readSystemPressureScore() -> Double? {
        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/memory_pressure")
        process.arguments = ["-Q"]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let rawOutput = String(data: data, encoding: .utf8),
              let percentRange = rawOutput.range(of: #"(\d+)%"#, options: .regularExpression),
              let freePercent = Int(rawOutput[percentRange].dropLast()) else {
            return nil
        }

        let pressurePercent = min(max(100 - freePercent, 0), 100)
        return Double(pressurePercent) / 100
    }

    private func pressureLevel(for score: Double) -> MemoryPressureLevel {
        if score >= 0.86 {
            return .high
        }

        if score >= 0.70 {
            return .medium
        }

        return .low
    }

    private func topProcesses(limit: Int) -> [ProcessMemory] {
        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,rss=,comm="]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let rawOutput = String(data: data, encoding: .utf8) else {
            return []
        }

        return rawOutput
            .split(separator: "\n")
            .compactMap(parseProcessLine)
            .sorted { $0.residentBytes > $1.residentBytes }
            .prefix(limit)
            .map { $0 }
    }

    private func parseProcessLine(_ line: Substring) -> ProcessMemory? {
        let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count == 3,
              let pid = Int(parts[0]),
              let residentKilobytes = UInt64(parts[1]) else {
            return nil
        }

        let rawName = String(parts[2])
        let lastPathComponent = URL(fileURLWithPath: rawName).lastPathComponent
        let displayName = lastPathComponent
            .replacingOccurrences(of: ".app", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ProcessMemory(
            pid: pid,
            name: displayName.isEmpty ? rawName : displayName,
            executablePath: rawName,
            residentBytes: residentKilobytes * 1024
        )
    }
}

private struct VirtualMemoryInfo {
    let stats: vm_statistics64
    let pageSize: UInt64

    func bytes<T: BinaryInteger>(for pageCount: T) -> UInt64 {
        UInt64(pageCount) * pageSize
    }
}
