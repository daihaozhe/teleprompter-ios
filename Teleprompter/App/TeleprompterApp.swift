import SwiftUI

@main
struct TeleprompterApp: App {
    @StateObject private var store = ScriptStore()
    @StateObject private var settings = PrompterSettings()

    var body: some Scene {
        WindowGroup {
            ScriptListView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}
