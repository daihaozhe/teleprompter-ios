import SwiftUI

struct ScriptEditorView: View {
    let item: ScriptItem

    @EnvironmentObject private var store: ScriptStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var bodyText: String

    init(item: ScriptItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _bodyText = State(initialValue: item.body)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("给这段台词起个名字", text: $title)
                }

                Section {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 300)
                        .scrollContentBackground(.hidden)
                } header: {
                    Text("台词")
                } footer: {
                    Text("\(bodyText.count) 字。换行和空行都会保留，段落之间会自动留出间距。")
                }
            }
            .navigationTitle("编辑台词")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = item
                        updated.title = title
                        updated.body = bodyText
                        store.update(updated)
                        dismiss()
                    }
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
