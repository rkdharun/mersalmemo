import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FloatingHeader: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var settings: AppSettings
    @Binding var isPinned: Bool
    @Binding var isBubble: Bool
    @State private var showNoteList = false
    @State private var showSettings = false
    @State private var newNoteFlash = false

    var body: some View {
        HStack(spacing: 4) {
            // Note title → note picker popover
            Button { showNoteList.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundColor(newNoteFlash ? .white : .orange)
                    Text(currentTitle)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(newNoteFlash ? .orange : .primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showNoteList, arrowEdge: .bottom) {
                NoteListPopover(isPresented: $showNoteList).environmentObject(store)
            }
            .onReceive(NotificationCenter.default.publisher(for: .createNote)) { _ in
                withAnimation(.easeInOut(duration: 0.15)) { newNoteFlash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeInOut(duration: 0.2)) { newNoteFlash = false }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showNoteSearch)) { _ in
                showNoteList = true
            }

            Spacer()

            // Import .md
            HdrBtn(icon: "square.and.arrow.down") { importMarkdown() }
                .help("Import .md File")

            // Export .md
            HdrBtn(icon: "square.and.arrow.up") { exportMarkdown() }
                .help("Export as .md")

            // New note
            HdrBtn(icon: "square.and.pencil") { store.createNote() }
                .help("New Note (⌘N)")

            // Delete
            if let id = store.selectedNoteId, let note = store.note(for: id) {
                HdrBtn(icon: "trash") { store.deleteNote(note) }
                    .help("Delete Note")
            }

            // Pin toggle
            HdrBtn(icon: isPinned ? "pin.fill" : "pin", tint: isPinned ? .orange : nil) {
                isPinned.toggle()
            }
            .help(isPinned ? "Unpin (⌘⇧P)" : "Pin on Top (⌘⇧P)")
            .keyboardShortcut("p", modifiers: [.command, .shift])

            // Bubble
            HdrBtn(icon: "circle.fill", tint: .orange) { isBubble = true }
                .help("Collapse to Bubble")

            // Settings
            HdrBtn(icon: "gearshape") { showSettings.toggle() }
                .help("Settings")
                .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                    SettingsPopover().environmentObject(settings)
                }

            // Close
            HdrBtn(icon: "xmark") { NSApp.terminate(nil) }
                .help("Close")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: File operations

    private func exportMarkdown() {
        guard let id = store.selectedNoteId, let note = store.note(for: id) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.plainText]
        panel.nameFieldStringValue = "\(note.displayTitle).md"
        panel.canCreateDirectories = true
        panel.message = "Export note as Markdown"
        if panel.runModal() == .OK, let url = panel.url {
            try? note.content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func importMarkdown() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Import a Markdown file as a new note"
        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                store.createNoteWithContent(content)
            }
        }
    }

    private var currentTitle: String {
        guard let id = store.selectedNoteId, let note = store.note(for: id) else { return "Notes" }
        return note.displayTitle
    }
}

private struct HdrBtn: View {
    let icon: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(tint ?? .orange.opacity(0.75))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
