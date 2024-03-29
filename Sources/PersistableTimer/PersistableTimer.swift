import Foundation
import PersistableTimerCore

/// A class for managing a persistable timer, capable of restoring state after application termination.
public final class PersistableTimer {
    /// An async stream of timer states, providing continuous updates.
    public var timeStream: AsyncStream<TimerState> {
        stream.stream
    }

    private var restoreTimerData: RestoreTimerData?
    private var timer: Timer?
    private var stream = AsyncStream<TimerState>.makeStream()
    private let container: RestoreTimerContainer
    private let now: () -> Date

    /// The interval at which the timer updates its elapsed time.
    let updateInterval: TimeInterval

    /// Initializes a new PersistableTimer.
    ///
    /// - Parameters:
    ///   - dataSourceType: The type of data source to use, either in-memory or UserDefaults.
    ///   - updateInterval: The interval at which the timer updates, defaults to 1 second.
    ///   - now: A closure providing the current date and time, defaults to `Date()`.
    public init(
        dataSourceType: DataSourceType,
        updateInterval: TimeInterval = 1,
        now: @escaping () -> Date = { Date() }
    ) {
        let dataSource: any DataSource =
            switch dataSourceType {
            case .inMemory:
                InMemoryDataSource()
            case .userDefaults(let userDefaults):
                UserDefaultsClient(userDefaults: userDefaults)
            }
        container = RestoreTimerContainer(dataSource: dataSource)
        self.now = now
        self.updateInterval = updateInterval
    }

    /// Retrieves the persisted timer data if available.
    ///
    /// - Throws: Any errors encountered while fetching the timer data.
    /// - Returns: The `RestoreTimerData` if available.
    public func getTimerData() throws -> RestoreTimerData? {
        try container.getTimerData()
    }

    /// Checks if a timer is currently running.
    ///
    /// - Returns: A Boolean value indicating whether a timer is running.
    public func isTimerRunning() -> Bool {
        container.isTimerRunning()
    }

    /// Restores the timer from the last known state and starts the timer if it was running.
    ///
    /// - Throws: Any errors encountered while restoring the timer.
    /// - Returns: The restored `RestoreTimerData`.
    @discardableResult
    public func restore() throws -> RestoreTimerData {
        let restoreTimerData = try container.getTimerData()
        let timerState = restoreTimerData.elapsedTimeAndStatus(now: now())

        self.stream.continuation.yield(timerState)
        if timerState.status == .running {
            startTimerIfNeeded()
        }

        return restoreTimerData
    }

    /// Starts the timer with the specified type, optionally forcing a start even if a timer is already running.
    ///
    /// - Parameters:
    ///   - type: The type of timer, either stopwatch or countdown.
    ///   - forceStart: A Boolean value to force start the timer, ignoring if another timer is already running.
    /// - Throws: Any errors encountered while starting the timer.
    public func start(type: RestoreType, forceStart: Bool = false) async throws {
        let restoreTimerData = try await container.start(
            now: now(),
            type: type,
            forceStart: forceStart
        )
        self.restoreTimerData = restoreTimerData

        stream.continuation.yield(restoreTimerData.elapsedTimeAndStatus(now: now()))
        startTimerIfNeeded()
    }

    /// Resumes a paused timer.
    ///
    /// - Throws: Any errors encountered while resuming the timer.
    public func resume() async throws {
        let restoreTimerData = try await container.resume(now: now())
        self.restoreTimerData = restoreTimerData

        stream.continuation.yield(restoreTimerData.elapsedTimeAndStatus(now: now()))
        startTimerIfNeeded()
    }

    /// Pauses the currently running timer.
    ///
    /// - Throws: Any errors encountered while pausing the timer.
    public func pause() async throws {
        let restoreTimerData = try await container.pause(now: now())
        self.restoreTimerData = restoreTimerData

        stream.continuation.yield(restoreTimerData.elapsedTimeAndStatus(now: now()))
        invalidate()
    }

    /// Finishes the timer and optionally resets the elapsed time.
    ///
    /// - Parameter isResetTime: A Boolean value indicating whether to reset the elapsed time upon finishing.
    /// - Throws: Any errors encountered while finishing the timer.
    public func finish(isResetTime: Bool = false) async throws {
        do {
            let restoreTimerData = try await container.finish(now: now())
            var elapsedTimeAndStatus = restoreTimerData.elapsedTimeAndStatus(now: now())
            if isResetTime {
                elapsedTimeAndStatus.elapsedTime = 0
            }
            self.restoreTimerData = restoreTimerData
            stream.continuation.yield(elapsedTimeAndStatus)
            invalidate(isFinish: true)
        } catch {
            invalidate(isFinish: true)
            throw error
        }
    }

    /// Starts the timer if it's not already running.
    private func startTimerIfNeeded() {
        let timer = Timer(fire: now(), interval: updateInterval, repeats: true) { [weak self] timer in
            guard let self,
                  let restoreTimerData = try? self.restoreTimerData ?? self.container.getTimerData()
            else {
                timer.invalidate()
                return
            }
            let timerState = restoreTimerData.elapsedTimeAndStatus(now: self.now())
            self.stream.continuation.yield(timerState)
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Invalidates the current timer and optionally finishes the stream.
    ///
    /// - Parameter isFinish: A Boolean value indicating whether to finish the stream.
    private func invalidate(isFinish: Bool = false) {
        timer?.invalidate()
        timer = nil
        if isFinish {
            stream.continuation.finish()
            stream = AsyncStream<TimerState>.makeStream()
        }
    }
}
