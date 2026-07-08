import Combine
import Foundation

/// Holds the transient rotate-colors override. When nil, the clock uses the
/// user's fixed color from SettingsStore.
final class ClockState: ObservableObject {
    @Published private(set) var paletteColor: RGBAColor?

    private var rng = SystemRandomNumberGenerator()

    func advancePalette() {
        paletteColor = ClockPalette.randomColor(differingFrom: paletteColor, using: &rng)
    }

    func clearPalette() {
        paletteColor = nil
    }
}
