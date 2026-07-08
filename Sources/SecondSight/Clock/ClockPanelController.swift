import AppKit
import Combine
import QuartzCore
import SwiftUI

/// Owns the floating clock window. The panel is borderless, transparent,
/// click-through, joins every Space, and floats above full-screen apps.
final class ClockPanelController {
    let clockState = ClockState()

    private let panel: NSPanel
    private let hostingView: NSHostingView<ClockView>
    private let settings: SettingsStore
    private var cancellables: Set<AnyCancellable> = []

    init(settings: SettingsStore) {
        self.settings = settings
        hostingView = NSHostingView(rootView: ClockView(settings: settings, clockState: clockState))

        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hostingView

        // Text metrics change with font settings; keep the panel snug.
        settings.$fontSize.map { _ in () }
            .merge(with: settings.$fontName.map { _ in () })
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.resizeToFit() }
            .store(in: &cancellables)
    }

    var clockSize: CGSize { panel.frame.size }

    var currentOrigin: CGPoint? { panel.isVisible ? panel.frame.origin : nil }

    func moveOrShow(at origin: CGPoint) {
        if panel.isVisible {
            glide(to: origin)
        } else {
            fadeIn(at: origin)
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
    }

    private func fadeIn(at origin: CGPoint) {
        panel.setFrameOrigin(origin)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            panel.animator().alphaValue = 1
        }
    }

    private func glide(to origin: CGPoint) {
        var frame = panel.frame
        frame.origin = origin
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func resizeToFit() {
        var frame = panel.frame
        frame.size = hostingView.fittingSize
        panel.setFrame(frame, display: true)
    }
}
