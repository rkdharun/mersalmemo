import AppKit

class MarkdownTextView: NSTextView {

    // Image views keyed by character location
    private var imageViews: [Int: NSImageView] = [:]
    // Loaded image cache keyed by URL string to avoid re-reading on every highlight pass
    private var imageCache: [String: NSImage] = [:]
    // Copy buttons keyed by code block start location
    private var copyButtons: [Int: NSButton] = [:]
    // Code block content ranges keyed by start location (for copy action)
    private var codeRanges: [Int: NSRange] = [:]

    // App Support directory where pasted images are saved
    private static let imageDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MersalMemo/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override func draw(_ dirtyRect: NSRect) {
        drawCodeBlockDecorations(in: dirtyRect)
        super.draw(dirtyRect)
        drawCheckboxes(in: dirtyRect)
    }

    // Called after every highlight pass
    func updateImageViews() {
        guard let lm = layoutManager,
              let tc = textContainer,
              let storage = textStorage else { return }

        var seenLocations = Set<Int>()
        let full = NSRange(location: 0, length: storage.length)

        storage.enumerateAttribute(MarkdownHighlighter.imageURLKey, in: full, options: []) { value, range, _ in
            guard let urlString = value as? String else { return }
            let loc = range.location
            seenLocations.insert(loc)

            let image = cachedImage(for: urlString)

            let iv = imageViews[loc] ?? {
                let v = NSImageView()
                v.imageScaling = .scaleProportionallyUpOrDown
                addSubview(v)
                imageViews[loc] = v
                return v
            }()

            if let image {
                iv.image = image
                iv.isHidden = false
                positionImageView(iv, atCharLoc: loc, image: image, lm: lm, tc: tc)
            } else {
                iv.isHidden = true
            }
        }

        // Remove stale views
        for (loc, iv) in imageViews where !seenLocations.contains(loc) {
            iv.removeFromSuperview()
            imageViews.removeValue(forKey: loc)
        }
        updateCodeButtons()
    }

    private func cachedImage(for urlString: String) -> NSImage? {
        if let cached = imageCache[urlString] { return cached }
        let image = NSImage(contentsOf: URL(fileURLWithPath: urlString))
            ?? URL(string: urlString).flatMap { NSImage(contentsOf: $0) }
        if let image { imageCache[urlString] = image }
        return image
    }

    private func positionImageView(_ iv: NSImageView, atCharLoc loc: Int,
                                   image: NSImage, lm: NSLayoutManager, tc: NSTextContainer) {
        guard let storage = textStorage, loc < storage.length else { iv.isHidden = true; return }
        let glyphRange = lm.glyphRange(forCharacterRange: NSRange(location: loc, length: 1),
                                       actualCharacterRange: nil)
        var lineRect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        let origin = textContainerOrigin
        lineRect.origin.x += origin.x
        lineRect.origin.y += origin.y

        let maxW = max(frame.width - textContainerInset.width * 2, 100)
        let maxH: CGFloat = 200
        let ratio = image.size.width > 0 ? image.size.height / image.size.width : 1
        let w = min(maxW, image.size.width)
        let h = min(maxH, w * ratio)

        iv.frame = NSRect(x: lineRect.origin.x, y: lineRect.maxY + 4, width: w, height: h)
    }

    // MARK: – Code block decoration

    private var isDarkMode: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
    }

    private func drawCodeBlockDecorations(in dirtyRect: NSRect) {
        guard let lm = layoutManager, let tc = textContainer,
              let storage = textStorage else { return }
        let origin = textContainerOrigin
        let full   = NSRange(location: 0, length: storage.length)

        storage.enumerateAttribute(MarkdownHighlighter.codeBlockKey, in: full, options: []) { value, range, _ in
            guard value != nil else { return }
            let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var blockRect  = CGRect.null
            lm.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, _, _ in
                blockRect = blockRect.isNull ? rect : blockRect.union(rect)
            }
            guard !blockRect.isNull else { return }
            blockRect.origin.x += origin.x
            blockRect.origin.y += origin.y

            let padH: CGFloat = 2; let padV: CGFloat = 4
            blockRect = blockRect.insetBy(dx: -padH, dy: -padV)

            // Only redraw what's in the dirty rect
            guard blockRect.intersects(dirtyRect) else { return }

            // Background
            let bg = isDarkMode
                ? NSColor(red:0.11, green:0.13, blue:0.18, alpha:1)
                : NSColor(red:0.95, green:0.96, blue:0.98, alpha:1)
            let path = NSBezierPath(roundedRect: blockRect, xRadius: 7, yRadius: 7)
            bg.setFill(); path.fill()

            // Border
            let borderColor = isDarkMode
                ? NSColor.white.withAlphaComponent(0.08)
                : NSColor.black.withAlphaComponent(0.08)
            borderColor.setStroke(); path.lineWidth = 1; path.stroke()

            // Left accent stripe
            let stripe = NSRect(x: blockRect.minX, y: blockRect.minY + 7,
                                width: 3, height: blockRect.height - 14)
            let stripePath = NSBezierPath(roundedRect: stripe, xRadius: 1.5, yRadius: 1.5)
            NSColor.systemBlue.withAlphaComponent(0.75).setFill()
            stripePath.fill()
        }
    }

    func updateCodeButtons() {
        guard let lm = layoutManager, let tc = textContainer,
              let storage = textStorage else { return }
        let origin = textContainerOrigin
        let full   = NSRange(location: 0, length: storage.length)
        var seenLocs = Set<Int>()

        storage.enumerateAttribute(MarkdownHighlighter.codeBlockKey, in: full, options: []) { value, range, _ in
            guard let language = value as? String else { return }
            let loc = range.location
            seenLocs.insert(loc)
            codeRanges[loc] = range

            let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var blockRect  = CGRect.null
            lm.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, _, _ in
                blockRect = blockRect.isNull ? rect : blockRect.union(rect)
            }
            guard !blockRect.isNull else { return }
            blockRect.origin.x += origin.x
            blockRect.origin.y += origin.y
            blockRect = blockRect.insetBy(dx: -2, dy: -4)

            // Language label (static NSTextField)
            let labelKey = -(loc + 1)
            if !language.isEmpty {
                let lbl = copyButtons[labelKey] as? NSTextField ?? {
                    let f = NSTextField(labelWithString: "")
                    f.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
                    f.textColor = .secondaryLabelColor
                    f.backgroundColor = .clear
                    f.isBezeled = false
                    addSubview(f)
                    // reuse copyButtons dict slot with negative key
                    copyButtons[labelKey] = f as? NSButton
                    return f
                }()
                lbl.stringValue = language
                let lblSize = lbl.fittingSize
                lbl.frame = NSRect(x: blockRect.maxX - lblSize.width - 44,
                                   y: blockRect.maxY - lblSize.height - 5,
                                   width: lblSize.width, height: lblSize.height)
            }

            // Copy button
            let btn = copyButtons[loc] ?? {
                let b = NSButton(title: "Copy", target: self, action: #selector(copyCodeBlock(_:)))
                b.bezelStyle = .inline
                b.controlSize = .small
                b.font = NSFont.systemFont(ofSize: 10, weight: .medium)
                addSubview(b)
                copyButtons[loc] = b
                return b
            }()
            btn.tag = loc
            let btnSize = btn.fittingSize
            btn.frame = NSRect(x: blockRect.maxX - btnSize.width - 6,
                               y: blockRect.maxY - btnSize.height - 3,
                               width: btnSize.width, height: btnSize.height)
        }

        // Remove stale buttons
        for (loc, view) in copyButtons where !seenLocs.contains(loc) && !seenLocs.contains(-(loc + 1)) {
            view.removeFromSuperview()
            copyButtons.removeValue(forKey: loc)
            codeRanges.removeValue(forKey: loc)
        }
    }

    @objc private func copyCodeBlock(_ sender: NSButton) {
        guard let storage = textStorage, let range = codeRanges[sender.tag] else { return }
        let nsStr = storage.string as NSString
        guard NSMaxRange(range) <= nsStr.length else { return }
        var lines = nsStr.substring(with: range).components(separatedBy: "\n")
        // Strip opening fence line (```) and closing fence line
        if lines.first?.hasPrefix("```") == true { lines.removeFirst() }
        while lines.last?.trimmingCharacters(in: .whitespaces) == "```"
           || lines.last?.trimmingCharacters(in: .whitespaces) == "" {
            let t = lines.removeLast().trimmingCharacters(in: .whitespaces)
            if t == "```" { break }
        }
        let content = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        let orig = sender.title
        sender.title = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { sender.title = orig }
    }

    // MARK: – Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadItem(withDataConformingToTypes: imageUTTypes) { return .copy }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let url = pb.readObjects(forClasses: [NSURL.self],
                                    options: [.urlReadingFileURLsOnly: true,
                                              .urlReadingContentsConformToTypes: imageUTTypes])?.first as? URL {
            insertImageFile(url: url)
            return true
        }
        if let img = NSImage(pasteboard: pb) {
            saveAndInsertImage(img)
            return true
        }
        return super.performDragOperation(sender)
    }

    private var imageUTTypes: [String] {
        ["public.png", "public.jpeg", "public.tiff", "public.gif",
         "public.heic", "com.compuserve.gif"]
    }

    // MARK: – Paste override

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let img = NSImage(pasteboard: pb) {
            saveAndInsertImage(img)
            return
        }
        super.paste(sender)
    }

    // MARK: – Insert helpers

    func insertImageFile(url: URL) {
        insertMarkdownImage("![image](\(url.path))\n")
    }

    // Saves image to Application Support and inserts a file path reference (never base64).
    func saveAndInsertImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }

        let filename = UUID().uuidString + ".png"
        let dest = Self.imageDir.appendingPathComponent(filename)

        do {
            try png.write(to: dest)
        } catch {
            return
        }

        insertMarkdownImage("![image](\(dest.path))\n")
    }

    private func insertMarkdownImage(_ markdown: String) {
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: markdown) else { return }
        textStorage?.replaceCharacters(in: range, with: markdown)
        didChangeText()
    }

    // MARK: – Checkbox drawing

    private func drawCheckboxes(in dirtyRect: NSRect) {
        guard let lm = layoutManager,
              let tc = textContainer,
              let storage = textStorage else { return }

        let origin = textContainerOrigin
        // Convert dirtyRect from view coordinates to text-container coordinates
        var dirtyInContainer = dirtyRect
        dirtyInContainer.origin.x -= origin.x
        dirtyInContainer.origin.y -= origin.y
        let visibleGlyphRange = lm.glyphRange(forBoundingRect: dirtyInContainer, in: tc)
        let visibleCharRange  = lm.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        storage.enumerateAttribute(
            MarkdownHighlighter.checkboxKey,
            in: visibleCharRange,
            options: []
        ) { value, range, _ in
            guard let isChecked = value as? Bool else { return }

            let spanRange  = NSRange(location: range.location, length: min(3, storage.length - range.location))
            let glyphRange = lm.glyphRange(forCharacterRange: spanRange, actualCharacterRange: nil)
            var lineRect   = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
            lineRect.origin.x += origin.x
            lineRect.origin.y += origin.y

            let sz: CGFloat  = min(lineRect.height * 0.68, 14)
            let circleRect   = CGRect(
                x: lineRect.origin.x + (lineRect.width - sz) / 2,
                y: lineRect.origin.y + (lineRect.height - sz) / 2,
                width: sz, height: sz
            )

            if isChecked {
                NSColor.systemTeal.setFill()
                NSBezierPath(ovalIn: circleRect).fill()

                let path = NSBezierPath()
                let s = sz * 0.22
                let cx = circleRect.midX, cy = circleRect.midY
                path.move(to: NSPoint(x: cx - s,       y: cy - s * 0.05))
                path.line(to: NSPoint(x: cx - s * 0.1, y: cy - s * 0.85))
                path.line(to: NSPoint(x: cx + s,       y: cy + s * 0.75))
                NSColor.white.setStroke()
                path.lineWidth     = max(sz * 0.14, 1.4)
                path.lineCapStyle  = .round
                path.lineJoinStyle = .round
                path.stroke()
            } else {
                let path = NSBezierPath(ovalIn: circleRect.insetBy(dx: 0.75, dy: 0.75))
                NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
        }
    }
}
