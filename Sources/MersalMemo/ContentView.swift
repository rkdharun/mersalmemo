import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @StateObject private var settings = AppSettings()
    @State private var isPinned = true
    @State private var isBubble = false

    var body: some View {
        Group {
            if isBubble {
                BubbleView { isBubble = false }
            } else {
                VStack(spacing: 0) {
                    FloatingHeader(isPinned: $isPinned, isBubble: $isBubble)
                    Divider().opacity(0.4)
                    EditorView(isPinned: $isPinned)
                }
                .background(Color(.windowBackgroundColor))
            }
        }
        .ignoresSafeArea()
        .background(WindowAccessor(isPinned: isPinned, isBubble: isBubble,
                                    opacity: settings.windowOpacity,
                                    bubblePosition: settings.bubblePosition))
        .environmentObject(settings)
        .onChange(of: isBubble) { newVal in
            if newVal { isPinned = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNote)) { _ in
            store.createNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectPreviousNote)) { _ in
            store.selectPreviousNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectNextNote)) { _ in
            store.selectNextNote()
        }
    }
}
