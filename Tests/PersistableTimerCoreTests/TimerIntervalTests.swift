import Testing
import Foundation
@testable import PersistableTimerCore

/// Boundary tests for `TimerState.timerInterval` / `pauseTime`.
///
/// The OS-specific formulas are workarounds for differences in `Text(timerInterval:pauseTime:)`
/// between iOS 17 and earlier and iOS 18 and later. These tests pin the original formulas
/// (`legacy*` below) so the crash fix can't change the result for any input that produced
/// a valid range before.
@Suite struct TimerIntervalTests {
    let startDate = Date(timeIntervalSince1970: 1_000_000)
    var pause: Date { startDate.addingTimeInterval(5) }

    private func pausedState(type: RestoreType, elapsedTime: TimeInterval) -> TimerState {
        TimerState(
            startDate: startDate,
            elapsedTime: elapsedTime,
            status: .paused,
            type: type,
            pausePeriods: [PausePeriod(pause: pause, start: nil)],
            lastElapsedTimeCalculatedAt: startDate
        )
    }

    // MARK: - Original formulas (before the crash fix), kept as reference

    private func legacyTimerUpperBound(duration: TimeInterval, elapsedTime: TimeInterval) -> Date {
        startDate.addingTimeInterval(duration - elapsedTime - 1)
    }

    private func legacyTimerPauseTime(duration: TimeInterval, elapsedTime: TimeInterval) -> Date {
        startDate.addingTimeInterval(duration - elapsedTime)
    }

    private func legacyStopwatchLowerBound(elapsedTime: TimeInterval) -> Date {
        if #available(iOS 18, macCatalyst 18, macOS 18, tvOS 18, visionOS 2, watchOS 11, *) {
            pause.addingTimeInterval(min(0, -elapsedTime + 1))
        } else {
            pause.addingTimeInterval(-elapsedTime)
        }
    }

    // MARK: - Countdown timer: normal range must be bit-identical

    @Test(arguments: [
        // (duration, elapsedTime) with duration - elapsedTime >= 1
        (10.0, 9.0),
        (10.0, 3.0),
        (10.0, 0.0),
        (1.0, 0.0),
        (60.0, 12.345),
        (10.0, -5.0),
        (.infinity, 3.0),
        (10.0, -.infinity),
    ])
    func timerIntervalUnchangedWhenAtLeastOneSecondRemains(duration: TimeInterval, elapsedTime: TimeInterval) throws {
        let state = pausedState(type: .timer(duration: duration), elapsedTime: elapsedTime)
        let interval = state.timerInterval
        #expect(interval.lowerBound == startDate)
        #expect(interval.upperBound == legacyTimerUpperBound(duration: duration, elapsedTime: elapsedTime))
        #expect(try #require(state.pauseTime) == legacyTimerPauseTime(duration: duration, elapsedTime: elapsedTime))
    }

    @Test(arguments: [(10.0, 9.5), (10.0, 10.0), (1.0, 0.75)])
    func timerPauseTimeUnchangedWhenRemainingIsNonNegative(duration: TimeInterval, elapsedTime: TimeInterval) throws {
        let state = pausedState(type: .timer(duration: duration), elapsedTime: elapsedTime)
        #expect(try #require(state.pauseTime) == legacyTimerPauseTime(duration: duration, elapsedTime: elapsedTime))
    }

    // MARK: - Countdown timer: previously crashing range

    @Test(arguments: [
        // duration - elapsedTime = 0.5, 0, -10, and sub-second / negative durations
        (10.0, 9.5),
        (10.0, 10.0),
        (10.0, 20.0),
        (0.5, 0.0),
        (0.0, 0.0),
        (-1.0, 0.0),
    ])
    func timerIntervalCollapsesToStartDateWhenLessThanOneSecondRemains(duration: TimeInterval, elapsedTime: TimeInterval) throws {
        let state = pausedState(type: .timer(duration: duration), elapsedTime: elapsedTime)
        #expect(state.timerInterval == startDate ... startDate)

        let pauseTime = try #require(state.pauseTime)
        #expect(pauseTime >= startDate)
        #expect(pauseTime == startDate.addingTimeInterval(max(duration - elapsedTime, 0)))
    }

    @Test(arguments: [
        (10.0, Double.nan),
        (Double.nan, 0.0),
        (10.0, Double.infinity),
        (Double.infinity, Double.infinity),
    ])
    func timerIntervalHandlesNonFiniteValues(duration: TimeInterval, elapsedTime: TimeInterval) throws {
        let state = pausedState(type: .timer(duration: duration), elapsedTime: elapsedTime)
        #expect(state.timerInterval == startDate ... startDate)
        #expect(try #require(state.pauseTime) == startDate)
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
        #expect(state.timerInterval == startDate ... startDate)
        #expect(try #require(state.pauseTime) == startDate)
    }

    // MARK: - Stopwatch

    @Test(arguments: [0.0, 0.5, 1.0, 10.0, 12.345, .infinity])
    func stopwatchIntervalUnchangedForValidElapsedTime(elapsedTime: TimeInterval) throws {
        let state = pausedState(type: .stopwatch, elapsedTime: elapsedTime)
        #expect(state.timerInterval == legacyStopwatchLowerBound(elapsedTime: elapsedTime) ... pause)
        #expect(try #require(state.pauseTime) == pause)
    }

    @Test(arguments: [-0.5, -1.0, -100.0, .nan, -.infinity])
    func stopwatchIntervalDoesNotCrashForInvalidElapsedTime(elapsedTime: TimeInterval) throws {
        let state = pausedState(type: .stopwatch, elapsedTime: elapsedTime)
        let interval = state.timerInterval
        #expect(interval.lowerBound <= interval.upperBound)
        #expect(interval.upperBound == pause)

        let legacyLower = legacyStopwatchLowerBound(elapsedTime: elapsedTime)
        if !legacyLower.timeIntervalSinceReferenceDate.isNaN, legacyLower <= pause {
            // Did not crash before (e.g. iOS 18+ clamps with `min(0, ...)`): must be unchanged.
            #expect(interval == legacyLower ... pause)
        } else {
            #expect(interval == pause ... pause)
        }
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
