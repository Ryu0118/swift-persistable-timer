import SwiftUI
import PersistableTimer
import Observation

@Observable
final class ContentModel {
    var isTimerPresented = false
    var isStopwatchPresented = false
    let persistableTimer: PersistableTimer

    init(persistableTimer: PersistableTimer) {
        self.persistableTimer = persistableTimer
    }

    func onAppear() {
        if let timerData = persistableTimer.getTimerData() {
            switch timerData.type {
            case .stopwatch:
                isStopwatchPresented = true
            case .timer:
                isTimerPresented = true
            }
        }
    }
}

struct ContentView: View {
    @Bindable var contentModel: ContentModel

    var body: some View {
        Form {
            Text("Timer")
                .onTapGesture {
                    contentModel.isTimerPresented = true
                }
            Text("Stopwatch")
                .onTapGesture {
                    contentModel.isStopwatchPresented = true
                }
        }
        .sheet(isPresented: $contentModel.isTimerPresented) {
            TimerView(
                timerModel: .init(
                    persistableTimer: contentModel.persistableTimer
                )
            )
        }
        .sheet(isPresented: $contentModel.isStopwatchPresented) {
        }
        .onAppear {
            contentModel.onAppear()
        }
    }
}

#Preview {
    ContentView(
        contentModel: ContentModel(
            persistableTimer: PersistableTimer(dataSource: .inMemory)
        )
    )
}
