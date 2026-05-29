import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    let isPinned: Bool
    let isBubble: Bool
    let opacity: Double
    let bubblePosition: BubblePosition

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        PassthroughView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            let c = context.coordinator

            // One-time window setup
            if !c.didSetup {
                c.didSetup = true
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.minSize = NSSize(width: 50, height: 50)
            }

            // Opacity
            window.alphaValue = self.opacity

            // Pin level
            window.level = self.isPinned ? .floating : .normal
            window.collectionBehavior = self.isPinned
                ? [.canJoinAllSpaces, .fullScreenAuxiliary]
                : [.managed, .participatesInCycle]

            // Bubble ↔ full transition
            guard c.wasBubble != self.isBubble else { return }
            c.wasBubble = self.isBubble

            if self.isBubble {
                c.normalFrame = window.frame
                let sz = NSSize(width: 64, height: 64)
                let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
                let visible = screen.visibleFrame
                let margin: CGFloat = 20
                let bubbleFrame = self.bubblePosition.frame(sz: sz, in: visible, margin: margin)

                // Phase 1 — squeeze: rapidly shrink ~40% while beginning to move toward corner
                let f = window.frame
                let squishFrame = NSRect(
                    x: f.origin.x + (bubbleFrame.origin.x - f.origin.x) * 0.3,
                    y: f.origin.y + (bubbleFrame.origin.y - f.origin.y) * 0.3,
                    width: f.width * 0.38,
                    height: f.height * 0.38
                )
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.14
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    window.animator().setFrame(squishFrame, display: true)
                } completionHandler: {
                    // Phase 2 — fly: shoot into the corner
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.20
                        ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.6, 0, 1, 0.8)
                        window.animator().setFrame(bubbleFrame, display: true)
                    } completionHandler: {
                        window.isOpaque = false
                        window.backgroundColor = .clear
                    }
                }
            } else {
                let targetFrame = c.normalFrame ?? NSRect(x: 100, y: 400, width: 340, height: 480)
                window.isOpaque = true
                window.backgroundColor = .windowBackgroundColor

                // Phase 1 — pop: burst from corner to slightly beyond target (overshoot)
                let overshoot = targetFrame.insetBy(dx: -10, dy: -8)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.22
                    ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0, 0.6, 0.3, 1)
                    window.animator().setFrame(overshoot, display: true)
                } completionHandler: {
                    // Phase 2 — settle: spring back to exact frame
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.12
                        ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        window.animator().setFrame(targetFrame, display: true)
                    }
                }
            }
        }
    }

    class Coordinator {
        var didSetup = false
        var wasBubble: Bool? = nil
        var normalFrame: NSRect? = nil
    }

    private class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override var acceptsFirstResponder: Bool { false }
    }
}

extension BubblePosition {
    func frame(sz: NSSize, in visible: NSRect, margin: CGFloat) -> NSRect {
        switch self {
        case .topLeft:
            return NSRect(x: visible.minX + margin,
                          y: visible.maxY - sz.height - margin,
                          width: sz.width, height: sz.height)
        case .topRight:
            return NSRect(x: visible.maxX - sz.width - margin,
                          y: visible.maxY - sz.height - margin,
                          width: sz.width, height: sz.height)
        case .bottomLeft:
            return NSRect(x: visible.minX + margin,
                          y: visible.minY + margin,
                          width: sz.width, height: sz.height)
        case .bottomRight:
            return NSRect(x: visible.maxX - sz.width - margin,
                          y: visible.minY + margin,
                          width: sz.width, height: sz.height)
        }
    }
}
