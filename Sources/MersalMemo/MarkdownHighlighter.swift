import AppKit

struct MarkdownHighlighter {
    static let fontSize: CGFloat = 15
    static let checkboxKey  = NSAttributedString.Key("mersalmemo.checkboxState")
    static let imageURLKey  = NSAttributedString.Key("mersalmemo.imageURL")
    static let codeBlockKey = NSAttributedString.Key("mersalmemo.codeBlock")

    // Background-matching color hides text while keeping layout intact.
    private static var hiddenColor: NSColor { .textBackgroundColor }

    static func apply(to storage: NSTextStorage, wrapWidth: CGFloat = 0) {
        let s = storage.string
        guard !s.isEmpty else { return }
        let nsStr = s as NSString
        let full = NSRange(location: 0, length: nsStr.length)

        storage.beginEditing()

        // Reset base attributes
        var baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.textColor
        ]
        if wrapWidth > 0 {
            let wrapStyle = NSMutableParagraphStyle()
            wrapStyle.tailIndent = wrapWidth
            baseAttrs[.paragraphStyle] = wrapStyle
        }
        storage.setAttributes(baseAttrs, range: full)

        // ── Code blocks ───────────────────────────────────────────────
        // Tag full range so MarkdownTextView can draw the border + language label + copy button.
        applyRegex(#"```([^\n]*)\n([\s\S]*?)```"#, in: s, full: full) { m in
            let fullRange    = m.range
            let langRange    = m.range(at: 1)
            let contentRange = m.range(at: 2)
            let language     = langRange.length > 0 ? nsStr.substring(with: langRange).trimmingCharacters(in: .whitespaces) : ""

            // Tag entire block so draw code can find it
            storage.addAttribute(codeBlockKey, value: language, range: fullRange)

            // Content: monospaced, label colour
            if contentRange.length > 0 {
                storage.addAttribute(.font,
                    value: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                    range: contentRange)
                storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: contentRange)
            }

            // Opening fence line: invisible height-only spacer (gives top padding)
            let openLineRange = nsStr.lineRange(for: NSRange(location: fullRange.location, length: 0))
            storage.addAttribute(.foregroundColor, value: hiddenColor, range: openLineRange)
            let openParaStyle = NSMutableParagraphStyle()
            openParaStyle.paragraphSpacingBefore = 6
            storage.addAttribute(.paragraphStyle, value: openParaStyle, range: openLineRange)

            // Closing fence line: invisible spacer (gives bottom padding)
            let closeFenceStart = NSMaxRange(fullRange) > 0 ? NSMaxRange(fullRange) - 1 : 0
            let closeLineRange  = nsStr.lineRange(for: NSRange(location: closeFenceStart, length: 0))
            storage.addAttribute(.foregroundColor, value: hiddenColor, range: closeLineRange)
            let closeParaStyle = NSMutableParagraphStyle()
            closeParaStyle.paragraphSpacing = 6
            storage.addAttribute(.paragraphStyle, value: closeParaStyle, range: closeLineRange)
        }

        // ── Block elements (line-by-line) ─────────────────────────────
        nsStr.enumerateSubstrings(in: full, options: .byLines) { line, lineRange, _, _ in
            guard let line else { return }

            if line.hasPrefix("# ") {
                applyHeading(storage, lineRange: lineRange, prefixLen: 2, scale: 1.6)
            } else if line.hasPrefix("## ") {
                applyHeading(storage, lineRange: lineRange, prefixLen: 3, scale: 1.3)
            } else if line.hasPrefix("### ") {
                applyHeading(storage, lineRange: lineRange, prefixLen: 4, scale: 1.15)
            } else if line.hasPrefix("> ") {
                storage.addAttribute(.foregroundColor,
                    value: NSColor.systemOrange.withAlphaComponent(0.65), range: lineRange)
                let pfx = NSRange(location: lineRange.location, length: min(2, lineRange.length))
                storage.addAttribute(.foregroundColor, value: hiddenColor, range: pfx)
            } else if line == "---" || line == "___" {
                storage.addAttribute(.foregroundColor, value: NSColor.separatorColor, range: lineRange)
            } else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [✓] ") {
                applyChecklist(storage, line: line, lineRange: lineRange)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                storage.addAttribute(.foregroundColor, value: NSColor.systemTeal,
                    range: NSRange(location: lineRange.location, length: min(1, lineRange.length)))
                if lineRange.length > 1 {
                    storage.addAttribute(.foregroundColor, value: hiddenColor,
                        range: NSRange(location: lineRange.location + 1, length: 1))
                }
            }
        }

        // ── Inline elements ───────────────────────────────────────────
        applyRegex(#"\*\*[^*\n]+\*\*"#, in: s, full: full) { m in
            storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: fontSize), range: m.range)
            storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: m.range)
            hideMarkers(storage, m.range, len: 2)
        }
        applyRegex(#"__[^_\n]+__"#, in: s, full: full) { m in
            storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: fontSize), range: m.range)
            storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: m.range)
            hideMarkers(storage, m.range, len: 2)
        }

        applyRegex(#"(?<!\*)\*(?!\*)([^*\n]+)(?<!\*)\*(?!\*)"#, in: s, full: full) { m in
            let desc = NSFont.systemFont(ofSize: fontSize).fontDescriptor.withSymbolicTraits(.italic)
            if let f = NSFont(descriptor: desc, size: fontSize) {
                storage.addAttribute(.font, value: f, range: m.range)
            }
            storage.addAttribute(.foregroundColor,
                value: NSColor.systemOrange.withAlphaComponent(0.85), range: m.range)
            hideMarkers(storage, m.range, len: 1)
        }

        applyRegex(#"`[^`\n]+`"#, in: s, full: full) { m in
            storage.addAttribute(.font,
                value: NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular), range: m.range)
            storage.addAttribute(.foregroundColor, value: NSColor.systemTeal, range: m.range)
            hideMarkers(storage, m.range, len: 1)
        }

        applyRegex(#"~~[^~\n]+~~"#, in: s, full: full) { m in
            storage.addAttribute(.strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue, range: m.range)
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
            hideMarkers(storage, m.range, len: 2)
        }

        // Links — truly hide [ and ](url) with zero-size font so they take no space.
        // The label text gets a .link attribute so clicking opens the URL.
        // linkTextAttributes on the text view controls the visible label style.
        let tinyFont = NSFont.systemFont(ofSize: 0.1)
        applyRegex(#"\[([^\]\n]+)\]\(([^)\n]+)\)"#, in: s, full: full) { m in
            let labelRange = m.range(at: 1)
            let urlRange   = m.range(at: 2)
            let fullRange  = m.range

            // Attach the URL so NSTextView can open it on click
            let urlString = nsStr.substring(with: urlRange)
            if let url = URL(string: urlString) {
                storage.addAttribute(.link, value: url, range: labelRange)
            }

            // Collapse [ prefix into zero visual width
            let prefixLen = labelRange.location - fullRange.location
            if prefixLen > 0 {
                let r = NSRange(location: fullRange.location, length: prefixLen)
                storage.addAttribute(.font, value: tinyFont, range: r)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: r)
            }
            // Collapse ](url) suffix into zero visual width
            let suffixStart = NSMaxRange(labelRange)
            let suffixLen   = NSMaxRange(fullRange) - suffixStart
            if suffixLen > 0 {
                let r = NSRange(location: suffixStart, length: suffixLen)
                storage.addAttribute(.font, value: tinyFont, range: r)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: r)
            }
        }

        // Images — hide entire ![alt](url) syntax, tag the '!' with the file path
        // Only matches file paths (not data: URIs) to keep the text storage lightweight
        applyRegex(#"!\[([^\]\n]*)\]\(([^)\n]+)\)"#, in: s, full: full) { m in
            let urlRange  = m.range(at: 2)
            let fullRange = m.range

            let urlString = nsStr.substring(with: urlRange)
            guard !urlString.hasPrefix("data:") else { return }

            storage.addAttribute(imageURLKey, value: urlString,
                range: NSRange(location: fullRange.location, length: 1))

            // Hide the entire markdown syntax line visually
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: fullRange)
            storage.addAttribute(.font, value: tinyFont, range: fullRange)

            // Add paragraph spacing below to make room for the rendered image
            let lineRange = nsStr.lineRange(for: NSRange(location: fullRange.location, length: 0))
            let paraStyle = NSMutableParagraphStyle()
            paraStyle.paragraphSpacingBefore = 4
            paraStyle.paragraphSpacing = 160
            storage.addAttribute(.paragraphStyle, value: paraStyle, range: lineRange)
        }

        storage.endEditing()
    }

    // MARK: - Helpers

    private static func applyHeading(_ storage: NSTextStorage, lineRange: NSRange,
                                      prefixLen: Int, scale: CGFloat) {
        let pLen = min(prefixLen, lineRange.length)
        storage.addAttribute(.foregroundColor, value: hiddenColor,
            range: NSRange(location: lineRange.location, length: pLen))
        let contentLen = max(0, lineRange.length - pLen)
        if contentLen > 0 {
            let contentRange = NSRange(location: lineRange.location + pLen, length: contentLen)
            storage.addAttribute(.font,
                value: NSFont.boldSystemFont(ofSize: fontSize * scale), range: contentRange)
            storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: contentRange)
        }
    }

    private static func applyChecklist(_ storage: NSTextStorage, line: String, lineRange: NSRange) {
        let isChecked = line.hasPrefix("- [x] ") || line.hasPrefix("- [✓] ")
        guard lineRange.length >= 5 else { return }

        // Hide "- " (keeps layout width, matching background color)
        storage.addAttribute(.foregroundColor, value: hiddenColor,
            range: NSRange(location: lineRange.location, length: 2))

        // Make "[✓]" / "[ ]" transparent so the custom-drawn circle shows through
        storage.addAttribute(.foregroundColor, value: NSColor.clear,
            range: NSRange(location: lineRange.location + 2, length: 3))

        // Tag the "[" position with checkbox state — MarkdownTextView draws the circle here
        storage.addAttribute(checkboxKey, value: isChecked,
            range: NSRange(location: lineRange.location + 2, length: 1))

        // Hide trailing space after "]"
        if lineRange.length >= 6 {
            storage.addAttribute(.foregroundColor, value: hiddenColor,
                range: NSRange(location: lineRange.location + 5, length: 1))
        }

        // Strikethrough + dim text for checked items
        if isChecked && lineRange.length > 6 {
            let cr = NSRange(location: lineRange.location + 6, length: lineRange.length - 6)
            storage.addAttribute(.strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue, range: cr)
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: cr)
        }
    }

    private static func hideMarkers(_ storage: NSTextStorage, _ r: NSRange, len: Int) {
        let clamped = min(len, r.length / 2)
        guard clamped > 0 else { return }
        storage.addAttribute(.foregroundColor, value: hiddenColor,
            range: NSRange(location: r.location, length: clamped))
        let endLoc = NSMaxRange(r) - clamped
        if endLoc != r.location {
            storage.addAttribute(.foregroundColor, value: hiddenColor,
                range: NSRange(location: endLoc, length: clamped))
        }
    }

    private static func applyRegex(_ pattern: String, in string: String, full: NSRange,
                                    apply: (NSTextCheckingResult) -> Void) {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        re.enumerateMatches(in: string, range: full) { m, _, _ in
            guard let m else { return }
            apply(m)
        }
    }
}
