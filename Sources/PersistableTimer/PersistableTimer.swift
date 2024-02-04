import Foundation
import PersistableTimerCore

public enum DataSourceType {
    case userDefaults(UserDefaults)
    case inMemory
}

public final class PersistableTimer {
    public var timeStream: AsyncStream<TimerState> {
        stream.stream
    }

    private var restoreTimerData: RestoreTimerData?
    private var timer: Timer?
    private var stream = AsyncStream<TimerState>.makeStream()
    private let container: RestoreTimerContainer
    private let now: () -> Date

    let updateInterval: TimeInterval

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

    public func getTimerData() throws -> RestoreTimerData? {
        try container.getTimerData()
    }

    public func isTimerRunning() -> Bool {
        container.isTimerRunning()
    }

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

    public func resume() async throws {
        let restoreTimerData = try await container.resume(now: now())
        self.restoreTimerData = restoreTimerData

        stream.continuation.yield(restoreTimerData.elapsedTimeAndStatus(now: now()))
        startTimerIfNeeded()
    }

    public func pause() async throws {
        let restoreTimerData = try await container.pause(now: now())
        self.restoreTimerData = restoreTimerData

        stream.continuation.yield(restoreTimerData.elapsedTimeAndStatus(now: now()))
        invalidate()
    }

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

    private func invalidate(isFinish: Bool = false) {
        timer?.invalidate()
        timer = nil
        if isFinish {
            stream.continuation.finish()
            stream = AsyncStream<TimerState>.makeStream()
        }
    }
}
