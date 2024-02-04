import Foundation

/// Represents the status of a timer.
public enum TimerStatus: Codable, Hashable {
    case running
    case paused
    case finished
}

/// Represents a period during which the timer is paused.
public struct PausePeriod: Codable, Hashable {
    public var pause: Date
    public var start: Date?

    public init(pause: Date, start: Date?) {
        self.pause = pause
        self.start = start
    }
}

/// Represents the state of a timer, including elapsed time and status.
public struct TimerState: Codable, Hashable {
    public var elapsedTime: TimeInterval
    public var status: TimerStatus
    public var type: RestoreType

    public var time: TimeInterval {
        switch type {
        case .stopwatch:
            elapsedTime
        case let .timer(duration):
            duration - elapsedTime
        }
    }

    public init(elapsedTime: TimeInterval, status: TimerStatus, type: RestoreType) {
        self.elapsedTime = elapsedTime
        self.status = status
        self.type = type
    }
}

/// Represents the type of restoration for a timer, either a stopwatch or a countdown timer.
public enum RestoreType: Codable, Hashable {
    case stopwatch
    case timer(duration: TimeInterval)
}

/// Represents the data required to restore a timer's state.
public struct RestoreTimerData: Codable, Hashable {
    public var startDate: Date
    public var pausePeriods: [PausePeriod]
    public var type: RestoreType
    public var stopDate: Date?

    public init(startDate: Date, pausePeriods: [PausePeriod], type: RestoreType, stopDate: Date? = nil) {
        self.startDate = startDate
        self.pausePeriods = pausePeriods
        self.type = type
        self.stopDate = stopDate
    }

    /// Calculates the elapsed time and determines the current status of the timer.
    ///
    /// - Parameter now: The current date and time, defaults to `Date()`.
    /// - Returns: The `TimerState` representing the elapsed time and the current status.
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
            status = .finished
        }

        return TimerState(
            elapsedTime: max(elapsedTime, 0),
            status: status,
            type: type
        )
    }
}
