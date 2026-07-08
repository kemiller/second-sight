import Combine
import Foundation

/// Single source of truth for user preferences. Every mutation persists
/// immediately; consumers react via the @Published Combine publishers.
final class SettingsStore: ObservableObject {
    static let intervalPresets: [TimeInterval] = [30, 60, 120, 300, 600, 900, 1800, 3600]
    static let fontSizeRange: ClosedRange<Double> = 24...160
    static let opacityRange: ClosedRange<Double> = 0.10...1.0

    private enum Keys {
        static let moveInterval = "moveInterval"
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let opacity = "opacity"
        static let colorHex = "colorHex"
        static let rotateColors = "rotateColors"
    }

    private enum Defaults {
        static let moveInterval: TimeInterval = 300
        static let fontSize: Double = 64
        static let fontSizeRange = SettingsStore.fontSizeRange
        static let opacity: Double = 0.35
        static let opacityRange = SettingsStore.opacityRange
    }

    @Published var moveInterval: TimeInterval {
        didSet { defaults.set(moveInterval, forKey: Keys.moveInterval) }
    }

    @Published var fontName: String? {
        didSet {
            if let fontName {
                defaults.set(fontName, forKey: Keys.fontName)
            } else {
                defaults.removeObject(forKey: Keys.fontName)
            }
        }
    }

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }

    @Published var opacity: Double {
        didSet { defaults.set(opacity, forKey: Keys.opacity) }
    }

    @Published var colorHex: String {
        didSet { defaults.set(colorHex, forKey: Keys.colorHex) }
    }

    @Published var rotateColors: Bool {
        didSet { defaults.set(rotateColors, forKey: Keys.rotateColors) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedInterval = defaults.double(forKey: Keys.moveInterval)
        moveInterval = Self.intervalPresets.contains(storedInterval)
            ? storedInterval : Defaults.moveInterval

        fontName = defaults.string(forKey: Keys.fontName)

        let storedSize = defaults.double(forKey: Keys.fontSize)
        fontSize = Defaults.fontSizeRange.contains(storedSize)
            ? storedSize : Defaults.fontSize

        let storedOpacity = defaults.double(forKey: Keys.opacity)
        opacity = Defaults.opacityRange.contains(storedOpacity)
            ? storedOpacity : Defaults.opacity

        let storedHex = defaults.string(forKey: Keys.colorHex)
        colorHex = storedHex.flatMap { RGBAColor(hex: $0) != nil ? $0 : nil }
            ?? RGBAColor.softWhite.hexString

        rotateColors = defaults.bool(forKey: Keys.rotateColors)
    }
}
