import Foundation

/// Snooze state machine. Persists across relaunches so an accidental restart
/// mid-presentation doesn't unsnooze the clock.
final class SnoozeController {
    enum State: Equatable {
        case active
        case snoozed(until: Date)
        case snoozedIndefinitely
    }

    private(set) var state: State = .active {
        didSet {
            guard state != oldValue else { return }
            persist()
            onChange?(state)
        }
    }

    var onChange: ((State) -> Void)?

    private enum Keys {
        static let snoozeUntil = "snoozeUntil"
        static let snoozeIndefinite = "snoozeIndefinite"
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private var resumeTimer: Timer?

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        restore()
    }

    func snooze(for duration: TimeInterval) {
        let until = now().addingTimeInterval(duration)
        state = .snoozed(until: until)
        scheduleResume(at: until)
    }

    func snoozeIndefinitely() {
        resumeTimer?.invalidate()
        state = .snoozedIndefinitely
    }

    func resume() {
        resumeTimer?.invalidate()
        state = .active
    }

    private func scheduleResume(at date: Date) {
        resumeTimer?.invalidate()
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.resume()
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        resumeTimer = timer
    }

    private func restore() {
        if defaults.bool(forKey: Keys.snoozeIndefinite) {
            state = .snoozedIndefinitely
        } else if let until = defaults.object(forKey: Keys.snoozeUntil) as? Date {
            if until > now() {
                state = .snoozed(until: until)
                scheduleResume(at: until)
            } else {
                // Expired while the app wasn't running — clear the stale keys
                // so a backward clock change can't resurrect a dead snooze.
                defaults.removeObject(forKey: Keys.snoozeUntil)
                defaults.set(false, forKey: Keys.snoozeIndefinite)
            }
        }
    }

    private func persist() {
        switch state {
        case .active:
            defaults.removeObject(forKey: Keys.snoozeUntil)
            defaults.set(false, forKey: Keys.snoozeIndefinite)
        case .snoozed(let until):
            defaults.set(until, forKey: Keys.snoozeUntil)
            defaults.set(false, forKey: Keys.snoozeIndefinite)
        case .snoozedIndefinitely:
            defaults.removeObject(forKey: Keys.snoozeUntil)
            defaults.set(true, forKey: Keys.snoozeIndefinite)
        }
    }
}
