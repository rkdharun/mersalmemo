import SwiftUI

struct EditorView: View {
    @EnvironmentObject var store: NoteStore
    @Binding var isPinned: Bool
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var currentNoteId: UUID?
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if store.selectedNoteId != nil {
                // Title field
                TextField("Untitled", text: $title)
                    .font(.system(size: 17, weight: .semibold))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                    .focused($titleFocused)
                    .onChange(of: title) { newTitle in
                        guard let id = store.selectedNoteId, id == currentNoteId else { return }
                        store.updateTitle(newTitle, for: id)
                    }

                Divider()
                    .padding(.horizontal, 16)
                    .opacity(0.35)

                NoteTextEditor(text: $content)
                    .onChange(of: content) { newContent in
                        guard let id = store.selectedNoteId, id == currentNoteId else { return }
                        store.updateContent(newContent, for: id)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        if let id = store.selectedNoteId { loadNote(id) }
                    }
                    .onChange(of: store.selectedNoteId) { newId in
                        if let oldId = currentNoteId {
                            store.flushPending(for: oldId, content: content)
                        }
                        if let id = newId { loadNote(id) }
                    }

                MarkdownToolbar()

                statusBar
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Button("New Note") { store.createNote() }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            let words = content.split { $0.isWhitespace || $0.isNewline }.count
            Text("\(words) \(words == 1 ? "word" : "words")")
                .font(.system(size: 10))
                .foregroundColor(.orange.opacity(0.55))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(.windowBackgroundColor))
    }

    private func loadNote(_ id: UUID) {
        guard let note = store.note(for: id) else { return }
        title = note.title
        content = note.content
        currentNoteId = id
        if note.title.isEmpty && note.content.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                titleFocused = true
            }
        }
    }
}
