import SwiftUI
import Observation
import PersistableTimer

@Observable
final class TimerModel {
    private let persistableTimer: PersistableTimer
    var timerText: String?
    var timerState: TimerState?
    var selectedHours: Int = 0
    var selectedMinutes: Int = 0
    var selectedSeconds: Int = 0

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
            switch timerState?.status {
            case .running:
                try await persistableTimer.pause()
            case .paused:
                try await persistableTimer.resume()
            case .finished, nil:
                try await persistableTimer.start(
                    type: .timer(
                        duration: TimeInterval((selectedHours * 60 * 60) + (selectedMinutes * 60) + selectedSeconds
                    ))
                )
            }
        } catch {
            print(error)
        }
    }

    func synchronize() async {
        do {
            self.timerState = try? persistableTimer.restore().elapsedTimeAndStatus()
        } catch {
            print(error)
        }
        let dateFormatter = DateComponentsFormatter()
        dateFormatter.unitsStyle = .positional
        dateFormatter.allowedUnits = [.hour, .minute, .second]

        for await timerState in persistableTimer.timeStream {
            timerText = dateFormatter.string(from: timerState.time) ?? "00:00:00"
            self.timerState = timerState
        }
    }

    func finish() async {
        try? await persistableTimer.finish()
    }
}

struct TimerView: View {
    @Bindable var timerModel: TimerModel

    var body: some View {
        VStack {
            if let timerText = timerModel.timerText {
                Text(timerText)
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
                dataSource: .inMemory
            )
        )
    )
}
