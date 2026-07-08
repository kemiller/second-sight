import AppKit

/// The app's only always-visible UI: a menu bar clock icon whose menu adapts
/// to the current snooze state.
final class StatusItemController: NSObject, NSMenuDelegate {
    private static let snoozeOptions: [(title: String, duration: TimeInterval)] = [
        ("For 15 Minutes", 15 * 60),
        ("For 30 Minutes", 30 * 60),
        ("For 1 Hour", 60 * 60),
        ("For 2 Hours", 2 * 60 * 60),
    ]

    private let statusItem: NSStatusItem
    private let snooze: SnoozeController
    private let openSettings: () -> Void

    init(snooze: SnoozeController, openSettings: @escaping () -> Void) {
        self.snooze = snooze
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refresh()
    }

    func refresh() {
        let snoozed = snooze.state != .active
        let symbol = snoozed ? "clock.badge.xmark" : "clock"
        statusItem.button?.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: snoozed ? "Second Sight (snoozed)" : "Second Sight"
        )
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        switch snooze.state {
        case .snoozed(let until):
            let label = "Snoozed until \(until.formatted(date: .omitted, time: .shortened))"
            menu.addItem(disabledItem(label))
            menu.addItem(actionItem("Resume Now", action: #selector(resumeNow)))
            menu.addItem(.separator())
        case .snoozedIndefinitely:
            menu.addItem(disabledItem("Snoozed"))
            menu.addItem(actionItem("Resume Now", action: #selector(resumeNow)))
            menu.addItem(.separator())
        case .active:
            let snoozeMenu = NSMenu()
            snoozeMenu.autoenablesItems = false
            for option in Self.snoozeOptions {
                let item = actionItem(option.title, action: #selector(snoozeFor(_:)))
                item.representedObject = option.duration
                snoozeMenu.addItem(item)
            }
            snoozeMenu.addItem(actionItem("Until I Resume", action: #selector(snoozeUntilResumed)))

            let snoozeRoot = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
            menu.addItem(snoozeRoot)
            menu.setSubmenu(snoozeMenu, for: snoozeRoot)
            menu.addItem(.separator())
        }

        menu.addItem(actionItem("Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit Second Sight", action: #selector(quit), keyEquivalent: "q"))
    }

    // MARK: - Actions

    @objc private func snoozeFor(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TimeInterval else { return }
        snooze.snooze(for: duration)
    }

    @objc private func snoozeUntilResumed() {
        snooze.snoozeIndefinitely()
    }

    @objc private func resumeNow() {
        snooze.resume()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Item helpers

    private func actionItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
