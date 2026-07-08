import CoreGraphics
import Testing
@testable import SecondSight

@Test func convertsTopLeftCGToBottomLeftAppKit() {
    // Primary screen 1000 pt tall. A CG rect at y=100 with height 200 occupies
    // rows 100–300 from the top, i.e. AppKit origin.y = 1000 - 300 = 700.
    let cg = CGRect(x: 50, y: 100, width: 400, height: 200)
    let appKit = ScreenCoordinateConverter.appKitRect(fromCGBounds: cg, primaryScreenHeight: 1000)
    #expect(appKit == CGRect(x: 50, y: 700, width: 400, height: 200))
}

@Test func convertsMenuBarAdjacentWindow() {
    let cg = CGRect(x: 0, y: 0, width: 100, height: 50) // menu-bar-adjacent window
    let appKit = ScreenCoordinateConverter.appKitRect(fromCGBounds: cg, primaryScreenHeight: 900)
    #expect(appKit.origin.y == 850)
}
