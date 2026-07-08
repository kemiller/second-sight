import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var launchAtLogin = false
    @State private var loginItemError: String?

    // SMAppService needs a real .app bundle; `swift run` executes a bare binary.
    private var isBundledApp: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    var body: some View {
        Form {
            Section("Movement") {
                Picker("Move every", selection: $settings.moveInterval) {
                    ForEach(SettingsStore.intervalPresets, id: \.self) { interval in
                        Text(Self.intervalLabel(interval)).tag(interval)
                    }
                }
            }

            Section("Appearance") {
                Picker("Font", selection: $settings.fontName) {
                    Text("System").tag(String?.none)
                    ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { family in
                        Text(family).tag(String?.some(family))
                    }
                }

                LabeledContent("Size") {
                    Slider(value: $settings.fontSize, in: 24...160)
                    Text("\(Int(settings.fontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }

                LabeledContent("Opacity") {
                    Slider(value: $settings.opacity, in: 0.1...1.0)
                    Text("\(Int(settings.opacity * 100)) %")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }

                LabeledContent("Color") {
                    HStack(spacing: 6) {
                        ForEach(Array(ClockPalette.colors.enumerated()), id: \.offset) { _, swatch in
                            Button {
                                settings.colorHex = swatch.hexString
                            } label: {
                                Circle()
                                    .fill(swatch.swiftUIColor)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().strokeBorder(.secondary.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
                        }
                        ColorPicker("", selection: colorBinding)
                            .labelsHidden()
                    }
                }

                Toggle("Rotate colors on each move", isOn: $settings.rotateColors)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .disabled(!isBundledApp)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if !isBundledApp {
                    Text("Available when running the installed app (Scripts/build-app.sh --install).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if isBundledApp {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { (RGBAColor(hex: settings.colorHex) ?? .softWhite).swiftUIColor },
            set: { newValue in
                if let rgba = RGBAColor(color: newValue) {
                    settings.colorHex = rgba.hexString
                }
            }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        guard (service.status == .enabled) != enabled else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = service.status == .enabled
        }
    }

    static func intervalLabel(_ interval: TimeInterval) -> String {
        if interval < 60 { return "\(Int(interval)) seconds" }
        if interval == 60 { return "1 minute" }
        return "\(Int(interval / 60)) minutes"
    }
}
