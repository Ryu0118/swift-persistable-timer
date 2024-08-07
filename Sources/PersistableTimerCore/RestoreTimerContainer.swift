import Foundation

/// A container for managing and persisting timer data.
public struct RestoreTimerContainer {
    /// A constant structure for defining keys used in data persistence.
    private enum Const {
        static let persistableTimerKey = "persistableTimerKey"
    }

    /// The data source for persisting and retrieving timer data.
    private let dataSource: any DataSource

    /// Initializes a new container with a given UserDefaults instance.
    ///
    /// - Parameter userDefaults: An instance of UserDefaults to be used as the data source.
    public init(userDefaults: UserDefaults) {
        self.dataSource = UserDefaultsClient(userDefaults: userDefaults)
    }

    /// Initializes a new container with a given data source.
    ///
    /// - Parameter dataSource: An instance conforming to `DataSource` protocol.
    package init(dataSource: any DataSource) {
        self.dataSource = dataSource
    }

    /// Retrieves the persisted timer data.
    ///
    /// - Throws: `PersistableTimerClientError.timerHasNotStarted` if no timer data is found.
    /// - Returns: The retrieved `RestoreTimerData`.
    public func getTimerData() throws -> RestoreTimerData {
        guard let restoreTimerData = dataSource.data(forKey: Const.persistableTimerKey, type: RestoreTimerData.self) else {
            throw PersistableTimerClientError.timerHasNotStarted
        }
        return restoreTimerData
    }

    /// Checks if a timer is currently running.
    ///
    /// - Returns: A Boolean value indicating whether a timer is running.
    public func isTimerRunning() -> Bool {
        dataSource.data(forKey: Const.persistableTimerKey, type: RestoreTimerData.self) != nil
    }

    /// Starts a new timer.
    ///
    /// - Parameters:
    ///   - now: The current date and time, defaults to `Date()`.
    ///   - type: The type of restore operation, either stopwatch or timer.
    ///   - forceStart: A Boolean value to force start the timer, ignoring if another timer is already running.
    /// - Throws: `PersistableTimerClientError.timerAlreadyStarted` if a timer is already running and `forceStart` is `false`.
    /// - Returns: The newly created `RestoreTimerData`.
    @discardableResult
    public func start(
        now: Date = Date(),
        type: RestoreType,
        forceStart: Bool = false
    ) async throws -> RestoreTimerData {
        if !forceStart {
            guard (try? getTimerData()) == nil else {
                throw PersistableTimerClientError.timerAlreadyStarted
            }
        }
        let restoreTimerData = RestoreTimerData(
            startDate: Date(),
            pausePeriods: [],
            type: type,
            stopDate: nil
        )
        try await dataSource.set(restoreTimerData, forKey: Const.persistableTimerKey)
        return restoreTimerData
    }

    /// Resumes a paused timer.
    ///
    /// - Parameter now: The current date and time, defaults to `Date()`.
    /// - Throws: `PersistableTimerClientError.timerHasNotPaused` if the timer is not in a paused state.
    /// - Returns: The updated `RestoreTimerData` after resuming.
    @discardableResult
    public func resume(now: Date = Date()) async throws -> RestoreTimerData {
        var restoreTimerData = try getTimerData()
        guard let lastPausePeriod = restoreTimerData.pausePeriods.last,
              lastPausePeriod.start == nil
        else {
            throw PersistableTimerClientError.timerHasNotPaused
        }
        restoreTimerData.pausePeriods[restoreTimerData.pausePeriods.endIndex - 1].start = now
        try await dataSource.set(restoreTimerData, forKey: Const.persistableTimerKey)
        return restoreTimerData
    }

    /// Pauses a running timer.
    ///
    /// - Parameter now: The current date and time, defaults to `Date()`.
    /// - Throws: `PersistableTimerClientError.timerAlreadyPaused` if the timer is already paused.
    /// - Returns: The updated `RestoreTimerData` after pausing.
    @discardableResult
    public func pause(now: Date = Date()) async throws -> RestoreTimerData {
        var restoreTimerData = try getTimerData()
        guard restoreTimerData.pausePeriods.allSatisfy({ $0.start != nil }) else {
            throw PersistableTimerClientError.timerAlreadyPaused
        }
        restoreTimerData.pausePeriods.append(
            PausePeriod(
                pause: now,
                start: nil
            )
        )
        try await dataSource.set(restoreTimerData, forKey: Const.persistableTimerKey)
        return restoreTimerData
    }

    /// Finishes the current timer.
    ///
    /// - Parameter now: The current date and time, defaults to `Date()`.
    /// - Returns: The final `RestoreTimerData`.
    @discardableResult
    public func finish(now: Date = Date()) async throws -> RestoreTimerData {
        var restoreTimerData = try getTimerData()
        restoreTimerData.stopDate = now
        await dataSource.set(nil, forKey: Const.persistableTimerKey)
        return restoreTimerData
    }
}

/// Errors specific to the PersistableTimerClient.
public enum PersistableTimerClientError: Error, Sendable {
    case timerHasNotStarted
    case timerHasNotPaused
    case timerAlreadyPaused
    case timerAlreadyStarted
}
