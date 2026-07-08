import Foundation

/// Framework-agnostic sRGB color. Bridged to SwiftUI/AppKit in ColorBridges.swift.
struct RGBAColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }

    /// Accepts "#RRGGBB", "#RRGGBBAA", with or without "#".
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8,
              s.allSatisfy({ $0.isHexDigit }),
              let value = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        } else {
            self.init(
                red: Double((value >> 24) & 0xFF) / 255,
                green: Double((value >> 16) & 0xFF) / 255,
                blue: Double((value >> 8) & 0xFF) / 255,
                alpha: Double(value & 0xFF) / 255
            )
        }
    }

    var hexString: String {
        String(
            format: "#%02X%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded()),
            Int((alpha * 255).rounded())
        )
    }

    static let softWhite = RGBAColor(hex: "#F2F2ED")!
}

/// Curated colors for the rotate-colors mode — muted enough to stay subtle.
enum ClockPalette {
    static let colors: [RGBAColor] = [
        .softWhite,                    // soft white
        RGBAColor(hex: "#7FB8E8")!,    // sky
        RGBAColor(hex: "#7FD8A8")!,    // mint
        RGBAColor(hex: "#F2C464")!,    // amber
        RGBAColor(hex: "#B49FE8")!,    // lavender
        RGBAColor(hex: "#F2937F")!,    // coral
        RGBAColor(hex: "#6FC4C4")!,    // teal
        RGBAColor(hex: "#E88FB0")!,    // rose
    ]

    static func randomColor(
        differingFrom current: RGBAColor?,
        using rng: inout some RandomNumberGenerator
    ) -> RGBAColor {
        let candidates = colors.filter { $0 != current }
        return candidates.randomElement(using: &rng) ?? colors[0]
    }
}
