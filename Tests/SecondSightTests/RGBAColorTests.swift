import Testing
@testable import SecondSight

@Test func parsesSixDigitHex() {
    let c = RGBAColor(hex: "#FF8800")
    #expect(c == RGBAColor(red: 1.0, green: 136.0 / 255.0, blue: 0.0, alpha: 1.0))
}

@Test func parsesEightDigitHexWithAlpha() {
    let c = RGBAColor(hex: "#FF880080")
    #expect(c?.alpha != nil)
    #expect(abs((c?.alpha ?? 0) - 128.0 / 255.0) < 0.001)
}

@Test func parsesWithoutHashPrefix() {
    #expect(RGBAColor(hex: "FF8800") != nil)
}

@Test func rejectsInvalidHex() {
    #expect(RGBAColor(hex: "") == nil)
    #expect(RGBAColor(hex: "#FFF") == nil)
    #expect(RGBAColor(hex: "#GGGGGG") == nil)
    #expect(RGBAColor(hex: "not a color") == nil)
}

@Test func hexStringRoundTrips() {
    let original = RGBAColor(hex: "#F2C464")!
    let reparsed = RGBAColor(hex: original.hexString)
    #expect(reparsed == original)
    #expect(original.hexString == "#F2C464FF")
}

@Test func initClampsComponents() {
    let c = RGBAColor(red: 2.0, green: -1.0, blue: 0.5, alpha: 9.0)
    #expect(c == RGBAColor(red: 1.0, green: 0.0, blue: 0.5, alpha: 1.0))
}
