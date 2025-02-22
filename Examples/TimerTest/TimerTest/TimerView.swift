import SwiftUI
import Observation
import PersistableTimer
import PersistableTimerText

@Observable
final class TimerModel {
    private let persistableTimer: PersistableTimer
    var timerState: TimerState?

    var selectedHours: Int = 0
    var selectedMinutes: Int = 0
    var selectedSeconds: Int = 0

    var duration: TimeInterval {
        TimeInterval((selectedHours * 60 * 60) + (selectedMinutes * 60) + selectedSeconds)
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

    init(persistableTimer: PersistableTimer) {
        self.persistableTimer = persistableTimer
    }

    func buttonTapped() async {
        do {
            let container = switch timerState?.status {
            case .running:
                try await persistableTimer.pause()
            case .paused:
                try await persistableTimer.resume()
            case .finished, nil:
                try await persistableTimer.start(
                    type: .timer(
                        duration: duration
                    )
                )
            }
            self.timerState = container.elapsedTimeAndStatus()
        } catch {
            print(error)
        }
    }

    /// Calls addRemainingTime(5) to extend the timer's remaining duration by 5 seconds.
    func addExtraTime() async {
        do {
            let container = try await persistableTimer.addRemainingTime(5)
            self.timerState = container.elapsedTimeAndStatus()
        } catch {
            print("Error adding remaining time: \(error)")
        }
    }

    func synchronize() async {
        timerState = try? persistableTimer.getTimerData()?.elapsedTimeAndStatus()
    }

    func finish() async {
        timerState = try? await persistableTimer.finish().elapsedTimeAndStatus()
    }
}

struct TimerView: View {
    @Bindable var timerModel: TimerModel

    var body: some View {
        VStack(spacing: 20) {
            if let timerState = timerModel.timerState {
                Text(timerState: timerState)
                    .font(.title)
            } else {
                TimePicker(
                    selectedHours: $timerModel.selectedHours,
                    selectedMinutes: $timerModel.selectedMinutes,
                    selectedSeconds: $timerModel.selectedSeconds
                )
            }
            Button {
                Task {
                    await timerModel.buttonTapped()
                }
            } label: {
                Text(timerModel.buttonTitle)
            }
            // 「Add 5 sec」ボタンは、タイマータイプ（.timer）の場合のみ表示
            if let timerState = timerModel.timerState, case .timer = timerState.type {
                Button("Add 5 sec") {
                    Task {
                        await timerModel.addExtraTime()
                    }
                }
            }
        }
        .task {
            await timerModel.synchronize()
        }
        .onDisappear {
            Task {
                await timerModel.finish()
            }
        }
    }
}

#Preview {
    TimerView(
        timerModel: TimerModel(
            persistableTimer: PersistableTimer(
                dataSourceType: .inMemory
            )
        )
    )
}
