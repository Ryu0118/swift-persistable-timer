import SwiftUI
import Observation
import PersistableTimer
import PersistableTimerText

@Observable
final class StopwatchModel {
    private let persistableTimer: PersistableTimer

    var timerState: TimerState?

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

struct StopwatchView: View {
    let stopwatchModel: StopwatchModel

    public var body: some View {
        VStack {
            Text(timerState: stopwatchModel.timerState)
                .font(.title)

            Button {
                Task {
                    await stopwatchModel.buttonTapped()
                }
            } label: {
                Text(stopwatchModel.buttonTitle)
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
    }
}
