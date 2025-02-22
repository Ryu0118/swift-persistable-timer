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

    /// Calls addElapsedTime(5) to increase the stopwatch's elapsed time by 5 seconds.
    func addExtraElapsedTime() async {
        do {
            let container = try await persistableTimer.addElapsedTime(5)
            self.timerState = container.elapsedTimeAndStatus()
        } catch {
            print("Error adding elapsed time: \(error)")
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
        VStack(spacing: 20) {
            Text(timerState: stopwatchModel.timerState)
                .font(.title)

            Button {
                Task {
                    await stopwatchModel.buttonTapped()
                }
            } label: {
                Text(stopwatchModel.buttonTitle)
            }
            Button("Add 5 sec") {
                Task {
                    await stopwatchModel.addExtraElapsedTime()
                }
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
