import Foundation
import Combine

final class ScriptStore: ObservableObject {
    @Published private(set) var scripts: [ScriptItem] = []

    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent("teleprompter_scripts.json")
        load()
        if scripts.isEmpty {
            scripts = [ScriptItem.sample]
            persist()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([ScriptItem].self, from: data) else { return }
        scripts = decoded
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(scripts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func script(id: UUID) -> ScriptItem? {
        scripts.first(where: { $0.id == id })
    }

    @discardableResult
    func create(title: String = "", body: String = "") -> ScriptItem {
        let item = ScriptItem(title: title, body: body)
        scripts.insert(item, at: 0)
        persist()
        return item
    }

    func update(_ item: ScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.updatedAt = Date()
        scripts[index] = updated
        persist()
    }

    func delete(id: UUID) {
        scripts.removeAll(where: { $0.id == id })
        persist()
    }
}
