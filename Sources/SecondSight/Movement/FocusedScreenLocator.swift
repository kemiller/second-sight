import AppKit

/// CGWindowList reports window bounds in a top-left-origin global space;
/// AppKit uses bottom-left origin of the primary screen.
enum ScreenCoordinateConverter {
    static func appKitRect(fromCGBounds bounds: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: bounds.origin.x,
            y: primaryScreenHeight - bounds.origin.y - bounds.height,
            width: bounds.width,
            height: bounds.height
        )
    }
}

/// Finds the screen the user is working on — where the frontmost app's
/// top window lives — without any TCC permission (window *bounds* are public;
/// only names/contents are gated). Falls back to the mouse screen.
final class FocusedScreenLocator {
    func focusedScreen() -> NSScreen? {
        frontmostWindowScreen() ?? mouseScreen() ?? NSScreen.main
    }

    private func frontmostWindowScreen() -> NSScreen? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // List is front-to-back; the first layer-0 window owned by the
        // frontmost app is its foreground window.
        for info in infoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pid == app.processIdentifier,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Double] else { continue }

            let cgRect = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            let rect = ScreenCoordinateConverter.appKitRect(fromCGBounds: cgRect, primaryScreenHeight: primaryHeight)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
                return screen
            }
        }
        return nil
    }

    private func mouseScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
