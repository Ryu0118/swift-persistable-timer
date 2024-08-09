import SwiftUI
import Observation
import PersistableTimer
import PersistableTimerText
import UserDefaultsEditor

@Observable
final class MultipleStopwatchModel {
    var timer1: TimerContainer
    var timer2: TimerContainer
    var timer3: TimerContainer

    var isUDEditorPresented = false

    init() {
        self.timer1 = TimerContainer(
            persistableTimer: PersistableTimer(
                id: "1",
                dataSourceType: .userDefaults(.standard),
                shouldEmitTimeStream: false
            )
        )
        self.timer2 = TimerContainer(
            persistableTimer: PersistableTimer(
                id: "2",
                dataSourceType: .userDefaults(.standard),
                shouldEmitTimeStream: false
            )
        )
        self.timer3 = TimerContainer(
            persistableTimer: PersistableTimer(
                id: "3",
                dataSourceType: .userDefaults(.standard),
                shouldEmitTimeStream: false
            )
        )
    }

    func synchronize() async {
        await timer1.synchronize()
        await timer2.synchronize()
        await timer3.synchronize()
    }

    func finish() async {
        await timer1.finish()
        await timer2.finish()
        await timer3.finish()
    }

    @Observable
    final class TimerContainer {
        let persistableTimer: PersistableTimer
        var timerState: TimerState?

        init(persistableTimer: PersistableTimer) {
            self.persistableTimer = persistableTimer
        }

        var buttonTitle: String {
            switch timerState?.status {
            case .running:
                "Stop"
            case .paused:
                "Resume"
            case .finished:
                "Finished"
            case nil:
                "Start"
            }
        }

        func buttonTapped() async {
            do {
                let container = switch timerState?.status {
                case .running:
                    try await persistableTimer.pause()
                case .paused:
                    try await persistableTimer.resume()
                case .finished, nil:
                    try await persistableTimer.start(type: .stopwatch)
                }
                self.timerState = container.elapsedTimeAndStatus()
            } catch {
                print(error)
            }
        }

        func synchronize() async {
            timerState = try? persistableTimer.getTimerData()?.elapsedTimeAndStatus()
        }

        func finish() async {
            timerState = try? await persistableTimer.finish().elapsedTimeAndStatus()
        }
    }
}

struct MultipleStopwatchView: View {
    @Bindable var stopwatchModel: MultipleStopwatchModel

    public var body: some View {
        VStack(spacing: 20) {
            VStack {
                timerView(timer: \.timer1)
                timerView(timer: \.timer2)
                timerView(timer: \.timer3)
            }
            Button("Present UserDefaultsEditor") {
                stopwatchModel.isUDEditorPresented = true
            }
        }
        .task {
            await stopwatchModel.synchronize()
        }
        .onDisappear {
            Task {
                await stopwatchModel.finish()
            }
        }
        .sheet(isPresented: $stopwatchModel.isUDEditorPresented) {
            UserDefaultsEditor(userDefaults: .standard, presentationStyle: .modal)
        }
    }

    private func timerView(timer: KeyPath<MultipleStopwatchModel, MultipleStopwatchModel.TimerContainer>) -> some View {
        VStack {
            Text(timerState: stopwatchModel[keyPath: timer].timerState)
                .font(.title)

            Button {
                Task {
                    await stopwatchModel[keyPath: timer].buttonTapped()
                    await stopwatchModel.synchronize()
                }
            } label: {
                Text(stopwatchModel[keyPath: timer].buttonTitle)
            }
        }
    }
}
