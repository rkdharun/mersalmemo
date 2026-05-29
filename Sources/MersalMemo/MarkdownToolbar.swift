import SwiftUI

struct MarkdownToolbar: View {
    var body: some View {
        HStack(spacing: 1) {
            // Inline styles
            FmtBtn("bold",           tip: "Bold (⌘B)",          .bold)
            FmtBtn("italic",         tip: "Italic (⌘I)",         .italic)
            FmtBtn("strikethrough",  tip: "Strikethrough",        .strikethrough)
            FmtBtn("chevron.left.forwardslash.chevron.right",
                                     tip: "Inline Code",          .inlineCode)
            FmtBtn("square.filled.on.square",
                                     tip: "Code Block",           .codeBlock)

            sep

            // Headings
            TxtBtn("H1", tip: "Heading 1", .h1)
            TxtBtn("H2", tip: "Heading 2", .h2)
            TxtBtn("H3", tip: "Heading 3", .h3)

            sep

            // Block
            FmtBtn("text.quote",          tip: "Blockquote",  .blockquote)
            FmtBtn("list.bullet",          tip: "List Item",   .listItem)
            FmtBtn("checklist",            tip: "Checklist",   .checklist)
            FmtBtn("link",                 tip: "Link",        .link)
            FmtBtn("photo",                tip: "Insert Image", .image)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .clipped()
        .frame(height: 30)
        .background(Color(.windowBackgroundColor))
        .overlay(Divider(), alignment: .top)
    }

    private var sep: some View {
        Divider().frame(height: 14).padding(.horizontal, 4)
    }
}

// Icon button
private struct FmtBtn: View {
    let icon: String
    let tip: String
    let action: MarkdownAction

    init(_ icon: String, tip: String, _ action: MarkdownAction) {
        self.icon = icon; self.tip = tip; self.action = action
    }

    var body: some View {
        Button { post(action) } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.orange.opacity(0.8))
        .help(tip)
    }
}

// Text-label button (H1 / H2 / H3)
private struct TxtBtn: View {
    let label: String
    let tip: String
    let action: MarkdownAction

    init(_ label: String, tip: String, _ action: MarkdownAction) {
        self.label = label; self.tip = tip; self.action = action
    }

    var body: some View {
        Button { post(action) } label: {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.orange.opacity(0.8))
        .help(tip)
    }
}

private func post(_ action: MarkdownAction) {
    NotificationCenter.default.post(
        name: .applyMarkdownFormat,
        object: nil,
        userInfo: ["action": action]
    )
}
