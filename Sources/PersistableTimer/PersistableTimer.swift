import Foundation
import PersistableTimerCore

public enum DataSource {
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

    public init(
        dataSource: DataSource,
        now: @escaping () -> Date = { Date() }
    ) {
        let userDefaultsClient: any UserDefaultsClient =
        switch dataSource {
        case .inMemory:
            MockUserDefaultsClient()
        case .userDefaults(let userDefaults):
            UserDefaultsClientImpl(userDefaults: userDefaults)
        }
        container = RestoreTimerContainer(userDefaultsClient: userDefaultsClient)
        self.now = now
    }

    #if DEBUG
    init(container: RestoreTimerContainer) {
        self.container = container
        self.now = { Date() }
    }
    #endif

    public func getTimerData() -> RestoreTimerData? {
        try? container.getTimerData()
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

    public func finish() async throws {
        let restoreTimerData = try await container.finish(now: now())
        self.restoreTimerData = restoreTimerData

        stream.continuation.yield(restoreTimerData.elapsedTimeAndStatus(now: now()))
        invalidate(isFinish: true)
    }

    private func startTimerIfNeeded() {
        let timer = Timer(fire: now(), interval: 1, repeats: true) { [weak self] timer in
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
