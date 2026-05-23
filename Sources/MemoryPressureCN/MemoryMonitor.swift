import Foundation

@MainActor
final class MemoryMonitor: ObservableObject {
    @Published private(set) var snapshot = MemorySnapshot.placeholder

    private let provider = MemoryStatsProvider()
    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        snapshot = provider.capture()
    }
}
