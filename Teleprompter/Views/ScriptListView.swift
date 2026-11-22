import SwiftUI

struct ScriptListView: View {
    @EnvironmentObject private var store: ScriptStore
    @State private var editing: ScriptItem?
    @State private var active: ScriptItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.scripts.isEmpty {
                        emptyRow
                    } else {
                        ForEach(store.scripts) { item in
                            Button {
                                active = item
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.delete(id: item.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }

                                Button {
                                    editing = item
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                } header: {
                    Text("台词")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        step(1, "点进一段台词，进入提词页")
                        step(2, "点「浮到相机上」，让提词窗口浮起来")
                        step(3, "回到桌面打开系统「相机」，窗口会盖在取景框上")
                        step(4, "在提词窗口里点播放，或提前设好倒计时")
                        Divider().opacity(0.3)
                        Text("浮窗用的是系统画中画，所以它不会出现在你录下来的画面里，画质也不受影响。窗口大小、位置可以直接用手指拖动和缩放。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("怎么用")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("提词器")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let item = store.create(title: "", body: "")
                        editing = item
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { item in
                ScriptEditorView(item: item)
                    .environmentObject(store)
            }
            .fullScreenCover(item: $active) { item in
                PrompterView(script: item)
            }
        }
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有台词")
                .font(.headline)
            Text("点右上角 + 新建一段，把稿子粘进去就行。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func row(_ item: ScriptItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(item.characterCount) 字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func step(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}
