import Foundation
import Testing
@testable import SecondSight

// Suites are throwaway; domain removed on next creation. Stray plists in
// ~/Library/Preferences are prefixed com.kenmiller.secondsight.tests for easy cleanup.
private func makeDefaults() -> UserDefaults {
    let name = "com.kenmiller.secondsight.tests.SnoozeControllerTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private let epoch = Date(timeIntervalSince1970: 1_000_000)

@Test func startsActive() {
    let c = SnoozeController(defaults: makeDefaults())
    #expect(c.state == .active)
}

@Test func snoozeForDurationSetsUntilDate() {
    let c = SnoozeController(defaults: makeDefaults(), now: { epoch })
    c.snooze(for: 900)
    #expect(c.state == .snoozed(until: epoch.addingTimeInterval(900)))
}

@Test func resumeReturnsToActive() {
    let c = SnoozeController(defaults: makeDefaults(), now: { epoch })
    c.snooze(for: 900)
    c.resume()
    #expect(c.state == .active)
}

@Test func snoozeIndefinitelyHoldsUntilResume() {
    let c = SnoozeController(defaults: makeDefaults())
    c.snoozeIndefinitely()
    #expect(c.state == .snoozedIndefinitely)
    c.resume()
    #expect(c.state == .active)
}

@Test func timedSnoozeSurvivesRestart() {
    let defaults = makeDefaults()
    let c = SnoozeController(defaults: defaults, now: { epoch })
    c.snooze(for: 3600)

    let restarted = SnoozeController(defaults: defaults, now: { epoch.addingTimeInterval(60) })
    #expect(restarted.state == .snoozed(until: epoch.addingTimeInterval(3600)))
}

@Test func expiredSnoozeRestoresAsActive() {
    let defaults = makeDefaults()
    let c = SnoozeController(defaults: defaults, now: { epoch })
    c.snooze(for: 900)

    let restarted = SnoozeController(defaults: defaults, now: { epoch.addingTimeInterval(901) })
    #expect(restarted.state == .active)
}

@Test func expiredSnoozeRestoreClearsStaleKeys() {
    let defaults = makeDefaults()
    let c = SnoozeController(defaults: defaults, now: { epoch })
    c.snooze(for: 900)

    // Restoring after expiry clears the persisted keys...
    _ = SnoozeController(defaults: defaults, now: { epoch.addingTimeInterval(901) })
    #expect(defaults.object(forKey: "snoozeUntil") == nil)

    // ...so even a controller whose clock is rolled back before the old
    // deadline cannot resurrect the dead snooze.
    let rolledBack = SnoozeController(defaults: defaults, now: { epoch })
    #expect(rolledBack.state == .active)
}

@Test func indefiniteSnoozeSurvivesRestart() {
    let defaults = makeDefaults()
    SnoozeController(defaults: defaults).snoozeIndefinitely()
    #expect(SnoozeController(defaults: defaults).state == .snoozedIndefinitely)
}

@Test func resumeIsPersisted() {
    let defaults = makeDefaults()
    let c = SnoozeController(defaults: defaults, now: { epoch })
    c.snooze(for: 3600)
    c.resume()
    #expect(SnoozeController(defaults: defaults, now: { epoch }).state == .active)
}

@Test func switchingSnoozeKindsDoesNotLeakPriorStateAcrossRestart() {
    let defaults = makeDefaults()
    let c = SnoozeController(defaults: defaults, now: { epoch })
    c.snooze(for: 3600)
    c.snoozeIndefinitely()
    #expect(SnoozeController(defaults: defaults, now: { epoch }).state == .snoozedIndefinitely)

    c.snooze(for: 900)
    let restored = SnoozeController(defaults: defaults, now: { epoch })
    #expect(restored.state == .snoozed(until: epoch.addingTimeInterval(900)))
}

@Test func onChangeFiresForEachTransition() {
    let c = SnoozeController(defaults: makeDefaults(), now: { epoch })
    var seen: [SnoozeController.State] = []
    c.onChange = { seen.append($0) }
    c.snooze(for: 900)
    c.resume()
    #expect(seen == [.snoozed(until: epoch.addingTimeInterval(900)), .active])
}
