import SwiftUI

@main
struct MersalMemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .accentColor(.orange)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 340, height: 260)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .createNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Previous Note") {
                    NotificationCenter.default.post(name: .selectPreviousNote, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Next Note") {
                    NotificationCenter.default.post(name: .selectNextNote, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Button("Find in Note") {
                    NotificationCenter.default.post(name: .findInNote, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Search Notes") {
                    NotificationCenter.default.post(name: .showNoteSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let createNote          = Notification.Name("mersalmemo.createNote")
    static let selectPreviousNote  = Notification.Name("mersalmemo.selectPreviousNote")
    static let selectNextNote      = Notification.Name("mersalmemo.selectNextNote")
    static let findInNote          = Notification.Name("mersalmemo.findInNote")
    static let showNoteSearch      = Notification.Name("mersalmemo.showNoteSearch")
}
