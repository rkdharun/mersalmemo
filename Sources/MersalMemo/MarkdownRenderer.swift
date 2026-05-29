import AppKit

// Renders markdown to NSAttributedString for the preview panel (strips markers, applies visual styles)
struct MarkdownRenderer {
    static let base: CGFloat = 15

    static func render(_ text: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        var lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("```") {
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                out.append(codeBlock(code.joined(separator: "\n")))
            } else {
                out.append(renderLine(line))
            }
            if i < lines.count - 1 { out.append(.init(string: "\n")) }
            i += 1
        }
        return out
    }

    // MARK: Block elements

    private static func renderLine(_ line: String) -> NSAttributedString {
        if line.hasPrefix("# ")  { return heading(inline(String(line.dropFirst(2))), size: base * 1.6) }
        if line.hasPrefix("## ") { return heading(inline(String(line.dropFirst(3))), size: base * 1.3) }
        if line.hasPrefix("### "){ return heading(inline(String(line.dropFirst(4))), size: base * 1.15) }
        if line.hasPrefix("> ")  { return blockquote(String(line.dropFirst(2))) }
        if line == "---" || line == "***" || line == "___" { return hr() }
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return listItem(inline(String(line.dropFirst(2))), bullet: "•")
        }
        if let (num, text) = orderedMatch(line) {
            return listItem(inline(text), bullet: "\(num).")
        }
        return inline(line)
    }

    private static func heading(_ content: NSAttributedString, size: CGFloat) -> NSAttributedString {
        let a = NSMutableAttributedString(attributedString: content)
        a.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: size),
                       range: NSRange(location: 0, length: a.length))
        return a
    }

    private static func blockquote(_ text: String) -> NSAttributedString {
        let r = NSMutableAttributedString(string: "│  ", attributes: [
            .font: NSFont.systemFont(ofSize: base),
            .foregroundColor: NSColor.systemOrange
        ])
        r.append(inline(text, color: .secondaryLabelColor))
        return r
    }

    private static func hr() -> NSAttributedString {
        NSAttributedString(string: "────────────────────────", attributes: [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.separatorColor
        ])
    }

    private static func listItem(_ content: NSAttributedString, bullet: String) -> NSAttributedString {
        let r = NSMutableAttributedString(string: "\(bullet)  ", attributes: [
            .font: NSFont.systemFont(ofSize: base),
            .foregroundColor: NSColor.systemOrange
        ])
        r.append(content)
        return r
    }

    private static func codeBlock(_ code: String) -> NSAttributedString {
        NSAttributedString(string: code, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: base - 1, weight: .regular),
            .foregroundColor: NSColor.systemTeal
        ])
    }

    // MARK: Inline elements (strips markers, applies styles)

    static func inline(_ text: String, color: NSColor = .textColor) -> NSAttributedString {
        struct Span {
            let range: Range<String.Index>
            let display: String
            let attrs: [NSAttributedString.Key: Any]
        }

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: base),
            .foregroundColor: color
        ]
        let boldFont = NSFont.boldSystemFont(ofSize: base)
        let monoFont = NSFont.monospacedSystemFont(ofSize: base - 1, weight: .regular)
        let italicDesc = NSFont.systemFont(ofSize: base).fontDescriptor.withSymbolicTraits(.italic)
        let italicFont = NSFont(descriptor: italicDesc, size: base) ?? NSFont.systemFont(ofSize: base)

        let patterns: [(String, (String) -> [NSAttributedString.Key: Any])] = [
            (#"\*\*(.+?)\*\*"#,     { _ in [.font: boldFont] }),
            (#"__(.+?)__"#,          { _ in [.font: boldFont] }),
            (#"~~(.+?)~~"#,          { _ in [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                             .foregroundColor: NSColor.secondaryLabelColor as Any] }),
            (#"`([^`]+)`"#,          { _ in [.font: monoFont, .foregroundColor: NSColor.systemTeal as Any] }),
            (#"\[(.+?)\]\(.+?\)"#,   { _ in [.foregroundColor: NSColor.linkColor as Any] }),
            (#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, { _ in [.font: italicFont] }),
            (#"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#,      { _ in [.font: italicFont] }),
        ]

        var spans: [Span] = []
        for (pattern, makeAttrs) in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            re.enumerateMatches(in: text, range: nsRange) { m, _, _ in
                guard let m, let range = Range(m.range, in: text) else { return }
                if spans.contains(where: { $0.range.overlaps(range) }) { return }
                let display: String
                if m.numberOfRanges > 1, let cr = Range(m.range(at: 1), in: text) {
                    display = String(text[cr])
                } else {
                    display = String(text[range])
                }
                var attrs = baseAttrs
                makeAttrs(display).forEach { attrs[$0.key] = $0.value }
                spans.append(Span(range: range, display: display, attrs: attrs))
            }
        }

        spans.sort { $0.range.lowerBound < $1.range.lowerBound }

        let result = NSMutableAttributedString()
        var pos = text.startIndex
        for span in spans {
            if pos < span.range.lowerBound {
                result.append(.init(string: String(text[pos..<span.range.lowerBound]), attributes: baseAttrs))
            }
            result.append(.init(string: span.display, attributes: span.attrs))
            pos = span.range.upperBound
        }
        if pos < text.endIndex {
            result.append(.init(string: String(text[pos...]), attributes: baseAttrs))
        }
        return result
    }

    private static func orderedMatch(_ line: String) -> (Int, String)? {
        guard let re = try? NSRegularExpression(pattern: #"^(\d+)\. (.+)$"#) else { return nil }
        let r = NSRange(line.startIndex..., in: line)
        guard let m = re.firstMatch(in: line, range: r), m.numberOfRanges >= 3,
              let nr = Range(m.range(at: 1), in: line),
              let tr = Range(m.range(at: 2), in: line) else { return nil }
        return (Int(line[nr]) ?? 1, String(line[tr]))
    }
}
