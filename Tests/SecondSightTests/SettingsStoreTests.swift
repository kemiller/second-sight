import Foundation
import Testing
@testable import SecondSight

// Suites are throwaway; domain removed on next creation. Stray plists in
// ~/Library/Preferences are prefixed com.kenmiller.secondsight.tests for easy cleanup.
private func makeDefaults() -> UserDefaults {
    let name = "com.kenmiller.secondsight.tests.SettingsStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@Test func freshStoreUsesSpecDefaults() {
    let store = SettingsStore(defaults: makeDefaults())
    #expect(store.moveInterval == 300)
    #expect(store.fontName == nil)
    #expect(store.fontSize == 64)
    #expect(store.opacity == 0.35)
    #expect(store.colorHex == RGBAColor.softWhite.hexString)
    #expect(store.rotateColors == false)
}

@Test func mutationsPersistAcrossInstances() {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    store.moveInterval = 60
    store.fontName = "Avenir"
    store.fontSize = 96
    store.opacity = 0.5
    store.colorHex = "#7FB8E8FF"
    store.rotateColors = true

    let reloaded = SettingsStore(defaults: defaults)
    #expect(reloaded.moveInterval == 60)
    #expect(reloaded.fontName == "Avenir")
    #expect(reloaded.fontSize == 96)
    #expect(reloaded.opacity == 0.5)
    #expect(reloaded.colorHex == "#7FB8E8FF")
    #expect(reloaded.rotateColors == true)
}

@Test func settingFontNameNilPersistsAsSystem() {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    store.fontName = "Avenir"
    store.fontName = nil
    #expect(SettingsStore(defaults: defaults).fontName == nil)
}

@Test func invalidStoredValuesFallBackToDefaults() {
    let defaults = makeDefaults()
    defaults.set(-3.0, forKey: "moveInterval")       // not a preset
    defaults.set(9999.0, forKey: "fontSize")         // out of range
    defaults.set(5.0, forKey: "opacity")             // out of range
    defaults.set("garbage", forKey: "colorHex")      // unparseable

    let store = SettingsStore(defaults: defaults)
    #expect(store.moveInterval == 300)
    #expect(store.fontSize == 64)
    #expect(store.opacity == 0.35)
    #expect(store.colorHex == RGBAColor.softWhite.hexString)
}
