import Foundation

class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedNoteId: UUID?

    // In-flight edits: not @Published so typing doesn't trigger view re-renders
    private var pendingContent: [UUID: String] = [:]
    private var saveWorkItem: DispatchWorkItem?
    private var titleSaveWorkItem: DispatchWorkItem?
    private let storageURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("MersalMemo")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("notes.json")
        load()

        if notes.isEmpty {
            let welcome = Note(content: "Welcome to Mersal Memo\n\nStart typing to write your first note.\n\nTips:\n• ⌘N — new note\n• ⌘⇧P — pin window on top of all apps\n• Right-click a note to delete it")
            notes = [welcome]
            selectedNoteId = welcome.id
            save()
        } else {
            selectedNoteId = notes.first?.id
        }
    }

    func note(for id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    func createNote() {
        let note = Note()
        notes.insert(note, at: 0)
        selectedNoteId = note.id
        save()
    }

    // Title is updated immediately (it's @Published) but save is debounced
    func updateTitle(_ title: String, for noteId: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[idx].title = title
        notes[idx].updatedAt = Date()
        titleSaveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        titleSaveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    func selectPreviousNote() {
        guard let id = selectedNoteId,
              let idx = notes.firstIndex(where: { $0.id == id }),
              idx > 0 else { return }
        selectedNoteId = notes[idx - 1].id
    }

    func selectNextNote() {
        guard let id = selectedNoteId,
              let idx = notes.firstIndex(where: { $0.id == id }),
              idx < notes.count - 1 else { return }
        selectedNoteId = notes[idx + 1].id
    }

    func createNoteWithContent(_ content: String) {
        let note = Note(content: content)
        notes.insert(note, at: 0)
        selectedNoteId = note.id
        save()
    }

    func deleteNote(_ note: Note) {
        pendingContent.removeValue(forKey: note.id)
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes.remove(at: idx)
        selectedNoteId = notes.isEmpty ? nil : notes[min(idx, notes.count - 1)].id
        save()
    }

    // Called on every keystroke — stores content without publishing (no re-render)
    func updateContent(_ content: String, for noteId: UUID) {
        pendingContent[noteId] = content
        scheduleSave(for: noteId)
    }

    // Called before switching notes to persist any in-flight edits
    func flushPending(for noteId: UUID, content: String) {
        guard notes.firstIndex(where: { $0.id == noteId }) != nil else { return }
        pendingContent[noteId] = content
        commitPending(for: noteId)
    }

    private func commitPending(for noteId: UUID) {
        guard let content = pendingContent[noteId],
              let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[idx].content = content
        notes[idx].updatedAt = Date()
        pendingContent.removeValue(forKey: noteId)
        save()
    }

    private func scheduleSave(for noteId: UUID) {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.commitPending(for: noteId)
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data) else { return }
        notes = decoded
        selectedNoteId = notes.first?.id
    }
}
