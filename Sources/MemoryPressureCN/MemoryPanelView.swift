import AppKit
import SwiftUI

struct MemoryPanelView: View {
    @ObservedObject var monitor: MemoryMonitor

    let onRefresh: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            usageSection
            processSection
            metricsSection
            footer
        }
        .frame(width: 398, height: 608, alignment: .top)
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "memorychip")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(monitor.snapshot.pressureLevel.color)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("内存占用")
                    .font(.system(size: 18, weight: .semibold))
                Text("每 2 秒自动更新")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(monitor.snapshot.pressureLevel.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(monitor.snapshot.pressureLevel.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(monitor.snapshot.pressureLevel.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(monitor.snapshot.usedPercent)%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("已用")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(formatBytes(monitor.snapshot.usedBytes)) / \(formatBytes(monitor.snapshot.totalBytes))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(monitor.snapshot.usedPercent) / 100)
                .tint(monitor.snapshot.pressureLevel.color)
                .controlSize(.large)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var metricsSection: some View {
        VStack(spacing: 7) {
            HStack {
                Text("系统细节")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("压力 \(monitor.snapshot.pressurePercent)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(monitor.snapshot.pressureLevel.color)
            }
            MetricRow(title: "已用内存", value: formatBytes(monitor.snapshot.usedBytes), symbol: "gauge.medium")
            MetricRow(title: "空闲+缓存", value: formatBytes(monitor.snapshot.availableBytes), symbol: "checkmark.circle")
            MetricRow(title: "压缩内存", value: formatBytes(monitor.snapshot.compressedBytes), symbol: "rectangle.compress.vertical")
            MetricRow(
                title: "交换空间",
                value: monitor.snapshot.swapTotalBytes == 0
                    ? formatBytes(monitor.snapshot.swapUsedBytes)
                    : "\(formatBytes(monitor.snapshot.swapUsedBytes)) / \(formatBytes(monitor.snapshot.swapTotalBytes))",
                symbol: "arrow.left.arrow.right"
            )
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("占用最高的程序")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("实际驻留内存")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if monitor.snapshot.topProcesses.isEmpty {
                Text("暂时没有读取到进程列表")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                let maxBytes = monitor.snapshot.topProcesses.map(\.residentBytes).max() ?? 1
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(monitor.snapshot.topProcesses) { process in
                            ProcessRow(process: process, maxBytes: maxBytes)
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: onRefresh) {
                Label("刷新", systemImage: "arrow.clockwise")
            }

            Button(action: openActivityMonitor) {
                Label("活动监视器", systemImage: "chart.xyaxis.line")
            }

            Spacer()

            Button(action: onQuit) {
                Label("退出", systemImage: "power")
            }
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12, weight: .medium))
    }

    private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

private struct MetricRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .frame(height: 20)
    }
}

private struct ProcessRow: View {
    let process: ProcessMemory
    let maxBytes: UInt64

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 9) {
                ProcessIcon(process: process)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 9) {
                        Text(process.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)

                        Spacer(minLength: 12)

                        Text(formatBytes(process.residentBytes))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { proxy in
                        let ratio = maxBytes == 0 ? 0 : Double(process.residentBytes) / Double(maxBytes)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.12))
                            Capsule()
                                .fill(Color.accentColor.opacity(0.55))
                                .frame(width: max(4, proxy.size.width * ratio))
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .frame(height: 36)
    }
}

private struct ProcessIcon: View {
    let process: ProcessMemory

    var body: some View {
        Image(nsImage: ProcessIconCache.shared.icon(for: process))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

@MainActor
private final class ProcessIconCache {
    static let shared = ProcessIconCache()

    private var icons: [String: NSImage] = [:]

    func icon(for process: ProcessMemory) -> NSImage {
        let key = "\(process.pid)-\(process.executablePath)"
        if let icon = icons[key] {
            return icon
        }

        let icon = resolvedIcon(for: process)
        icons[key] = icon
        return icon
    }

    private func resolvedIcon(for process: ProcessMemory) -> NSImage {
        if let runningIcon = NSRunningApplication(processIdentifier: pid_t(process.pid))?.icon {
            return runningIcon
        }

        if let bundlePath = bundlePath(from: process.executablePath) {
            return NSWorkspace.shared.icon(forFile: bundlePath)
        }

        if process.executablePath.hasPrefix("/") {
            return NSWorkspace.shared.icon(forFile: process.executablePath)
        }

        return NSWorkspace.shared.icon(for: .application)
    }

    private func bundlePath(from path: String) -> String? {
        let components = path.split(separator: "/").map(String.init)
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else {
            return nil
        }

        return "/" + components.prefix(appIndex + 1).joined(separator: "/")
    }
}

private func formatBytes(_ bytes: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .memory
    formatter.includesActualByteCount = false
    formatter.isAdaptive = true

    return formatter.string(fromByteCount: Int64(bytes))
}

extension MemoryPressureLevel {
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    var nsColor: NSColor {
        switch self {
        case .low:
            return .systemGreen
        case .medium:
            return .systemOrange
        case .high:
            return .systemRed
        }
    }
}
