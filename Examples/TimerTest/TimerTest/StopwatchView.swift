import SwiftUI
import Observation
import PersistableTimer

@Observable
final class StopwatchModel {
    private let persistableTimer: PersistableTimer

    var stopwatchText: String = "00:00:00"
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

    var dateFormatter: DateComponentsFormatter = {
        let dateFormatter = DateComponentsFormatter()
        dateFormatter.unitsStyle = .positional
        dateFormatter.zeroFormattingBehavior = .pad
        dateFormatter.allowedUnits = [.hour, .minute, .second]
        return dateFormatter
    }()

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
                try await persistableTimer.start(type: .stopwatch)
            }
        } catch {
            print(error)
        }
    }

    func synchronize() async {
        do {
            try persistableTimer.restore()
        } catch {
            print(error)
        }

        for await timerState in persistableTimer.timeStream {
            stopwatchText = dateFormatter.string(from: timerState.time) ?? "00:00:00"
            self.timerState = timerState
        }
    }

    func finish() async {
        try? await persistableTimer.finish()
    }
}

struct StopwatchView: View {
    let stopwatchModel: StopwatchModel

    public var body: some View {
        VStack {
            Text(stopwatchModel.stopwatchText)
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
