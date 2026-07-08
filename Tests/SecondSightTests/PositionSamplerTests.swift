import CoreGraphics
import Testing
@testable import SecondSight

private let screen = CGRect(x: 0, y: 0, width: 1512, height: 944)
private let clock = CGSize(width: 220, height: 90)

@Test func staysWithinInsetBounds() {
    var rng = SeededRNG(seed: 42)
    for _ in 0..<200 {
        let p = PositionSampler.samplePosition(in: screen, clockSize: clock, previous: nil, using: &rng)
        #expect(p.x >= screen.minX + 24)
        #expect(p.y >= screen.minY + 24)
        #expect(p.x + clock.width <= screen.maxX - 24)
        #expect(p.y + clock.height <= screen.maxY - 24)
    }
}

@Test func worksOnSecondaryScreenWithNonZeroOrigin() {
    var rng = SeededRNG(seed: 11)
    let external = CGRect(x: 1512, y: -200, width: 2560, height: 1415)
    for _ in 0..<200 {
        let p = PositionSampler.samplePosition(in: external, clockSize: clock, previous: nil, using: &rng)
        #expect(p.x >= external.minX + 24)
        #expect(p.y >= external.minY + 24)
        #expect(p.x + clock.width <= external.maxX - 24)
        #expect(p.y + clock.height <= external.maxY - 24)
    }
}

@Test func hopsAtLeastMinDistanceFromPrevious() {
    var rng = SeededRNG(seed: 7)
    var previous = CGPoint(x: 100, y: 100)
    for _ in 0..<200 {
        let p = PositionSampler.samplePosition(in: screen, clockSize: clock, previous: previous, using: &rng)
        #expect(hypot(p.x - previous.x, p.y - previous.y) >= screen.width * 0.2)
        previous = p
    }
}

@Test func degenerateTinyScreenPinsToInsetOriginWithoutCrashing() {
    var rng = SeededRNG(seed: 3)
    let tiny = CGRect(x: 0, y: 0, width: 200, height: 100) // usable area smaller than the clock
    let p = PositionSampler.samplePosition(in: tiny, clockSize: clock, previous: .zero, using: &rng)
    #expect(p == CGPoint(x: tiny.minX + 24, y: tiny.minY + 24))
}

@Test func screenSmallerThanTwiceInsetPinsWithoutCrashing() {
    var rng = SeededRNG(seed: 5)
    let tiny = CGRect(x: 0, y: 0, width: 40, height: 40) // insetBy returns .null
    let p = PositionSampler.samplePosition(in: tiny, clockSize: clock, previous: nil, using: &rng)
    #expect(p == CGPoint(x: 24, y: 24))
}

@Test func zeroSizedScreenPinsWithoutCrashing() {
    var rng = SeededRNG(seed: 6)
    let p = PositionSampler.samplePosition(in: .zero, clockSize: clock, previous: .zero, using: &rng)
    #expect(p == CGPoint(x: 24, y: 24))
}

@Test func relaxesMinDistanceWhenUnsatisfiableButStaysInBounds() {
    var rng = SeededRNG(seed: 9)
    // Usable area barely fits the clock, so many candidates are near the previous point.
    let small = CGRect(x: 0, y: 0, width: 300, height: 160)
    let size = CGSize(width: 200, height: 80)
    for _ in 0..<100 {
        let p = PositionSampler.samplePosition(in: small, clockSize: size, previous: CGPoint(x: 24, y: 24), using: &rng)
        #expect(p.x >= small.minX + 24 && p.x + size.width <= small.maxX - 24)
        #expect(p.y >= small.minY + 24 && p.y + size.height <= small.maxY - 24)
    }
}
