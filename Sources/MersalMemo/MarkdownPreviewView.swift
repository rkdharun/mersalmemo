import SwiftUI
import AppKit

struct MarkdownPreviewView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let tv = scrollView.documentView as? NSTextView else { return scrollView }
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .textBackgroundColor
        tv.textContainerInset = NSSize(width: 20, height: 18)
        tv.textContainer?.lineFragmentPadding = 0
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .textBackgroundColor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView else { return }
        let rendered = MarkdownRenderer.render(text)
        tv.textStorage?.setAttributedString(rendered)
    }
}
