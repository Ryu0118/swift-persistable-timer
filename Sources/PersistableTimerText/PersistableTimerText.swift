import PersistableTimerCore
import SwiftUI

@available(iOS 16.0, *)
public extension Text {
    init(timerState: TimerState?, countsDown: Bool = true) {
        if let timerState, let pauseTime = timerState.pauseTime {
            self.init(timerInterval: timerState.timerInterval, pauseTime: pauseTime, countsDown: countsDown)
        } else if let displayDate = timerState?.displayDate {
            self.init(displayDate, style: .timer)
        } else {
            let now = Date()
            self.init(timerInterval: now ... now, countsDown: countsDown)
        }
    }
}
