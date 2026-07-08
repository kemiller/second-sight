import AppKit
import SwiftUI

struct ClockView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var clockState: ClockState

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(ClockView.timeString(for: context.date))
                .font(ClockView.font(name: settings.fontName, size: settings.fontSize))
                .foregroundStyle(displayColor)
                .shadow(color: .black.opacity(0.55), radius: max(2, settings.fontSize / 16), y: 1)
                .padding(settings.fontSize / 8)
        }
        .opacity(settings.opacity)
        .fixedSize()
    }

    private var displayColor: Color {
        let rgba = (settings.rotateColors ? clockState.paletteColor : nil)
            ?? RGBAColor(hex: settings.colorHex)
            ?? .softWhite
        return rgba.swiftUIColor
    }

    /// HH:MM or h:mm AM/PM — follows the system 12/24-hour setting.
    static func timeString(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func font(name: String?, size: Double) -> Font {
        if let name, NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .semibold, design: .rounded)
    }
}
