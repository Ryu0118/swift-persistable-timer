# PersistableTimer
Persistent timers and stopwatches ensuring seamless state restoration.

## Example
- [Example App](https://github.com/Ryu0118/swift-persistable-timer/tree/main/Examples/TimerTest)

## Usage
Instantiate PersistableTimer with your choice of data source (UserDefaults or in-memory for testing and previewing purposes):
```Swift
import PersistableTimer

let timer = PersistableTimer(dataSourceType: .inMemory)
let timer = PersistableTimer(dataSourceType: .userDefaults(.standard))
let timer = PersistableTimer(dataSourceType: .userDefaults(.standard), updateInterval: 0.5)
```

### Starting a Timer
Start a stopwatch or countdown timer. Optionally force the start of a new timer even if another is running.

```Swift
try await timer.start(type: .stopwatch)
// Start a countdown timer with a duration of 100 seconds
try await timer.start(type: .timer(duration: 100))
```
### Pausing, Resuming, and Finishing
Pause and resume a running timer, or mark it as finished:
```Swift
try await timer.pause()
try await timer.resume()
try await timer.finish(isResetTime: false)
```
### Restoring Timer State
Restore the timer's state after an app restart:
```Swift
try timer.restore()
```

### Timer Updates
Subscribe to timer updates using the timeStream:
```Swift
for await timeState in timer.timeStream {
    // Update your UI with the current timeState
    print(timerState.time)
}
```

