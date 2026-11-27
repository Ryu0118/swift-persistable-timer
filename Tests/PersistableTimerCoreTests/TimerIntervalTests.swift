import Testing
import Foundation
@testable import PersistableTimerCore

@Suite struct TimerIntervalTests {
    let startDate = Date(timeIntervalSince1970: 1_000_000)

    private func pausedState(
        type: RestoreType,
        elapsedTime: TimeInterval,
        pause: Date? = nil
    ) -> TimerState {
        TimerState(
            startDate: startDate,
            elapsedTime: elapsedTime,
            status: .paused,
            type: type,
            pausePeriods: [PausePeriod(pause: pause ?? startDate.addingTimeInterval(5), start: nil)],
            lastElapsedTimeCalculatedAt: startDate
        )
    }

    // MARK: - Countdown timer

    @Test(arguments: [
        // (duration, elapsedTime) -> duration - elapsedTime = 1, 0.5, 0, -10
        (10.0, 9.0),
        (10.0, 9.5),
        (10.0, 10.0),
        (10.0, 20.0),
    ])
    func timerIntervalDoesNotCrashNearOrPastDuration(duration: TimeInterval, elapsedTime: TimeInterval) throws {
        let state = pausedState(type: .timer(duration: duration), elapsedTime: elapsedTime)
        let interval = state.timerInterval
        #expect(interval.lowerBound == startDate)
        #expect(interval.lowerBound <= interval.upperBound)

        let pauseTime = try #require(state.pauseTime)
        #expect(pauseTime >= interval.lowerBound)
        #expect(pauseTime == startDate.addingTimeInterval(max(duration - elapsedTime, 0)))
    }

    @Test func timerIntervalKeepsExistingRangeWhenEnoughTimeRemains() throws {
        let state = pausedState(type: .timer(duration: 10), elapsedTime: 3)
        #expect(state.timerInterval == startDate ... startDate.addingTimeInterval(6))
        #expect(try #require(state.pauseTime) == startDate.addingTimeInterval(7))
    }

    @Test(arguments: [-5.0, .nan, .infinity, -.infinity])
    func timerIntervalHandlesInvalidElapsedTime(elapsedTime: TimeInterval) throws {
        let state = pausedState(type: .timer(duration: 10), elapsedTime: elapsedTime)
        let interval = state.timerInterval
        #expect(interval.lowerBound <= interval.upperBound)
        let pauseTime = try #require(state.pauseTime)
        #expect(pauseTime >= interval.lowerBound)
        #expect(pauseTime.timeIntervalSince1970.isFinite)
    }

    @Test(arguments: [0.0, 0.5, -1.0, .nan, .infinity])
    func timerIntervalHandlesInvalidDuration(duration: TimeInterval) throws {
        let state = pausedState(type: .timer(duration: duration), elapsedTime: 0)
        let interval = state.timerInterval
        #expect(interval.lowerBound <= interval.upperBound)
        let pauseTime = try #require(state.pauseTime)
        #expect(pauseTime >= interval.lowerBound)
    }

    @Test func timerIntervalFromRestoredDataPausedAfterDuration() throws {
        // Paused 12s after start with a 10s duration: elapsedTime exceeds duration.
        let data = RestoreTimerData(
            startDate: startDate,
            pausePeriods: [PausePeriod(pause: startDate.addingTimeInterval(12), start: nil)],
            type: .timer(duration: 10),
            stopDate: nil
        )
        let state = data.elapsedTimeAndStatus(now: startDate.addingTimeInterval(30))
        #expect(state.status == .paused)
        let interval = state.timerInterval
        #expect(interval.lowerBound <= interval.upperBound)
        #expect(try #require(state.pauseTime) == startDate)
    }

    // MARK: - Stopwatch

    @Test(arguments: [0.0, 0.5, 1.0, 10.0, -1.0, -100.0, .nan, .infinity, -.infinity])
    func stopwatchIntervalDoesNotCrash(elapsedTime: TimeInterval) throws {
        let pause = startDate.addingTimeInterval(5)
        let state = pausedState(type: .stopwatch, elapsedTime: elapsedTime, pause: pause)
        let interval = state.timerInterval
        #expect(interval.lowerBound <= interval.upperBound)
        #expect(interval.upperBound == pause)
        #expect(try #require(state.pauseTime) == pause)
    }

    @Test func stopwatchIntervalWithoutPausePeriods() {
        let state = TimerState(
            startDate: startDate,
            elapsedTime: -3,
            status: .running,
            type: .stopwatch,
            pausePeriods: [],
            lastElapsedTimeCalculatedAt: startDate
        )
        #expect(state.timerInterval == startDate ... startDate)
        #expect(state.pauseTime == nil)
    }
}
