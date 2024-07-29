import Testing
import Foundation
@testable import PersistableTimerCore

@Suite struct PersistableTimerCoreTests {
    var RestoreTimerContainer: RestoreTimerContainer!
    var mockUserDefaultsClient: InMemoryDataSource!

    init() {
        mockUserDefaultsClient = InMemoryDataSource()
        RestoreTimerContainer = PersistableTimerCore.RestoreTimerContainer(dataSource: mockUserDefaultsClient)
    }

    @Test func startTimerSuccessfully() async throws {
        let expectedStartDate = Date()
        let result = try await RestoreTimerContainer.start(now: expectedStartDate, type: .timer(duration: 10))
        #expect(result.startDate.timeIntervalSince1970.floorInt == expectedStartDate.timeIntervalSince1970.floorInt)
        #expect(result.pausePeriods.isEmpty)
        #expect(result.stopDate == nil)
    }

    @Test func startTimerThrowsErrorWhenAlreadyStarted() async throws {
        try await RestoreTimerContainer.start(type: .stopwatch)
        await #expect { try await RestoreTimerContainer.start(type: .stopwatch) } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerAlreadyStarted
        }
    }

    @Test func startTimerForcefullyWhenAlreadyStarted() async throws {
        try await RestoreTimerContainer.start(type: .timer(duration: 10))
        let result = try await RestoreTimerContainer.start(type: .timer(duration: 10), forceStart: true)
        #expect(result.startDate != nil)
    }

    @Test func pauseTimerSuccessfully() async throws {
        let startDate = Date()
        let pauseDate = Date()
        try await RestoreTimerContainer.start(now: startDate, type: .stopwatch)
        let result = try await RestoreTimerContainer.pause(now: pauseDate)
        #expect(result.pausePeriods.count == 1)
        #expect(result.pausePeriods.first?.pause == pauseDate)
        #expect(result.pausePeriods.first?.start == nil)
        #expect(result.startDate.timeIntervalSince1970.floorInt == startDate.timeIntervalSince1970.floorInt)
    }

    @Test func pauseTimerThrowsErrorWhenAlreadyPaused() async throws {
        try await RestoreTimerContainer.start(type: .stopwatch)
        try await RestoreTimerContainer.pause()
        await #expect { try await RestoreTimerContainer.pause() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerAlreadyPaused
        }
    }

    @Test func resumeTimerSuccessfully() async throws {
        try await RestoreTimerContainer.start(type: .stopwatch)
        try await RestoreTimerContainer.pause()
        let result = try await RestoreTimerContainer.resume()
        #expect(result.pausePeriods.count == 1)
        #expect(result.pausePeriods.first?.start != nil)
    }

    @Test func resumeTimerThrowsErrorWhenNotPaused() async throws {
        try await RestoreTimerContainer.start(type: .stopwatch)
        await #expect { try await RestoreTimerContainer.resume() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotPaused
        }
    }

    @Test func finishTimerSuccessfullyWhenRunning() async throws {
        try await  RestoreTimerContainer.start(type: .stopwatch)
        let result = try await RestoreTimerContainer.finish()
        #expect(result.stopDate != nil)
    }

    @Test func finishTimerSuccessfullyWhenPaused() async throws {
        try await RestoreTimerContainer.start(type: .stopwatch)
        try await RestoreTimerContainer.pause()
        let result = try await RestoreTimerContainer.finish()
        #expect(result.stopDate != nil)
    }

    @Test func finishTimerThrowsErrorWhenNotStarted() async throws {
        await #expect { try await RestoreTimerContainer.finish() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func getTimerDataThrowsErrorWhenNotStarted() async throws {
        #expect { try RestoreTimerContainer.getTimerData() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func getTimerDataReturnsCorrectDataWhenRunning() async throws {
        let startedTimerData = try await RestoreTimerContainer.start(type: .stopwatch)
        let fetchedTimerData = try RestoreTimerContainer.getTimerData()
        #expect(fetchedTimerData.startDate == startedTimerData.startDate)
        #expect(fetchedTimerData.pausePeriods.count == startedTimerData.pausePeriods.count)
    }

    @Test func pauseTimerThrowsErrorWhenStopped() async throws {
        try await RestoreTimerContainer.start(type: .stopwatch)
        try await RestoreTimerContainer.finish()
        await #expect { try await RestoreTimerContainer.pause() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func resumeTimerThrowsErrorWhenStopped() async throws {
        try await RestoreTimerContainer.start(type: .stopwatch)
        try await RestoreTimerContainer.pause()
        try await RestoreTimerContainer.finish()
        await #expect { try await RestoreTimerContainer.resume() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func elapsedTimeAndStatusReturnsRunningAndCorrectTime() async throws {
        let startDate = Date()
        try await RestoreTimerContainer.start(now: startDate, type: .stopwatch)
        let timerData = try RestoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus()
        #expect(result.status == .running)
        #expect(result.elapsedTime >= 0)
    }

    @Test func elapsedTimeAndStatusReturnsPausedAndCorrectTime() async throws {
        let startDate = Date()
        try await RestoreTimerContainer.start(now: startDate, type: .stopwatch)
        try await RestoreTimerContainer.pause()
        let timerData = try RestoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus()
        #expect(result.status == .paused)
        #expect(result.elapsedTime >= 0)
    }

    @Test func elapsedTimeAndStatusReturnsStoppedAndCorrectTime() async throws {
        let startDate = Date()
        try await RestoreTimerContainer.start(now: startDate, type: .stopwatch)
        try await RestoreTimerContainer.finish()
        #expect { try RestoreTimerContainer.getTimerData() } throws: { error in
            let persistableTimerClientError = try #require(error as? PersistableTimerClientError)
            return persistableTimerClientError == .timerHasNotStarted
        }
    }

    @Test func elapsedTimeAndStatusCalculatesCorrectElapsedTimeWhenRunning() async throws {
        let startDate = Date()
        try await RestoreTimerContainer.start(now: startDate, type: .stopwatch)

        let futureDate = startDate.addingTimeInterval(2)

        let timerData = try RestoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus(now: futureDate)

        #expect(result.status == .running)
        #expect(result.elapsedTime.ceilInt == 2)
    }

    @Test func elapsedTimeAndStatusCalculatesCorrectElapsedTimeWhenPaused() async throws {
        let startDate = Date()
        try await RestoreTimerContainer.start(now: startDate, type: .stopwatch)

        let pauseDate = startDate.addingTimeInterval(1)
        try await RestoreTimerContainer.pause(now: pauseDate)

        let futureDate = startDate.addingTimeInterval(3)

        let timerData = try RestoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus(now: futureDate)

        #expect(result.status == .paused)
        #expect(result.elapsedTime.ceilInt == 1)
    }

    @Test func elapsedTimeAndStatusCalculatesCorrectElapsedTimeWhenStopped() async throws {
        let startDate = Date()
        try await RestoreTimerContainer.start(now: startDate, type: .timer(duration: 10))

        let stopDate = startDate.addingTimeInterval(2)
        let timerData = try await RestoreTimerContainer.finish(now: stopDate)
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
