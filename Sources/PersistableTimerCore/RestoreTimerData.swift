import Foundation

/// Represents the status of a timer.
public enum TimerStatus: Sendable, Codable, Hashable {
    /// The timer is currently running.
    case running
    /// The timer is currently paused.
    case paused
    /// The timer has finished.
    case finished
}

/// Represents a period during which the timer is paused.
public struct PausePeriod: Sendable, Codable, Hashable {
    /// The date and time when the timer was paused.
    public var pause: Date
    /// The date and time when the timer resumed.
    /// If `nil`, the timer is still paused.
    public var start: Date?

    public init(pause: Date, start: Date?) {
        self.pause = pause
        self.start = start
    }
}

/// Represents the type of timer, either a stopwatch or a countdown timer.
public enum RestoreType: Codable, Hashable, Sendable {
    /// A stopwatch timer.
    case stopwatch
    /// A countdown timer with a specified duration (in seconds).
    case timer(duration: TimeInterval)
}

/// Represents the state of a timer, including elapsed time, status, and the last calculation timestamp.
public struct TimerState: Sendable, Codable, Hashable {
    /// The date and time when the timer started.
    public let startDate: Date
    /// The total elapsed time of the timer in seconds, adjusted for any pause durations.
    public var elapsedTime: TimeInterval
    /// The current status of the timer (running, paused, or finished).
    public var status: TimerStatus
    /// The type of timer operation (stopwatch or timer with duration).
    public var type: RestoreType
    /// An array of periods during which the timer was paused.
    public var pausePeriods: [PausePeriod]
    /// The date and time when the elapsed time was last calculated.
    ///
    /// This property is updated each time `elapsedTimeAndStatus(now:)` is called,
    /// and represents the moment when the elapsed time and timer status were computed.
    public let lastElapsedTimeCalculatedAt: Date

    /// The computed time value for the timer.
    ///
    /// - For a stopwatch, this value is equal to `elapsedTime`.
    /// - For a countdown timer, this value is the remaining time (initial duration minus `elapsedTime`).
    public var time: TimeInterval {
        switch type {
        case .stopwatch:
            return elapsedTime
        case let .timer(duration):
            return duration - elapsedTime
        }
    }

    /// The display date used for UI representation of the timer.
    ///
    /// - For a stopwatch, this is calculated by subtracting `elapsedTime` from the current time.
    /// - For a timer, this is calculated by subtracting `elapsedTime` from the timer's duration.
    public var displayDate: Date {
        switch type {
        case .stopwatch:
            return Date(timeIntervalSinceNow: -elapsedTime)
        case let .timer(duration):
            return Date(timeIntervalSinceNow: duration - elapsedTime)
        }
    }

    /// The timer interval used for creating countdown or stopwatch animations.
    ///
    /// For a stopwatch, if a pause exists, it returns a range ending at the pause time.
    /// For a timer, it returns a range from the start date to the expected finish date.
    ///
    /// The returned range is always valid (`lowerBound <= upperBound`). When the computed bounds
    /// would be inverted (e.g. a countdown timer paused with less than one second remaining or after
    /// its duration was exceeded, or a negative / non-finite `elapsedTime`), the range collapses to a
    /// single date instead of trapping. For all inputs that produced a valid range before, the result
    /// is unchanged.
    package var timerInterval: ClosedRange<Date> {
        switch type {
        case .stopwatch:
            if let lastPausePeriod = pausePeriods.last {
                if #available(iOS 18, macCatalyst 18, macOS 18, tvOS 18, visionOS 2, watchOS 11, *) {
                    Self.clampedRange(
                        lastPausePeriod.pause.addingTimeInterval(min(0, -elapsedTime + 1)),
                        lastPausePeriod.pause,
                        fallback: lastPausePeriod.pause
                    )
                } else {
                    Self.clampedRange(
                        lastPausePeriod.pause.addingTimeInterval(-elapsedTime),
                        lastPausePeriod.pause,
                        fallback: lastPausePeriod.pause
                    )
                }
            } else {
                startDate ... startDate
            }
        case .timer(let duration):
            Self.clampedRange(
                startDate,
                startDate.addingTimeInterval(duration - elapsedTime - 1),
                fallback: startDate
            )
        }
    }

    /// Returns `lower ... upper` when it is a valid range, otherwise `fallback ... fallback`.
    ///
    /// `ClosedRange` traps when `lower > upper`. NaN bounds are treated as invalid explicitly,
    /// because how `Date` comparison handles NaN differs between Foundation versions.
    private static func clampedRange(_ lower: Date, _ upper: Date, fallback: Date) -> ClosedRange<Date> {
        let isNaN = lower.timeIntervalSinceReferenceDate.isNaN || upper.timeIntervalSinceReferenceDate.isNaN
        return !isNaN && lower <= upper ? lower ... upper : fallback ... fallback
    }

    /// The time at which the timer is set to resume if it is currently paused.
    ///
    /// - For a stopwatch, if currently paused, returns the pause time.
    /// - For a timer, if currently paused, returns the expected resume time.
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
                // Never earlier than `startDate` (or NaN), so it stays consistent with
                // `timerInterval` even when the duration has already been exceeded.
                // Unchanged whenever `duration - elapsedTime >= 0`.
                startDate.addingTimeInterval(Self.nonNegativeOrZero(duration - elapsedTime))
            } else {
                nil
            }
        }
    }

    /// Returns `value` if it is `>= 0`, otherwise `0` (including NaN).
    private static func nonNegativeOrZero(_ value: TimeInterval) -> TimeInterval {
        value >= 0 ? value : 0
    }

    public init(
        startDate: Date,
        elapsedTime: TimeInterval,
        status: TimerStatus,
        type: RestoreType,
        pausePeriods: [PausePeriod],
        lastElapsedTimeCalculatedAt: Date
    ) {
        self.startDate = startDate
        self.elapsedTime = elapsedTime
        self.status = status
        self.type = type
        self.pausePeriods = pausePeriods
        self.lastElapsedTimeCalculatedAt = lastElapsedTimeCalculatedAt
    }
}

/// Represents the data required to restore a timer's state.
public struct RestoreTimerData: Codable, Hashable, Sendable {
    /// The date and time when the timer was started.
    public var startDate: Date
    /// An array of pause periods during which the timer was paused.
    public var pausePeriods: [PausePeriod]
    /// The type of timer (stopwatch or timer with duration).
    public var type: RestoreType
    /// The date and time when the timer was stopped, if applicable.
    public var stopDate: Date?

    /// Calculates the elapsed time and determines the current status of the timer.
    ///
    /// This method accounts for any pause periods and adjusts the elapsed time accordingly.
    /// It also records the current time as `lastElapsedTimeCalculatedAt` in the returned `TimerState`,
    /// indicating when the calculation was performed.
    ///
    /// - Parameter now: The current date and time. Defaults to `Date()`.
    /// - Returns: A `TimerState` representing the timer's state, including the adjusted elapsed time,
    ///            current status, and the timestamp of the calculation.
    public func elapsedTimeAndStatus(now: Date = Date()) -> TimerState {
        let endDate = stopDate ?? now
        var elapsedTime = endDate.timeIntervalSince(startDate)
        var status: TimerStatus = .running

        for period in pausePeriods {
            if let resumeTime = period.start {
                let pauseDuration = resumeTime.timeIntervalSince(period.pause)
                elapsedTime -= pauseDuration
            } else {
                let pauseDuration = endDate.timeIntervalSince(period.pause)
                elapsedTime -= pauseDuration
                status = .paused
                break
            }
        }

        if stopDate != nil {
            status = .finished
        }

        return TimerState(
            startDate: startDate,
            elapsedTime: max(elapsedTime, 0),
            status: status,
            type: type,
            pausePeriods: pausePeriods,
            lastElapsedTimeCalculatedAt: now
        )
    }
}
