import SwiftUI
import PersistableTimer
import Observation

@Observable
final class ContentModel {
    var isTimerPresented = false
    var isStopwatchPresented = false
    var isMultipleStopwatchPresented = false
    let persistableTimer: PersistableTimer

    init(persistableTimer: PersistableTimer) {
        self.persistableTimer = persistableTimer
    }

    func onAppear() {
        if let timerData = try? persistableTimer.getTimerData() {
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
        List {
            Text("Timer")
                .onTapGesture {
                    contentModel.isTimerPresented = true
                }
            Text("Stopwatch")
                .onTapGesture {
                    contentModel.isStopwatchPresented = true
                }
            Text("Multiple Stopwatch")
                .onTapGesture {
                    contentModel.isMultipleStopwatchPresented = true
                }
        }
        .sheet(isPresented: $contentModel.isTimerPresented) {
            TimerView(
                timerModel: TimerModel(
                    persistableTimer: contentModel.persistableTimer
                )
            )
        }
        .sheet(isPresented: $contentModel.isStopwatchPresented) {
            StopwatchView(
                stopwatchModel: StopwatchModel(
                    persistableTimer: contentModel.persistableTimer
                )
            )
        }
        .sheet(isPresented: $contentModel.isMultipleStopwatchPresented) {
            MultipleStopwatchView(
                stopwatchModel: MultipleStopwatchModel()
            )
        }
        .onAppear {
            contentModel.onAppear()
        }
    }
}

#Preview {
    ContentView(
        contentModel: ContentModel(
            persistableTimer: PersistableTimer(dataSourceType: .inMemory)
        )
    )
}
