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
    private var hideGeneration = 0

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
        hideGeneration += 1  // cancel any in-flight hide's pending orderOut
        if panel.isVisible {
            glide(to: origin)
            // A cancelled mid-fade hide leaves alpha below 1 — bring it back.
            if panel.alphaValue < 1 {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.5
                    panel.animator().alphaValue = 1
                }
            }
        } else {
            fadeIn(at: origin)
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        hideGeneration += 1
        let generation = hideGeneration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.hideGeneration == generation else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        })
    }

    private func fadeIn(at origin: CGPoint) {
        // Stomp any still-running glide so it can't drag the panel to a stale target.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().setFrame(CGRect(origin: origin, size: panel.frame.size), display: false)
        }
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
