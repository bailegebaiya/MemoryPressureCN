import Cocoa

if CommandLine.arguments.contains("--print-once") {
    let snapshot = MemoryStatsProvider().capture()
    print("usedPercent=\(snapshot.usedPercent)")
    print("pressurePercent=\(snapshot.pressurePercent)")
    print("usedBytes=\(snapshot.usedBytes)")
    print("totalBytes=\(snapshot.totalBytes)")
    print("topProcesses=\(snapshot.topProcesses.count)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
