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
        VStack {
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
