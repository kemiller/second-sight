import Testing
@testable import SecondSight

@Test func paletteHasEightColorsStartingWithSoftWhite() {
    #expect(ClockPalette.colors.count == 8)
    #expect(ClockPalette.colors[0] == .softWhite)
}

@Test func randomColorAlwaysComesFromPalette() {
    var rng = SeededRNG(seed: 1)
    for _ in 0..<100 {
        let c = ClockPalette.randomColor(differingFrom: nil, using: &rng)
        #expect(ClockPalette.colors.contains(c))
    }
}

@Test func randomColorNeverRepeatsCurrent() {
    var rng = SeededRNG(seed: 2)
    var current: RGBAColor? = nil
    for _ in 0..<100 {
        let next = ClockPalette.randomColor(differingFrom: current, using: &rng)
        #expect(next != current)
        current = next
    }
}

@Test func randomColorHandlesNonPaletteCurrent() {
    var rng = SeededRNG(seed: 3)
    let custom = RGBAColor(hex: "#123456")!
    let next = ClockPalette.randomColor(differingFrom: custom, using: &rng)
    #expect(ClockPalette.colors.contains(next))
}
