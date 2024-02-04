import Foundation

public struct RestoreTimerContainer {
    private enum Const {
        static let persistableTimerKey = "persistableTimerKey"
    }
    private let userDefaultsClient: any UserDefaultsClient

    public init(userDefaults: UserDefaults) {
        self.userDefaultsClient = UserDefaultsClientImpl(userDefaults: userDefaults)
    }

    #if DEBUG
    init(userDefaultsClient: any UserDefaultsClient) {
        self.userDefaultsClient = userDefaultsClient
    }
    #endif

    public func getTimerData() throws -> RestoreTimerData {
        guard let restoreTimerData = userDefaultsClient.data(forKey: Const.persistableTimerKey, type: RestoreTimerData.self) else {
            throw PersistableTimerClientError.timerHasNotStarted
        }
        return restoreTimerData
    }

    @discardableResult
    public func start(now: Date = Date(), forceStart: Bool = false) throws -> RestoreTimerData {
        if !forceStart {
            guard (try? getTimerData()) == nil else {
                throw PersistableTimerClientError.timerAlreadyStarted
            }
        }
        let restoreTimerData = RestoreTimerData(
            startDate: Date(),
            pausePeriods: [],
            stopDate: nil
        )
        try userDefaultsClient.set(restoreTimerData, forKey: Const.persistableTimerKey)
        return restoreTimerData
    }

    @discardableResult
    public func resume(now: Date = Date()) throws -> RestoreTimerData {
        var restoreTimerData = try getTimerData()
        guard let lastPausePeriod = restoreTimerData.pausePeriods.last,
              lastPausePeriod.start == nil
        else {
            throw PersistableTimerClientError.timerHasNotPaused
        }
        restoreTimerData.pausePeriods[restoreTimerData.pausePeriods.endIndex - 1].start = now
        try userDefaultsClient.set(restoreTimerData, forKey: Const.persistableTimerKey)
        return restoreTimerData
    }

    @discardableResult
    public func pause(now: Date = Date()) throws -> RestoreTimerData {
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
        try userDefaultsClient.set(restoreTimerData, forKey: Const.persistableTimerKey)
        return restoreTimerData
    }

    @discardableResult
    public func finish(now: Date = Date()) throws -> RestoreTimerData {
        var restoreTimerData = try getTimerData()
        restoreTimerData.stopDate = now
        userDefaultsClient.set(nil, forKey: Const.persistableTimerKey)
        return restoreTimerData
    }
}

public enum PersistableTimerClientError: Error {
    case timerHasNotStarted
    case timerHasNotPaused
    case timerAlreadyPaused
    case timerAlreadyStarted
}
