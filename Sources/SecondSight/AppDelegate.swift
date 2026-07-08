import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsStore!
    private var snooze: SnoozeController!
    private var panelController: ClockPanelController!
    private var movementEngine: MovementEngine!
    private var statusItemController: StatusItemController!
    private var settingsWindowController: SettingsWindowController!
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = SettingsStore()
        snooze = SnoozeController()
        panelController = ClockPanelController(settings: settings)
        movementEngine = MovementEngine(settings: settings)
        settingsWindowController = SettingsWindowController(settings: settings)

        movementEngine.clockSize = { [weak self] in self?.panelController.clockSize ?? .zero }
        movementEngine.currentOrigin = { [weak self] in self?.panelController.currentOrigin }
        movementEngine.onMove = { [weak self] origin, _ in
            guard let self else { return }
            if self.settings.rotateColors {
                self.panelController.clockState.advancePalette()
            } else {
                self.panelController.clockState.clearPalette()
            }
            self.panelController.moveOrShow(at: origin)
        }

        statusItemController = StatusItemController(
            snooze: snooze,
            openSettings: { [weak self] in self?.settingsWindowController.show() }
        )

        snooze.onChange = { [weak self] state in self?.apply(snoozeState: state) }
        apply(snoozeState: snooze.state)

        // After font metrics change, hop once so the resized clock can't hang
        // off-screen. dropFirst(2) skips the two initial @Published emissions.
        settings.$fontSize.map { _ in () }
            .merge(with: settings.$fontName.map { _ in () })
            .dropFirst(2)
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self, self.movementEngine.isRunning else { return }
                self.movementEngine.relocateNow()
            }
            .store(in: &cancellables)
    }

    private func apply(snoozeState: SnoozeController.State) {
        switch snoozeState {
        case .active:
            movementEngine.start()
        case .snoozed, .snoozedIndefinitely:
            movementEngine.stop()
            panelController.hide()
        }
        statusItemController.refresh()
    }
}
