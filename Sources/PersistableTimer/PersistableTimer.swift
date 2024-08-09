import AsyncAlgorithms
import Foundation
import PersistableTimerCore

/// A class for managing a persistable timer, capable of restoring state after application termination.
public final class PersistableTimer {
    /// An async stream of timer states, providing continuous updates.
    public var timeStream: AsyncStream<TimerState> {
        if !shouldEmitTimeStream {
            assertionFailure("Attempted to access timeStream while shouldEmitTimeStream is set to false.")
        }
        return stream.stream
    }

    private var restoreTimerData: RestoreTimerData?
    private var timerType: TimerType?
    private var stream = AsyncStream<TimerState>.makeStream()
    private let container: RestoreTimerContainer
    private let now: () -> Date

    /// The interval at which the timer updates its elapsed time.
    let updateInterval: TimeInterval
    let useFoundationTimer: Bool
    let shouldEmitTimeStream: Bool
    let id: String?

    /// Initializes a new PersistableTimer.
    ///
    /// - Parameters:
    ///   - dataSourceType: The type of data source to use, either in-memory or UserDefaults.
    ///   - updateInterval: The interval at which the timer updates, defaults to 1 second.
    ///   - now: A closure providing the current date and time, defaults to `Date()`.
    public init(
        id: String? = nil,
        dataSourceType: DataSourceType,
        shouldEmitTimeStream: Bool = true,
        updateInterval: TimeInterval = 1,
        useFoundationTimer: Bool = false,
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
        self.id = id
        self.now = now
        self.updateInterval = updateInterval
        self.useFoundationTimer = useFoundationTimer
        self.shouldEmitTimeStream = shouldEmitTimeStream
    }

    deinit {
        timerType?.cancel()
    }

    /// Retrieves the persisted timer data if available.
    ///
    /// - Throws: Any errors encountered while fetching the timer data.
    /// - Returns: The `RestoreTimerData` if available.
    public func getTimerData() throws -> RestoreTimerData? {
        try container.getTimerData(id: id)
    }

    /// Checks if a timer is currently running.
    ///
    /// - Returns: A Boolean value indicating whether a timer is running.
    public func isTimerRunning() -> Bool {
        container.isTimerRunning(id: id)
    }

    /// Restores the timer from the last known state and starts the timer if it was running.
    ///
    /// - Throws: Any errors encountered while restoring the timer.
    /// - Returns: The restored `RestoreTimerData`.
    @discardableResult
    public func restore() throws -> RestoreTimerData {
        let now = now()
        let restoreTimerData = try container.getTimerData(id: id)
        let timerState = restoreTimerData.elapsedTimeAndStatus(now: now)

        self.stream.continuation.yieldIfNeeded(timerState, enable: shouldEmitTimeStream)
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
    @discardableResult
    public func start(type: RestoreType, forceStart: Bool = false) async throws -> RestoreTimerData {
        let now = now()
        let restoreTimerData = try await container.start(
            id: id,
            now: now,
            type: type,
            forceStart: forceStart
        )
        self.restoreTimerData = restoreTimerData

        stream.continuation.yieldIfNeeded(restoreTimerData.elapsedTimeAndStatus(now: now), enable: shouldEmitTimeStream)
        startTimerIfNeeded()

        return restoreTimerData
    }

    /// Resumes a paused timer.
    ///
    /// - Throws: Any errors encountered while resuming the timer.
    @discardableResult
    public func resume() async throws -> RestoreTimerData {
        let now = now()
        let restoreTimerData = try await container.resume(id: id, now: now)
        self.restoreTimerData = restoreTimerData

        stream.continuation.yieldIfNeeded(restoreTimerData.elapsedTimeAndStatus(now: now), enable: shouldEmitTimeStream)
        startTimerIfNeeded()

        return restoreTimerData
    }

    /// Pauses the currently running timer.
    ///
    /// - Throws: Any errors encountered while pausing the timer.
    @discardableResult
    public func pause() async throws -> RestoreTimerData {
        let now = now()
        let restoreTimerData = try await container.pause(id: id, now: now)
        self.restoreTimerData = restoreTimerData

        stream.continuation.yieldIfNeeded(restoreTimerData.elapsedTimeAndStatus(now: now), enable: shouldEmitTimeStream)
        invalidate()

        return restoreTimerData
    }

    /// Finishes the timer and optionally resets the elapsed time.
    ///
    /// - Parameter isResetTime: A Boolean value indicating whether to reset the elapsed time upon finishing.
    /// - Throws: Any errors encountered while finishing the timer.
    @discardableResult
    public func finish(isResetTime: Bool = false) async throws -> RestoreTimerData {
        do {
            let now = now()
            let restoreTimerData = try await container.finish(id: id, now: now)
            var elapsedTimeAndStatus = restoreTimerData.elapsedTimeAndStatus(now: now)
            if isResetTime {
                elapsedTimeAndStatus.elapsedTime = 0
            }
            self.restoreTimerData = restoreTimerData
            stream.continuation.yieldIfNeeded(elapsedTimeAndStatus, enable: shouldEmitTimeStream)
            invalidate(isFinish: true)

            return restoreTimerData
        } catch {
            invalidate(isFinish: true)
            throw error
        }
    }

    /// Starts the timer if it's not already running.
    private func startTimerIfNeeded() {
        guard shouldEmitTimeStream else {
            return
        }

        timerType?.cancel()
        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *), !useFoundationTimer {
            self.timerType = .asyncTimerSequence(
                Task { [weak self] in
                    let timer = AsyncTimerSequence(interval: .seconds(self?.updateInterval ?? 1), clock: .continuous)
                    for await _ in timer {
                        self?.updateTimerStream()
                    }
                }
            )
        } else {
            let timer = Timer(fire: now(), interval: updateInterval, repeats: true) { [weak self] timer in
                self?.updateTimerStream()
            }
            self.timerType = .timer(timer)
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Invalidates the current timer and optionally finishes the stream.
    ///
    /// - Parameter isFinish: A Boolean value indicating whether to finish the stream.
    private func invalidate(isFinish: Bool = false) {
        timerType?.cancel()
        timerType = nil
        if isFinish && shouldEmitTimeStream {
            stream.continuation.finish()
            stream = AsyncStream<TimerState>.makeStream()
        }
    }

    private func updateTimerStream() {
        guard let restoreTimerData = try? restoreTimerData ?? container.getTimerData(id: id)
        else {
            timerType?.cancel()
            return
        }
        let timerState = restoreTimerData.elapsedTimeAndStatus(now: now())
        stream.continuation.yieldIfNeeded(timerState, enable: shouldEmitTimeStream)
    }
}

private extension PersistableTimer {
    private enum TimerType {
        case timer(Timer)
        case asyncTimerSequence(Task<Void, Never>)

        func cancel() {
            switch self {
            case .timer(let timer):
                timer.invalidate()
            case .asyncTimerSequence(let task):
                task.cancel()
            }
        }
    }
}

extension AsyncStream.Continuation {
    @discardableResult
    func yieldIfNeeded(_ value: Element, enable: Bool) -> AsyncStream<Element>.Continuation.YieldResult? {
        if enable {
            return yield(value)
        } else {
            return nil
        }
    }
}
