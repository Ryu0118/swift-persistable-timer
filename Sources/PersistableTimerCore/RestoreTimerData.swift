import Foundation

/// Represents the status of a timer.
public enum TimerStatus: Sendable, Codable, Hashable {
    case running
    case paused
    case finished
}

/// Represents a period during which the timer is paused.
public struct PausePeriod: Sendable, Codable, Hashable {
    public var pause: Date
    public var start: Date?

    public init(pause: Date, start: Date?) {
        self.pause = pause
        self.start = start
    }
}

/// Represents the state of a timer, including elapsed time and status.
public struct TimerState: Sendable, Codable, Hashable {
    public let startDate: Date
    public var elapsedTime: TimeInterval
    public var status: TimerStatus
    public var type: RestoreType
    public var pausePeriods: [PausePeriod]

    public var time: TimeInterval {
        switch type {
        case .stopwatch:
            elapsedTime
        case let .timer(duration):
            duration - elapsedTime
        }
    }

    /// Calculates the display date for the timer or stopwatch.
    /// - Returns: The `Date` to be displayed in the `Text` view.
    public var displayDate: Date {
        switch type {
        case .stopwatch:
            Date(timeIntervalSinceNow: -elapsedTime)
        case let .timer(duration):
            Date(timeIntervalSinceNow: duration - elapsedTime)
        }
    }

    package var timerInterval: ClosedRange<Date> {
        switch type {
        case .stopwatch:
            if pausePeriods.last != nil {
                if #available(iOS 18, macCatalyst 18, macOS 18, tvOS 18, visionOS 2, watchOS 11, *) {
                    Date().addingTimeInterval(-elapsedTime + 1) ... Date()
                } else {
                    Date().addingTimeInterval(-elapsedTime) ... Date()
                }
            } else {
                startDate ... startDate
            }
        case .timer(let duration):
            startDate ... startDate.addingTimeInterval(duration - elapsedTime)
        }
    }

    package var pauseTime: Date? {
        switch type {
        case .stopwatch:
            if let pausePeriod = pausePeriods.last, pausePeriod.start == nil {
                pausePeriod.pause
            } else {
                nil
            }
        case .timer(let duration):
            if let pausePeriod = pausePeriods.last, pausePeriod.start == nil {
                startDate.addingTimeInterval(duration - elapsedTime)
            } else {
                nil
            }
        }
    }

    public init(
        startDate: Date,
        elapsedTime: TimeInterval,
        status: TimerStatus,
        type: RestoreType,
        pausePeriods: [PausePeriod]
    ) {
        self.startDate = startDate
        self.elapsedTime = elapsedTime
        self.status = status
        self.type = type
        self.pausePeriods = pausePeriods
    }
}

/// Represents the type of restoration for a timer, either a stopwatch or a countdown timer.
public enum RestoreType: Codable, Hashable, Sendable {
    case stopwatch
    case timer(duration: TimeInterval)
}

/// Represents the data required to restore a timer's state.
public struct RestoreTimerData: Codable, Hashable, Sendable {
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
            startDate: startDate,
            elapsedTime: max(elapsedTime, 0),
            status: status,
            type: type,
            pausePeriods: pausePeriods
        )
    }
}
