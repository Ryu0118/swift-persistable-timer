import Testing
import Foundation
@testable import PersistableTimerCore

@Suite struct PersistableTimerCoreTests {
    var restoreTimerContainer: RestoreTimerContainer!
    var mockUserDefaultsClient: InMemoryDataSource!

    init() {
        mockUserDefaultsClient = InMemoryDataSource()
        restoreTimerContainer = PersistableTimerCore.RestoreTimerContainer(dataSource: mockUserDefaultsClient)
    }

    @Test func startTimerSuccessfully() async throws {
        let expectedStartDate = Date()
        let result = try await restoreTimerContainer.start(now: expectedStartDate, type: .timer(duration: 10))
        #expect(result.startDate.timeIntervalSince1970.floorInt == expectedStartDate.timeIntervalSince1970.floorInt)
        #expect(result.pausePeriods.isEmpty)
        #expect(result.stopDate == nil)
    }

    @Test func startTimerWithIDSuccessfully() async throws {
        let expectedStartDate = Date()
        let timerID = "unique-timer-id"
        let result = try await restoreTimerContainer.start(id: timerID, now: expectedStartDate, type: .timer(duration: 10))
        #expect(result.startDate.timeIntervalSince1970.floorInt == expectedStartDate.timeIntervalSince1970.floorInt)
        #expect(result.pausePeriods.isEmpty)
        #expect(result.stopDate == nil)
    }

    @Test func startTimerThrowsErrorWhenAlreadyStarted() async throws {
        try await restoreTimerContainer.start(type: .stopwatch)
        await #expect { try await restoreTimerContainer.start(type: .stopwatch) } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerAlreadyStarted
        }
    }

    @Test func startTimerForcefullyWhenAlreadyStarted() async throws {
        try await restoreTimerContainer.start(type: .timer(duration: 10))
        let result = try await restoreTimerContainer.start(type: .timer(duration: 10), forceStart: true)
        #expect(result.startDate != nil)
    }

    @Test func startMultipleTimersSuccessfully() async throws {
        let timerID1 = "timer-1"
        let timerID2 = "timer-2"

        let result1 = try await restoreTimerContainer.start(id: timerID1, type: .stopwatch)
        let result2 = try await restoreTimerContainer.start(id: timerID2, type: .timer(duration: 10))

        #expect(result1.startDate != nil)
        #expect(result2.startDate != nil)
    }

    @Test func pauseTimerSuccessfully() async throws {
        let startDate = Date()
        let pauseDate = Date()
        try await restoreTimerContainer.start(now: startDate, type: .stopwatch)
        let result = try await restoreTimerContainer.pause(now: pauseDate)
        #expect(result.pausePeriods.count == 1)
        #expect(result.pausePeriods.first?.pause == pauseDate)
        #expect(result.pausePeriods.first?.start == nil)
        #expect(result.startDate.timeIntervalSince1970.floorInt == startDate.timeIntervalSince1970.floorInt)
    }

    @Test func pauseTimerWithIDSuccessfully() async throws {
        let timerID = "timer-1"
        let startDate = Date()
        let pauseDate = Date()
        try await restoreTimerContainer.start(id: timerID, now: startDate, type: .stopwatch)
        let result = try await restoreTimerContainer.pause(id: timerID, now: pauseDate)
        #expect(result.pausePeriods.count == 1)
        #expect(result.pausePeriods.first?.pause == pauseDate)
        #expect(result.pausePeriods.first?.start == nil)
        #expect(result.startDate.timeIntervalSince1970.floorInt == startDate.timeIntervalSince1970.floorInt)
    }

    @Test func pauseTimerThrowsErrorWhenAlreadyPaused() async throws {
        try await restoreTimerContainer.start(type: .stopwatch)
        try await restoreTimerContainer.pause()
        await #expect { try await restoreTimerContainer.pause() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerAlreadyPaused
        }
    }

    @Test func resumeTimerSuccessfully() async throws {
        try await restoreTimerContainer.start(type: .stopwatch)
        try await restoreTimerContainer.pause()
        let result = try await restoreTimerContainer.resume()
        #expect(result.pausePeriods.count == 1)
        #expect(result.pausePeriods.first?.start != nil)
    }

    @Test func resumeTimerWithIDSuccessfully() async throws {
        let timerID = "timer-1"
        try await restoreTimerContainer.start(id: timerID, type: .stopwatch)
        try await restoreTimerContainer.pause(id: timerID)
        let result = try await restoreTimerContainer.resume(id: timerID)
        #expect(result.pausePeriods.count == 1)
        #expect(result.pausePeriods.first?.start != nil)
    }

    @Test func resumeTimerThrowsErrorWhenNotPaused() async throws {
        try await restoreTimerContainer.start(type: .stopwatch)
        await #expect { try await restoreTimerContainer.resume() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotPaused
        }
    }

    @Test func finishTimerSuccessfullyWhenRunning() async throws {
        try await restoreTimerContainer.start(type: .stopwatch)
        let result = try await restoreTimerContainer.finish()
        #expect(result.stopDate != nil)
    }

    @Test func finishTimerWithIDSuccessfullyWhenRunning() async throws {
        let timerID = "timer-1"
        try await restoreTimerContainer.start(id: timerID, type: .stopwatch)
        let result = try await restoreTimerContainer.finish(id: timerID)
        #expect(result.stopDate != nil)
    }

    @Test func finishAllTimersSuccessfully() async throws {
        let timerID1 = "timer-1"
        let timerID2 = "timer-2"

        try await restoreTimerContainer.start(id: timerID1, type: .stopwatch)
        try await restoreTimerContainer.start(id: timerID2, type: .timer(duration: 10))

        let results = try await restoreTimerContainer.finishAll()

        #expect(results[timerID1]?.stopDate != nil)
        #expect(results[timerID2]?.stopDate != nil)
    }

    @Test func finishTimerSuccessfullyWhenPaused() async throws {
        try await restoreTimerContainer.start(type: .stopwatch)
        try await restoreTimerContainer.pause()
        let result = try await restoreTimerContainer.finish()
        #expect(result.stopDate != nil)
    }

    @Test func finishTimerThrowsErrorWhenNotStarted() async throws {
        await #expect { try await restoreTimerContainer.finish() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func getTimerDataThrowsErrorWhenNotStarted() async throws {
        #expect { try restoreTimerContainer.getTimerData() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func getTimerDataReturnsCorrectDataWhenRunning() async throws {
        let startedTimerData = try await restoreTimerContainer.start(type: .stopwatch)
        let fetchedTimerData = try restoreTimerContainer.getTimerData()
        #expect(fetchedTimerData.startDate == startedTimerData.startDate)
        #expect(fetchedTimerData.pausePeriods.count == startedTimerData.pausePeriods.count)
    }

    @Test func pauseTimerThrowsErrorWhenStopped() async throws {
        try await restoreTimerContainer.start(type: .stopwatch)
        try await restoreTimerContainer.finish()
        await #expect { try await restoreTimerContainer.pause() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func resumeTimerThrowsErrorWhenStopped() async throws {
        try await restoreTimerContainer.start(type: .stopwatch)
        try await restoreTimerContainer.pause()
        try await restoreTimerContainer.finish()
        await #expect { try await restoreTimerContainer.resume() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func elapsedTimeAndStatusReturnsRunningAndCorrectTime() async throws {
        let startDate = Date()
        try await restoreTimerContainer.start(now: startDate, type: .stopwatch)
        let timerData = try restoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus()
        #expect(result.status == .running)
        #expect(result.elapsedTime >= 0)
    }

    @Test func elapsedTimeAndStatusReturnsPausedAndCorrectTime() async throws {
        let startDate = Date()
        try await restoreTimerContainer.start(now: startDate, type: .stopwatch)
        try await restoreTimerContainer.pause()
        let timerData = try restoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus()
        #expect(result.status == .paused)
        #expect(result.elapsedTime >= 0)
    }

    @Test func elapsedTimeAndStatusReturnsStoppedAndCorrectTime() async throws {
        let startDate = Date()
        try await restoreTimerContainer.start(now: startDate, type: .stopwatch)
        try await restoreTimerContainer.finish()
        #expect { try restoreTimerContainer.getTimerData() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func elapsedTimeAndStatusCalculatesCorrectElapsedTimeWhenRunning() async throws {
        let startDate = Date()
        try await restoreTimerContainer.start(now: startDate, type: .stopwatch)

        let futureDate = startDate.addingTimeInterval(2)

        let timerData = try restoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus(now: futureDate)

        #expect(result.status == .running)
        #expect(result.elapsedTime.ceilInt == 2)
    }

    @Test func elapsedTimeAndStatusCalculatesCorrectElapsedTimeWhenPaused() async throws {
        let startDate = Date()
        try await restoreTimerContainer.start(now: startDate, type: .stopwatch)

        let pauseDate = startDate.addingTimeInterval(1)
        try await restoreTimerContainer.pause(now: pauseDate)

        let futureDate = startDate.addingTimeInterval(3)

        let timerData = try restoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus(now: futureDate)

        #expect(result.status == .paused)
        #expect(result.elapsedTime.ceilInt == 1)
    }

    @Test func elapsedTimeAndStatusCalculatesCorrectElapsedTimeWhenStopped() async throws {
        let startDate = Date()
        try await restoreTimerContainer.start(now: startDate, type: .timer(duration: 10))

        let stopDate = startDate.addingTimeInterval(2)
        let timerData = try await restoreTimerContainer.finish(now: stopDate)
        let futureDate = stopDate.addingTimeInterval(10)
        let result = timerData.elapsedTimeAndStatus(now: futureDate)

        #expect(result.status == .finished)
        #expect(result.elapsedTime.ceilInt == 2)
    }
}

fileprivate extension TimeInterval {
    var ceilInt: Int {
        Int(ceil(self))
    }

    var floorInt: Int {
        Int(floor(self))
    }
}
