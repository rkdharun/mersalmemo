import SwiftUI

struct LinkEditorPopover: View {
    @State private var urlText: String
    @State private var labelText: String
    let onDelete: () -> Void
    let onSave: (String, String) -> Void

    init(url: String, label: String,
         onDelete: @escaping () -> Void,
         onSave: @escaping (String, String) -> Void) {
        _urlText   = State(initialValue: url)
        _labelText = State(initialValue: label)
        self.onDelete = onDelete
        self.onSave   = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            fieldRow(title: "URL",  text: $urlText)
            Divider()
            fieldRow(title: "Text", text: $labelText)
            Divider()
            HStack {
                Button(action: onDelete) {
                    Text("Delete").foregroundColor(.red).font(.system(size: 12))
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Update") { onSave(urlText, labelText) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }

    private func fieldRow(title: String, text: Binding<String>) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 38, alignment: .leading)
                .padding(.leading, 10)
            Divider().frame(height: 26)
            TextField("", text: text)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .frame(height: 28)
    }
}
