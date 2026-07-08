import AppKit
import Combine

/// Decides *when* the clock moves and *where* to. Owns the interval timer and
/// listens for display/focus changes that warrant an immediate hop.
final class MovementEngine {
    var onMove: ((CGPoint, NSScreen) -> Void)?
    var clockSize: () -> CGSize = { .zero }
    var currentOrigin: () -> CGPoint? = { nil }

    private(set) var isRunning = false

    private let settings: SettingsStore
    private let screenLocator: FocusedScreenLocator
    private var timer: Timer?
    private var rng = SystemRandomNumberGenerator()
    private var cancellables: Set<AnyCancellable> = []

    init(settings: SettingsStore, screenLocator: FocusedScreenLocator = FocusedScreenLocator()) {
        self.settings = settings
        self.screenLocator = screenLocator

        settings.$moveInterval
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.scheduleTimer()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.relocateNow()
            }
            .store(in: &cancellables)

        // Known gap: moving focus between windows of the SAME app on different
        // screens fires no activation notification, so that case corrects on
        // the next tick instead of immediately. Detecting it would require
        // polling; not worth it for a zero-permission app.
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in self?.relocateIfFocusMovedScreens() }
            .store(in: &cancellables)
    }

    func start() {
        isRunning = true
        relocateNow()
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func relocateNow() {
        guard let screen = screenLocator.focusedScreen() else { return }
        let origin = PositionSampler.samplePosition(
            in: screen.visibleFrame,
            clockSize: clockSize(),
            previous: currentOrigin(),
            using: &rng
        )
        onMove?(origin, screen)
    }

    private func relocateIfFocusMovedScreens() {
        guard isRunning,
              let origin = currentOrigin(),
              let focused = screenLocator.focusedScreen() else { return }
        let clockScreen = NSScreen.screens.first { $0.frame.contains(origin) }
        if clockScreen != focused {
            relocateNow()
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: settings.moveInterval, repeats: true) { [weak self] _ in
            self?.relocateNow()
        }
        newTimer.tolerance = settings.moveInterval * 0.1
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
}
