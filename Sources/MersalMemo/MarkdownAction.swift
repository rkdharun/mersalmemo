import AppKit

enum MarkdownAction {
    case bold, italic, strikethrough, inlineCode, codeBlock
    case h1, h2, h3
    case blockquote, listItem, checklist, link, image

    func apply(to tv: NSTextView) {
        switch self {
        case .bold:          wrap(tv, "**", "**")
        case .italic:        wrap(tv, "*",  "*")
        case .strikethrough: wrap(tv, "~~", "~~")
        case .inlineCode:    wrap(tv, "`",  "`")
        case .codeBlock:     insertCodeBlock(tv)
        case .h1:            prefixLine(tv, "# ")
        case .h2:            prefixLine(tv, "## ")
        case .h3:            prefixLine(tv, "### ")
        case .blockquote:    prefixLine(tv, "> ")
        case .listItem:      prefixLine(tv, "- ")
        case .checklist:     prefixLine(tv, "- [ ] ")
        case .link:          insertLink(tv)
        case .image:         break  // handled by coordinator via NSOpenPanel
        }
    }

    private func wrap(_ tv: NSTextView, _ pre: String, _ suf: String) {
        let range    = tv.selectedRange()
        let selected = (tv.string as NSString).substring(with: range)
        let inner    = selected.isEmpty ? "text" : selected
        let replacement = "\(pre)\(inner)\(suf)"

        guard tv.shouldChangeText(in: range, replacementString: replacement) else { return }
        tv.textStorage?.replaceCharacters(in: range, with: replacement)
        tv.didChangeText()

        if selected.isEmpty {
            tv.setSelectedRange(NSRange(location: range.location + pre.count, length: inner.count))
        } else {
            tv.setSelectedRange(NSRange(location: range.location + replacement.count, length: 0))
        }
    }

    private func prefixLine(_ tv: NSTextView, _ newPrefix: String) {
        let nsStr = tv.string as NSString
        let sel   = tv.selectedRange()

        // Collect all lines touched by the selection
        let selectionLineRange = nsStr.lineRange(for: sel)
        var lines: [(content: String, range: NSRange)] = []
        nsStr.enumerateSubstrings(in: selectionLineRange, options: .byLines) { line, lineRange, _, _ in
            lines.append((line ?? "", lineRange))
        }
        guard !lines.isEmpty else { return }

        let blockPrefixes = ["### ", "## ", "# ", "> ", "- [x] ", "- [✓] ", "- [ ] ", "- ", "* "]

        func stripped(_ line: String) -> String {
            for p in blockPrefixes where line.hasPrefix(p) { return String(line.dropFirst(p.count)) }
            return line
        }

        func isChecklistPrefix(_ line: String) -> Bool {
            line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [✓] ")
        }

        // Determine toggle: if ALL lines already have this prefix, remove it; otherwise apply
        let allHavePrefix = lines.allSatisfy { line in
            line.content.hasPrefix(newPrefix) ||
            (newPrefix == "- [ ] " && isChecklistPrefix(line.content))
        }

        var newLines: [String] = []
        for line in lines {
            let bare = line.content
            newLines.append(allHavePrefix ? stripped(bare) : (newPrefix + stripped(bare)))
        }

        let replacement = newLines.joined(separator: "\n")
        // lineRange(for:) includes the trailing newline; exclude it so the newline stays in the document
        let replContent = nsStr.substring(with: selectionLineRange)
        let trailingNewline = replContent.hasSuffix("\n")
        let actualReplRange = NSRange(
            location: selectionLineRange.location,
            length: trailingNewline ? selectionLineRange.length - 1 : selectionLineRange.length
        )

        guard tv.shouldChangeText(in: actualReplRange, replacementString: replacement) else { return }
        tv.textStorage?.replaceCharacters(in: actualReplRange, with: replacement)
        tv.didChangeText()

        tv.setSelectedRange(NSRange(location: actualReplRange.location, length: (replacement as NSString).length))
    }

    private func insertCodeBlock(_ tv: NSTextView) {
        let range    = tv.selectedRange()
        let selected = (tv.string as NSString).substring(with: range)

        let replacement: String
        let cursorAfter: NSRange

        if selected.isEmpty {
            // Empty block — cursor lands on the blank line inside
            replacement = "```\n\n```"
            cursorAfter = NSRange(location: range.location + 4, length: 0)
        } else {
            // Wrap selection; strip leading/trailing newlines so fences sit on their own lines
            let trimmed = selected.trimmingCharacters(in: .newlines)
            replacement = "```\n\(trimmed)\n```"
            cursorAfter = NSRange(location: range.location + replacement.count, length: 0)
        }

        guard tv.shouldChangeText(in: range, replacementString: replacement) else { return }
        tv.textStorage?.replaceCharacters(in: range, with: replacement)
        tv.didChangeText()
        tv.setSelectedRange(cursorAfter)
    }

    private func insertLink(_ tv: NSTextView) {
        let range    = tv.selectedRange()
        let selected = (tv.string as NSString).substring(with: range)
        let linkText = selected.isEmpty ? "text" : selected
        let replacement = "[\(linkText)](url)"

        guard tv.shouldChangeText(in: range, replacementString: replacement) else { return }
        tv.textStorage?.replaceCharacters(in: range, with: replacement)
        tv.didChangeText()

        let urlStart = range.location + 1 + linkText.count + 2
        tv.setSelectedRange(NSRange(location: urlStart, length: 3))
    }
}

extension Notification.Name {
    static let applyMarkdownFormat = Notification.Name("quicknotes.applyMarkdownFormat")
}
