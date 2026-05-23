import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusBarController()
    }
}

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 42)
    private let popover = NSPopover()
    private let monitor = MemoryMonitor()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        configureStatusItem()
        configurePopover()
        bindMonitor()
        monitor.start()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = StatusIconRenderer.image(percent: 0, level: .low)
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = "内存占用"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 430, height: 640)
        popover.contentViewController = NSHostingController(
            rootView: MemoryPanelView(
                monitor: monitor,
                onRefresh: { [weak monitor] in
                    monitor?.refresh()
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        )
    }

    private func bindMonitor() {
        monitor.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.updateStatusItem(with: snapshot)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem(with snapshot: MemorySnapshot) {
        guard let button = statusItem.button else {
            return
        }

        button.image = StatusIconRenderer.image(
            percent: snapshot.usedPercent,
            level: snapshot.pressureLevel
        )
        button.title = ""
        button.toolTip = "内存占用 \(snapshot.usedPercent)%"
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            monitor.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
