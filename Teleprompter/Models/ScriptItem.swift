import Foundation

struct ScriptItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var body: String
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "", body: String = "", updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        let cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "未命名台词" : String(cleaned.prefix(18))
    }

    var characterCount: Int {
        body.count
    }

    static let sample = ScriptItem(
        title: "示例：开场白",
        body: """
        大家好，欢迎来到我的频道。

        今天想跟你聊一个特别实用的话题。

        （这段是示例台词，点右上角「编辑」把它换成你自己的稿子就好。）

        提词器会按你设置的速度匀速滚动，你也可以用遥控页面暂停、加速或者回到开头。

        拍摄时打开苹果原生相机，提词浮窗会一直浮在取景框上方，不会出现在录制的画面里。

        准备好了就开始吧。
        """
    )
}
