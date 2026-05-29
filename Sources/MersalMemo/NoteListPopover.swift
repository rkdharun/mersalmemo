import SwiftUI
import AppKit

struct NoteListPopover: View {
    @EnvironmentObject var store: NoteStore
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var highlightedIndex = 0

    var filtered: [Note] {
        guard !searchText.isEmpty else { return store.notes }
        return store.notes.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.7))
                NoteSearchField(
                    text: $searchText,
                    onReturn: selectHighlighted,
                    onEscape: { isPresented = false },
                    onMoveDown: { highlightedIndex = min(highlightedIndex + 1, max(0, filtered.count - 1)) },
                    onMoveUp:   { highlightedIndex = max(0, highlightedIndex - 1) }
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider()

            if filtered.isEmpty {
                Text(searchText.isEmpty ? "No notes" : "No results")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(16)
                    .frame(width: 220)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, note in
                            NoteRow(
                                note: note,
                                isSelected: store.selectedNoteId == note.id,
                                isHighlighted: idx == highlightedIndex,
                                onSelect: {
                                    store.selectedNoteId = note.id
                                    isPresented = false
                                },
                                onDelete: { store.deleteNote(note) }
                            )
                            .onHover { if $0 { highlightedIndex = idx } }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(width: 220, height: min(CGFloat(filtered.count) * 50 + 8, 280))
            }
        }
        .onChange(of: searchText) { _ in highlightedIndex = 0 }
    }

    private func selectHighlighted() {
        guard !filtered.isEmpty else { return }
        store.selectedNoteId = filtered[min(highlightedIndex, filtered.count - 1)].id
        isPresented = false
    }
}

// MARK: – Custom search field that intercepts Return / Escape / Arrow keys

private struct NoteSearchField: NSViewRepresentable {
    @Binding var text: String
    var onReturn: () -> Void
    var onEscape: () -> Void
    var onMoveDown: () -> Void
    var onMoveUp: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.delegate = context.coordinator
        tf.placeholderString = "Search notes"
        tf.isBordered = false
        tf.drawsBackground = false
        tf.font = .systemFont(ofSize: 12)
        tf.focusRingType = .none
        tf.cell?.wraps = false
        DispatchQueue.main.async { tf.window?.makeFirstResponder(tf) }
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        if tf.stringValue != text { tf.stringValue = text }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NoteSearchField
        init(_ p: NoteSearchField) { self.parent = p }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy cmd: Selector) -> Bool {
            switch cmd {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onReturn();   return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape();   return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onMoveDown(); return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onMoveUp();   return true
            default:
                return false
            }
        }
    }
}

// MARK: – Note row

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    let isHighlighted: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                if !note.previewText.isEmpty {
                    Text(note.previewText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red.opacity(0.75))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete note")
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected    ? Color.accentColor.opacity(0.15) :
                      isHighlighted ? Color.orange.opacity(0.12) :
                      isHovered     ? Color.secondary.opacity(0.08) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.08), value: isHighlighted)
    }
}
