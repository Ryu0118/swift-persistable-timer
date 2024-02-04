import XCTest
@testable import PersistableTimerCore

final class PersistableTimerCoreTests: XCTestCase {
    var RestoreTimerContainer: RestoreTimerContainer!
    var mockUserDefaultsClient: MockUserDefaultsClient!

    override func setUp() {
        super.setUp()
        mockUserDefaultsClient = MockUserDefaultsClient()
        RestoreTimerContainer = PersistableTimerCore.RestoreTimerContainer(userDefaultsClient: mockUserDefaultsClient)
    }

    override func tearDown() {
        RestoreTimerContainer = nil
        mockUserDefaultsClient = nil
        super.tearDown()
    }

    func testStartTimerSuccessfully() throws {
        let expectedStartDate = Date()
        let result = try RestoreTimerContainer.start(now: expectedStartDate, type: .timer(duration: 10))
        XCTAssertEqual(result.startDate.timeIntervalSince1970, expectedStartDate.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(result.pausePeriods.isEmpty)
        XCTAssertNil(result.stopDate)
    }

    func testStartTimerThrowsErrorWhenAlreadyStarted() throws {
        try RestoreTimerContainer.start(type: .stopwatch)
        XCTAssertThrowsError(try RestoreTimerContainer.start(type: .stopwatch)) { error in
            XCTAssertEqual(error as? PersistableTimerClientError, .timerAlreadyStarted)
        }
    }

    func testStartTimerForcefullyWhenAlreadyStarted() throws {
        try RestoreTimerContainer.start(type: .timer(duration: 10))
        let result = try RestoreTimerContainer.start(type: .timer(duration: 10), forceStart: true)
        XCTAssertNotNil(result.startDate)
    }

    func testPauseTimerSuccessfully() throws {
        let startDate = Date()
        let pauseDate = Date()
        try RestoreTimerContainer.start(now: startDate, type: .stopwatch)
        let result = try RestoreTimerContainer.pause(now: pauseDate)
        XCTAssertEqual(result.pausePeriods.count, 1)
        XCTAssertEqual(result.pausePeriods.first?.pause, pauseDate)
        XCTAssertNil(result.pausePeriods.first?.start)
        XCTAssertEqual(result.startDate.timeIntervalSince1970, startDate.timeIntervalSince1970, accuracy: 0.001)
    }

    func testPauseTimerThrowsErrorWhenAlreadyPaused() throws {
        try RestoreTimerContainer.start(type: .stopwatch)
        try RestoreTimerContainer.pause()
        XCTAssertThrowsError(try RestoreTimerContainer.pause()) { error in
            XCTAssertEqual(error as? PersistableTimerClientError, .timerAlreadyPaused)
        }
    }

    func testResumeTimerSuccessfully() throws {
        try RestoreTimerContainer.start(type: .stopwatch)
        try RestoreTimerContainer.pause()
        let result = try RestoreTimerContainer.resume()
        XCTAssertEqual(result.pausePeriods.count, 1)
        XCTAssertNotNil(result.pausePeriods.first?.start)
    }

    func testResumeTimerThrowsErrorWhenNotPaused() throws {
        try RestoreTimerContainer.start(type: .stopwatch)
        XCTAssertThrowsError(try RestoreTimerContainer.resume()) { error in
            XCTAssertEqual(error as? PersistableTimerClientError, .timerHasNotPaused)
        }
    }

    func testFinishTimerSuccessfullyWhenRunning() throws {
        try RestoreTimerContainer.start(type: .stopwatch)
        let result = try RestoreTimerContainer.finish()
        XCTAssertNotNil(result.stopDate)
    }

    func testFinishTimerSuccessfullyWhenPaused() throws {
        try RestoreTimerContainer.start(type: .stopwatch)
        try RestoreTimerContainer.pause()
        let result = try RestoreTimerContainer.finish()
        XCTAssertNotNil(result.stopDate)
    }

    func testFinishTimerThrowsErrorWhenNotStarted() throws {
        XCTAssertThrowsError(try RestoreTimerContainer.finish()) { error in
            XCTAssertEqual(error as? PersistableTimerClientError, .timerHasNotStarted)
        }
    }

    func testGetTimerDataThrowsErrorWhenNotStarted() throws {
        XCTAssertThrowsError(try RestoreTimerContainer.getTimerData()) { error in
            XCTAssertEqual(error as? PersistableTimerClientError, .timerHasNotStarted)
        }
    }

    func testGetTimerDataReturnsCorrectDataWhenRunning() throws {
        let startedTimerData = try RestoreTimerContainer.start(type: .stopwatch)
        let fetchedTimerData = try RestoreTimerContainer.getTimerData()
        XCTAssertEqual(fetchedTimerData.startDate, startedTimerData.startDate)
        XCTAssertEqual(fetchedTimerData.pausePeriods.count, startedTimerData.pausePeriods.count)
    }

    func testPauseTimerThrowsErrorWhenStopped() throws {
        try RestoreTimerContainer.start(type: .stopwatch)
        try RestoreTimerContainer.finish()
        XCTAssertThrowsError(try RestoreTimerContainer.pause()) { error in
            XCTAssertEqual(error as? PersistableTimerClientError, .timerHasNotStarted)
        }
    }

    func testResumeTimerThrowsErrorWhenStopped() throws {
        try RestoreTimerContainer.start(type: .stopwatch)
        try RestoreTimerContainer.pause()
        try RestoreTimerContainer.finish()
        XCTAssertThrowsError(try RestoreTimerContainer.resume()) { error in
            XCTAssertEqual(error as? PersistableTimerClientError, .timerHasNotStarted)
        }
    }

    func testElapsedTimeAndStatusReturnsRunningAndCorrectTime() throws {
        let startDate = Date()
        try RestoreTimerContainer.start(now: startDate, type: .stopwatch)
        let timerData = try RestoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus()
        XCTAssertEqual(result.status, .running)
        XCTAssertTrue(result.elapsedTime >= 0)
    }

    func testElapsedTimeAndStatusReturnsPausedAndCorrectTime() throws {
        let startDate = Date()
        try RestoreTimerContainer.start(now: startDate, type: .stopwatch)
        try RestoreTimerContainer.pause()
        let timerData = try RestoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus()
        XCTAssertEqual(result.status, .paused)
        XCTAssertTrue(result.elapsedTime >= 0)
    }

    func testElapsedTimeAndStatusReturnsStoppedAndCorrectTime() throws {
        let startDate = Date()
        try RestoreTimerContainer.start(now: startDate, type: .stopwatch)
        try RestoreTimerContainer.finish()
        XCTAssertThrowsError(try RestoreTimerContainer.getTimerData()) { error in
            XCTAssertEqual(error as? PersistableTimerClientError, .timerHasNotStarted)
        }
    }

    func testElapsedTimeAndStatusCalculatesCorrectElapsedTimeWhenRunning() throws {
        let startDate = Date()
        try RestoreTimerContainer.start(now: startDate, type: .stopwatch)

        let futureDate = startDate.addingTimeInterval(2)

        let timerData = try RestoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus(now: futureDate)

        XCTAssertEqual(result.status, .running)
        XCTAssertEqual(result.elapsedTime, 2, accuracy: 0.1)
    }

    func testElapsedTimeAndStatusCalculatesCorrectElapsedTimeWhenPaused() throws {
        let startDate = Date()
        try RestoreTimerContainer.start(now: startDate, type: .stopwatch)

        let pauseDate = startDate.addingTimeInterval(1)
        try RestoreTimerContainer.pause(now: pauseDate)

        let futureDate = startDate.addingTimeInterval(3)

        let timerData = try RestoreTimerContainer.getTimerData()
        let result = timerData.elapsedTimeAndStatus(now: futureDate)

        XCTAssertEqual(result.status, .paused)
        XCTAssertEqual(result.elapsedTime, 1, accuracy: 0.1)
    }

    func testElapsedTimeAndStatusCalculatesCorrectElapsedTimeWhenStopped() throws {
        let startDate = Date()
        try RestoreTimerContainer.start(now: startDate, type: .timer(duration: 10))

        let stopDate = startDate.addingTimeInterval(2)
        let timerData = try RestoreTimerContainer.finish(now: stopDate)
        let futureDate = stopDate.addingTimeInterval(10)
        let result = timerData.elapsedTimeAndStatus(now: futureDate)

        XCTAssertEqual(result.status, .finished)
        XCTAssertEqual(result.elapsedTime, 2, accuracy: 0.1)
    }
}
