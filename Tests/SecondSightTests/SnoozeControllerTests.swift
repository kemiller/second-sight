import Foundation
import Testing
@testable import SecondSight

private func makeDefaults() -> UserDefaults {
    let name = "SnoozeTests-\(UUID().uuidString)"
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

@Test func onChangeFiresForEachTransition() {
    let c = SnoozeController(defaults: makeDefaults(), now: { epoch })
    var seen: [SnoozeController.State] = []
    c.onChange = { seen.append($0) }
    c.snooze(for: 900)
    c.resume()
    #expect(seen == [.snoozed(until: epoch.addingTimeInterval(900)), .active])
}
