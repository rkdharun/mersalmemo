import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct NoteTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder

        let tv = MarkdownTextView()
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = tv

        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        context.coordinator.scrollView = scrollView

        tv.font = .systemFont(ofSize: MarkdownHighlighter.fontSize)
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.isRichText = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.usesFindBar = true
        tv.backgroundColor = .textBackgroundColor
        tv.textContainerInset = NSSize(width: 20, height: 18)
        tv.textContainer?.lineFragmentPadding = 0
        tv.linkTextAttributes = [
            .foregroundColor: NSColor.systemTeal,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.backgroundColor = .textBackgroundColor

        context.coordinator.setupMouseMonitor()
        context.coordinator.setupHoverMonitor(for: tv)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? MarkdownTextView else { return }
        guard tv.string != text else { return }

        let savedRanges = tv.selectedRanges
        tv.string = text

        let len = (text as NSString).length
        if len == 0 || savedRanges.isEmpty {
            tv.setSelectedRange(NSRange(location: 0, length: 0))
        } else {
            tv.selectedRanges = savedRanges.map { v in
                let r = v.rangeValue
                let loc = min(r.location, len)
                return NSValue(range: NSRange(location: loc, length: min(r.length, len - loc)))
            }
        }

        context.coordinator.scrollView = scrollView
        context.coordinator.reapplyHighlighting()

        // Don't steal focus from the title field for new empty notes
        if !text.isEmpty {
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }
    }

    // MARK: Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        private var formatObserver: Any?
        private var findObserver: Any?
        private var mouseMonitor: Any?
        private var hoverMonitor: Any?

        // Selection saved so toolbar buttons don't lose multi-line selections
        private var savedRanges: [NSValue] = []

        // Link popover state
        private var linkPopover: NSPopover?
        private var popoverLinkRange: NSRange?
        private var showTimer: Timer?
        private var hideTimer: Timer?
        private var lastHoverChar = -1

        private static let linkRE = try? NSRegularExpression(
            pattern: #"\[([^\]\n]+)\]\(([^)\n]+)\)"#)

        init(_ parent: NoteTextEditor) {
            self.parent = parent
            super.init()

            findObserver = NotificationCenter.default.addObserver(
                forName: .findInNote, object: nil, queue: .main
            ) { [weak self] _ in
                guard let tv = self?.textView else { return }
                tv.window?.makeFirstResponder(tv)
                let item = NSMenuItem()
                item.tag = 1  // NSTextFinder.Action.showFindInterface
                tv.performFindPanelAction(item)
            }

            formatObserver = NotificationCenter.default.addObserver(
                forName: .applyMarkdownFormat, object: nil, queue: nil
            ) { [weak self] note in
                guard let self,
                      let tv = self.textView,
                      let action = note.userInfo?["action"] as? MarkdownAction else { return }
                if !self.savedRanges.isEmpty { tv.selectedRanges = self.savedRanges }
                if case .link = action {
                    let sel = tv.selectedRange()
                    DispatchQueue.main.async { [weak self, weak tv] in
                        guard let self, let tv else { return }
                        self.showLinkURLInput(selection: sel, in: tv)
                    }
                } else if case .image = action {
                    DispatchQueue.main.async { [weak tv] in
                        guard let tv = tv as? MarkdownTextView else { return }
                        tv.window?.makeFirstResponder(tv)
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .heic]
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = false
                        panel.begin { result in
                            guard result == .OK, let url = panel.url else { return }
                            tv.insertImageFile(url: url)
                        }
                    }
                } else {
                    action.apply(to: tv)
                }
            }
        }

        deinit {
            if let obs = formatObserver { NotificationCenter.default.removeObserver(obs) }
            if let obs = findObserver   { NotificationCenter.default.removeObserver(obs) }
            if let mon = mouseMonitor   { NSEvent.removeMonitor(mon) }
            if let mon = hoverMonitor   { NSEvent.removeMonitor(mon) }
            showTimer?.invalidate()
            hideTimer?.invalidate()
        }

        // MARK: – Hover-to-edit link popover

        func setupHoverMonitor(for tv: NSTextView) {
            // NSTrackingArea ensures mouseMoved events are generated over the text view
            let area = NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .activeInActiveApp],
                owner: tv, userInfo: nil)
            tv.addTrackingArea(area)

            hoverMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                self?.handleMouseMoved(event)
                return event
            }
        }

        private func handleMouseMoved(_ event: NSEvent) {
            guard let tv = textView, event.window == tv.window else { return }

            // If mouse is inside the popover itself, keep it open
            if let popWin = linkPopover?.contentViewController?.view.window {
                let screenPt = event.window!.convertPoint(toScreen: event.locationInWindow)
                if popWin.frame.contains(screenPt) {
                    hideTimer?.invalidate(); hideTimer = nil
                    return
                }
            }

            let viewPt = tv.convert(event.locationInWindow, from: nil)

            // Resolve character index — exit fast if same char as last check
            guard let (charIdx, fullRange, labelRange) = linkRanges(at: viewPt, in: tv) else {
                lastHoverChar = -1
                showTimer?.invalidate(); showTimer = nil
                scheduleLinkPopoverHide()
                return
            }
            if charIdx == lastHoverChar { return }
            lastHoverChar = charIdx

            // Cancel any pending hide; start a 1.5s delay before showing the popover
            hideTimer?.invalidate(); hideTimer = nil
            showTimer?.invalidate()
            showTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self, weak tv] _ in
                guard let self, let tv else { return }
                self.showLinkPopover(fullRange: fullRange, labelRange: labelRange, in: tv)
            }
        }

        /// Returns (charIndex, fullLinkRange, labelRange) if the point is over a link's label text.
        private func linkRanges(at pt: NSPoint, in tv: NSTextView)
            -> (Int, NSRange, NSRange)? {
            guard let lm = tv.layoutManager, let tc = tv.textContainer,
                  lm.numberOfGlyphs > 0 else { return nil }

            let origin = tv.textContainerOrigin
            let cp = NSPoint(x: pt.x - origin.x, y: pt.y - origin.y)

            let glyphIdx = lm.glyphIndex(for: cp, in: tc)
            let charIdx  = lm.characterIndexForGlyph(at: glyphIdx)

            let s = tv.string
            guard !s.isEmpty, charIdx < (s as NSString).length else { return nil }

            guard let re = Coordinator.linkRE else { return nil }
            let full = NSRange(location: 0, length: (s as NSString).length)

            var result: (Int, NSRange, NSRange)? = nil
            re.enumerateMatches(in: s, range: full) { m, _, stop in
                guard let m else { return }
                let labelRange = m.range(at: 1)
                // Only trigger when cursor is specifically over the label (orange) text
                if NSLocationInRange(charIdx, labelRange) {
                    result = (charIdx, m.range, labelRange)
                    stop.pointee = true
                }
            }
            return result
        }

        private func showLinkPopover(fullRange: NSRange, labelRange: NSRange, in tv: NSTextView) {
            // Extract label and URL text from the document
            guard let re = Coordinator.linkRE else { return }
            let nsStr = tv.string as NSString
            guard NSMaxRange(fullRange) <= nsStr.length else { return }

            let fullText = nsStr.substring(with: fullRange)
            guard let m = re.firstMatch(in: fullText,
                                         range: NSRange(location: 0, length: (fullText as NSString).length))
            else { return }

            let label = (fullText as NSString).substring(with: m.range(at: 1))
            let url   = (fullText as NSString).substring(with: m.range(at: 2))

            // Avoid recreating the popover if the same link is already shown
            if let existing = popoverLinkRange,
               existing.location == fullRange.location,
               linkPopover?.isShown == true { return }

            linkPopover?.close()
            popoverLinkRange = fullRange

            // Anchor rect = bounding box of the label text in the text view
            guard let lm = tv.layoutManager, let tc = tv.textContainer else { return }
            let glyphRange = lm.glyphRange(forCharacterRange: labelRange, actualCharacterRange: nil)
            var anchorRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
            anchorRect.origin.x += tv.textContainerOrigin.x
            anchorRect.origin.y += tv.textContainerOrigin.y

            let popover = NSPopover()
            popover.behavior = .semitransient
            popover.contentViewController = NSHostingController(rootView:
                LinkEditorPopover(
                    url: url,
                    label: label,
                    onDelete: { [weak self, weak tv, weak popover] in
                        popover?.close()
                        guard let tv else { return }
                        self?.applyLinkDelete(range: fullRange, in: tv)
                    },
                    onSave: { [weak self, weak tv, weak popover] newURL, newLabel in
                        popover?.close()
                        guard let tv else { return }
                        self?.applyLinkUpdate(range: fullRange, url: newURL, label: newLabel, in: tv)
                    }
                )
            )
            popover.show(relativeTo: anchorRect, of: tv, preferredEdge: .maxY)
            linkPopover = popover
        }

        private func scheduleLinkPopoverHide() {
            guard linkPopover?.isShown == true else { return }
            hideTimer?.invalidate()
            hideTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.linkPopover?.close()
                self?.linkPopover = nil
                self?.popoverLinkRange = nil
            }
        }

        private func showLinkURLInput(selection: NSRange, in tv: NSTextView) {
            let selectedText = selection.length > 0
                ? (tv.string as NSString).substring(with: selection) : ""

            let alert = NSAlert()
            alert.messageText = "Add Link"
            alert.addButton(withTitle: "Add")
            alert.addButton(withTitle: "Cancel")

            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            field.placeholderString = "https://"
            alert.accessoryView = field
            alert.window.initialFirstResponder = field

            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let url = field.stringValue.trimmingCharacters(in: .whitespaces)
            guard !url.isEmpty else { return }

            let label = selectedText.isEmpty ? url : selectedText
            let replacement = "[\(label)](\(url))"
            guard tv.shouldChangeText(in: selection, replacementString: replacement) else { return }
            tv.textStorage?.replaceCharacters(in: selection, with: replacement)
            tv.didChangeText()
        }

        private func applyLinkDelete(range: NSRange, in tv: NSTextView) {
            let nsStr = tv.string as NSString
            guard NSMaxRange(range) <= nsStr.length else { return }
            guard tv.shouldChangeText(in: range, replacementString: "") else { return }
            tv.textStorage?.replaceCharacters(in: range, with: "")
            tv.didChangeText()
            popoverLinkRange = nil
        }

        private func applyLinkUpdate(range: NSRange, url: String, label: String, in tv: NSTextView) {
            let nsStr = tv.string as NSString
            guard NSMaxRange(range) <= nsStr.length else { return }
            let replacement = "[\(label)](\(url))"
            guard tv.shouldChangeText(in: range, replacementString: replacement) else { return }
            tv.textStorage?.replaceCharacters(in: range, with: replacement)
            tv.didChangeText()
            popoverLinkRange = nil
        }

        // MARK: – Checkbox click monitor

        func setupMouseMonitor() {
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self, let tv = self.textView,
                      event.window == tv.window else { return event }

                let viewPoint = tv.convert(event.locationInWindow, from: nil)
                guard tv.visibleRect.contains(viewPoint) else { return event }

                let origin  = tv.textContainerOrigin
                let cp      = NSPoint(x: viewPoint.x - origin.x, y: viewPoint.y - origin.y)

                guard let lm = tv.layoutManager, let tc = tv.textContainer,
                      lm.numberOfGlyphs > 0 else { return event }

                let glyphIdx = lm.glyphIndex(for: cp, in: tc)
                let charIdx  = lm.characterIndexForGlyph(at: glyphIdx)
                let nsStr    = tv.string as NSString
                guard charIdx < nsStr.length else { return event }

                let lineRange    = nsStr.lineRange(for: NSRange(location: charIdx, length: 0))
                let line         = nsStr.substring(with: lineRange)
                let offsetInLine = charIdx - lineRange.location

                guard offsetInLine <= 5,
                      line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [✓] ")
                else { return event }

                let isChecked   = line.hasPrefix("- [x] ") || line.hasPrefix("- [✓] ")
                let toggleRange = NSRange(location: lineRange.location + 3, length: 1)
                let newChar     = isChecked ? " " : "✓"
                if tv.shouldChangeText(in: toggleRange, replacementString: newChar) {
                    tv.textStorage?.replaceCharacters(in: toggleRange, with: newChar)
                    tv.didChangeText()
                }
                return nil
            }
        }

        // MARK: – NSTextViewDelegate

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let ranges = tv.selectedRanges
            if ranges.contains(where: { $0.rangeValue.length > 0 }) { savedRanges = ranges }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Escape: close find bar if visible, else do nothing
                let item = NSMenuItem()
                item.tag = 3  // NSTextFinder.Action.hideFindInterface
                textView.performFindPanelAction(item)
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                textView.insertText("  ", replacementRange: textView.selectedRange())
                return true
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                let nsStr     = textView.string as NSString
                let sel       = textView.selectedRange()
                let lineRange = nsStr.lineRange(for: NSRange(location: sel.location, length: 0))
                let line      = nsStr.substring(with: lineRange)
                guard line.hasPrefix("  ") else { return false }
                let removeRange = NSRange(location: lineRange.location, length: 2)
                if textView.shouldChangeText(in: removeRange, replacementString: "") {
                    textView.textStorage?.replaceCharacters(in: removeRange, with: "")
                    textView.didChangeText()
                }
                return true
            }
            return false
        }

        // MARK: – Highlighting

        func reapplyHighlighting() {
            guard let sv = scrollView, let tv = textView,
                  let storage = tv.textStorage else { return }
            tv.isHorizontallyResizable = false
            tv.textContainer?.widthTracksTextView = true
            sv.hasHorizontalScroller = false
            sv.autohidesScrollers = true
            let inset      = tv.textContainerInset.width
            let frameWidth = sv.frame.width > 0 ? sv.frame.width : 400
            MarkdownHighlighter.apply(to: storage, wrapWidth: frameWidth - 2 * inset)
            (tv as? MarkdownTextView)?.updateImageViews()
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            DispatchQueue.main.async { [weak self] in self?.reapplyHighlighting() }
        }
    }
}
