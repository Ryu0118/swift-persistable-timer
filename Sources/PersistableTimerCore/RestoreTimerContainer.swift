import Foundation

/// A container for managing and persisting timer data.
/// Supports handling multiple timers using unique identifiers.
public struct RestoreTimerContainer: Sendable {
    /// A constant structure for defining keys used in data persistence.
    private enum Const {
        static let persistableTimerKey = "persistableTimerKey"

        static func persistableTimerKey(id: String?) -> String {
            if let id {
                return "\(persistableTimerKey)_\(id)"
            } else {
                return persistableTimerKey
            }
        }
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

    /// Retrieves the persisted timer data for a given identifier.
    ///
    /// - Parameter id: An optional identifier for the timer. If `nil`, retrieves the default timer data.
    /// - Throws: `PersistableTimerClientError.timerHasNotStarted` if no timer data is found.
    /// - Returns: The retrieved `RestoreTimerData`.
    public func getTimerData(id: String? = nil) throws -> RestoreTimerData {
        guard let restoreTimerData = dataSource.data(forKey: Const.persistableTimerKey(id: id), type: RestoreTimerData.self) else {
            throw PersistableTimerClientError.timerHasNotStarted
        }
        return restoreTimerData
    }

    /// Checks if a timer is currently running for a given identifier.
    ///
    /// - Parameter id: An optional identifier for the timer. If `nil`, checks the default timer.
    /// - Returns: A Boolean value indicating whether a timer is running.
    public func isTimerRunning(id: String? = nil) -> Bool {
        dataSource.data(forKey: Const.persistableTimerKey(id: id), type: RestoreTimerData.self) != nil
    }

    /// Starts a new timer with an optional identifier.
    ///
    /// - Parameters:
    ///   - id: An optional identifier for the timer. If `nil`, starts the default timer.
    ///   - now: The current date and time, defaults to `Date()`.
    ///   - type: The type of restore operation, either stopwatch or timer.
    ///   - forceStart: A Boolean value to force start the timer, ignoring if another timer is already running.
    /// - Throws: `PersistableTimerClientError.timerAlreadyStarted` if a timer is already running and `forceStart` is `false`.
    /// - Returns: The newly created `RestoreTimerData`.
    @discardableResult
    public func start(
        id: String? = nil,
        now: Date = Date(),
        type: RestoreType,
        forceStart: Bool = false
    ) async throws -> RestoreTimerData {
        if !forceStart {
            guard (try? getTimerData(id: id)) == nil else {
                throw PersistableTimerClientError.timerAlreadyStarted
            }
        }
        let restoreTimerData = RestoreTimerData(
            startDate: now,
            pausePeriods: [],
            type: type,
            stopDate: nil
        )
        try await dataSource.set(restoreTimerData, forKey: Const.persistableTimerKey(id: id))
        return restoreTimerData
    }

    /// Resumes a paused timer with an optional identifier.
    ///
    /// - Parameters:
    ///   - id: An optional identifier for the timer. If `nil`, resumes the default timer.
    ///   - now: The current date and time, defaults to `Date()`.
    /// - Throws: `PersistableTimerClientError.timerHasNotPaused` if the timer is not in a paused state.
    /// - Returns: The updated `RestoreTimerData` after resuming.
    @discardableResult
    public func resume(id: String? = nil, now: Date = Date()) async throws -> RestoreTimerData {
        var restoreTimerData = try getTimerData(id: id)
        guard let lastPausePeriod = restoreTimerData.pausePeriods.last,
              lastPausePeriod.start == nil
        else {
            throw PersistableTimerClientError.timerHasNotPaused
        }
        restoreTimerData.pausePeriods[restoreTimerData.pausePeriods.endIndex - 1].start = now
        try await dataSource.set(restoreTimerData, forKey: Const.persistableTimerKey(id: id))
        return restoreTimerData
    }

    /// Pauses a running timer with an optional identifier.
    ///
    /// - Parameters:
    ///   - id: An optional identifier for the timer. If `nil`, pauses the default timer.
    ///   - now: The current date and time, defaults to `Date()`.
    /// - Throws: `PersistableTimerClientError.timerAlreadyPaused` if the timer is already paused.
    /// - Returns: The updated `RestoreTimerData` after pausing.
    @discardableResult
    public func pause(id: String? = nil, now: Date = Date()) async throws -> RestoreTimerData {
        var restoreTimerData = try getTimerData(id: id)
        guard restoreTimerData.pausePeriods.allSatisfy({ $0.start != nil }) else {
            throw PersistableTimerClientError.timerAlreadyPaused
        }
        restoreTimerData.pausePeriods.append(
            PausePeriod(
                pause: now,
                start: nil
            )
        )
        try await dataSource.set(restoreTimerData, forKey: Const.persistableTimerKey(id: id))
        return restoreTimerData
    }

    /// Finishes the current timer with an optional identifier.
    ///
    /// - Parameters:
    ///   - id: An optional identifier for the timer. If `nil`, finishes the default timer.
    ///   - now: The current date and time, defaults to `Date()`.
    /// - Returns: The final `RestoreTimerData`.
    @discardableResult
    public func finish(id: String? = nil, now: Date = Date()) async throws -> RestoreTimerData {
        var restoreTimerData = try getTimerData(id: id)
        restoreTimerData.stopDate = now
        await dataSource.setNil(forKey: Const.persistableTimerKey(id: id))
        return restoreTimerData
    }

    /// Finishes all running timers.
    ///
    /// - Parameter now: The current date and time, defaults to `Date()`.
    /// - Returns: A dictionary containing the final `RestoreTimerData` for all finished timers, keyed by their identifiers.
    @discardableResult
    public func finishAll(now: Date = Date()) async throws -> [String?: RestoreTimerData] {
        let keys = dataSource.keys().filter { $0.hasPrefix(Const.persistableTimerKey) }
        return try await withThrowingTaskGroup(
            of: (String?, RestoreTimerData).self,
            returning: [String?: RestoreTimerData].self
        ) { group in
            for key in keys {
                group.addTask {
                    if let id = key.components(separatedBy: "_").last,
                       id != Const.persistableTimerKey
                    {
                        return (id, try await self.finish(id: id, now: now))
                    } else {
                        return (nil, try await self.finish(now: now))
                    }
                }
            }

            return try await group.reduce(into: [String?: RestoreTimerData]()) { partialResult, data in
                partialResult.updateValue(data.1, forKey: data.0)
            }
        }
    }
}

/// Errors specific to the PersistableTimerClient.
public enum PersistableTimerClientError: Error, Sendable {
    case timerHasNotStarted
    case timerHasNotPaused
    case timerAlreadyPaused
    case timerAlreadyStarted
}
