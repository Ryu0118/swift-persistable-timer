import Foundation

public struct RestoreTimerContainer {
    private enum Const {
        static let persistableTimerKey = "persistableTimerKey"
    }
    private let dataSource: any DataSource

    public init(userDefaults: UserDefaults) {
        self.dataSource = UserDefaultsClient(userDefaults: userDefaults)
    }

    package init(dataSource: any DataSource) {
        self.dataSource = dataSource
    }

    public func getTimerData() throws -> RestoreTimerData {
        guard let restoreTimerData = dataSource.data(forKey: Const.persistableTimerKey, type: RestoreTimerData.self) else {
            throw PersistableTimerClientError.timerHasNotStarted
        }
        return restoreTimerData
    }

    public func isTimerRunning() -> Bool {
        dataSource.data(forKey: Const.persistableTimerKey, type: RestoreTimerData.self) != nil
    }

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
        print(dataSource.data(forKey: Const.persistableTimerKey, type: RestoreTimerData.self))
        return restoreTimerData
    }

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

    @discardableResult
    public func finish(now: Date = Date()) async throws -> RestoreTimerData {
        var restoreTimerData = try getTimerData()
        restoreTimerData.stopDate = now
        await dataSource.set(nil, forKey: Const.persistableTimerKey)
        return restoreTimerData
    }
}

public enum PersistableTimerClientError: Error {
    case timerHasNotStarted
    case timerHasNotPaused
    case timerAlreadyPaused
    case timerAlreadyStarted
}
