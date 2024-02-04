import Foundation

// タイマーの状態を表す列挙型
public enum TimerStatus: Codable {
    case running
    case paused
    case stopped
}

// 一時停止期間を表す構造体
public struct PausePeriod: Codable {
    public var pause: Date
    public var start: Date?

    public init(pause: Date, start: Date?) {
        self.pause = pause
        self.start = start
    }
}

// 経過時間とタイマー状態を格納するための構造体
public struct TimerState: Codable {
    public var elapsedTime: TimeInterval
    public var status: TimerStatus

    public init(elapsedTime: TimeInterval, status: TimerStatus) {
        self.elapsedTime = elapsedTime
        self.status = status
    }
}

public struct RestoreTimerData: Codable {
    public var startDate: Date
    public var pausePeriods: [PausePeriod]
    public var stopDate: Date?

    public init(startDate: Date, pausePeriods: [PausePeriod], stopDate: Date?) {
        self.startDate = startDate
        self.pausePeriods = pausePeriods
        self.stopDate = stopDate
    }

    public func elapsedTimeAndStatus(now: Date = Date()) -> TimerState {
        let endDate = stopDate ?? now
        var elapsedTime = endDate.timeIntervalSince(startDate)
        var status: TimerStatus = .running

        for period in pausePeriods {
            if let start = period.start, start < endDate {
                let pauseTime = start.timeIntervalSince(period.pause)
                elapsedTime -= pauseTime
            } else {
                let pauseTime = endDate.timeIntervalSince(period.pause)
                elapsedTime -= pauseTime
                status = .paused
                break
            }
        }

        if let _ = stopDate {
            status = .stopped
        }

        return TimerState(
            elapsedTime: max(elapsedTime, 0),
            status: status
        )
    }
}
