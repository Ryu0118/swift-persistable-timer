import SwiftUI
import PersistableTimer

@main
struct TimerTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                contentModel: ContentModel(
                    persistableTimer: PersistableTimer(
                        dataSource: .userDefaults(.standard)
                    )
                )
            )
        }
    }
}
