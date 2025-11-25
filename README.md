# PersistableTimer

PersistableTimer is a Swift library that provides persistent timers and stopwatches with seamless state restoration — even across app restarts. It supports both countdown timers and stopwatches, with flexible data sources such as UserDefaults (for production) and in-memory storage (for testing or previews).

## Features

- **Persistent State:** Restore timer state automatically after app termination or restart.
- **Dual Modes:** Choose between a running stopwatch and a countdown timer.
- **Real-time Updates:** Subscribe to continuous timer updates via an asynchronous stream.
- **Dynamic Time Adjustment:** Add extra time to a countdown or extra elapsed time to a stopwatch.
- **SwiftUI Integration:** Easily display timer states using extensions from `PersistableTimerText`.

## Example Application

See the [Example App](https://github.com/Ryu0118/swift-persistable-timer/tree/main/Examples/TimerTest) for a complete SwiftUI implementation.

## Installation

Add the package dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Ryu0118/swift-persistable-timer.git", from: "0.7.0")
],
```

Then add the desired products (`PersistableTimer`, `PersistableTimerCore`, or `PersistableTimerText`) to your target dependencies.

## Usage

### Basic Setup

```swift
import PersistableTimer

// For production (with persistence):
let timer = PersistableTimer(dataSourceType: .userDefaults(.standard))

// For testing or previews:
let timer = PersistableTimer(dataSourceType: .inMemory)
```

### Stopwatch Mode

```swift
// Start a stopwatch
try await timer.start(type: .stopwatch)

// Pause and resume
try await timer.pause()
try await timer.resume()

// Add extra elapsed time (moves start date back by 5 seconds)
try await timer.addElapsedTime(5)

// Finish the stopwatch
try await timer.finish()
```

### Countdown Timer Mode

```swift
// Start a 100-second countdown
try await timer.start(type: .timer(duration: 100))

// Add extra time to the countdown
try await timer.addRemainingTime(30) // Now 130 seconds total

// Force restart even if already running
try await timer.start(type: .timer(duration: 60), forceStart: true)
```

### Real-time Updates with SwiftUI

```swift
import SwiftUI
import PersistableTimerText

struct TimerView: View {
    @State private var timerState: TimerState?
    let timer = PersistableTimer(dataSourceType: .userDefaults(.standard))

    var body: some View {
        VStack {
            // Automatic timer display
            Text(timerState: timerState)
                .font(.largeTitle)

            HStack {
                Button("Start") {
                    Task { try? await timer.start(type: .timer(duration: 60)) }
                }
                Button("Pause") {
                    Task { try? await timer.pause() }
                }
                Button("Resume") {
                    Task { try? await timer.resume() }
                }
            }
        }
        .onAppear {
            // Restore timer state after app restart
            try? timer.restore()
        }
    }
}
```

### Managing Multiple Timers

Use unique IDs to manage multiple timers simultaneously:

```swift
let workoutTimer = PersistableTimer(
    id: "workout",
    dataSourceType: .userDefaults(.standard)
)

let restTimer = PersistableTimer(
    id: "rest",
    dataSourceType: .userDefaults(.standard)
)

// Each timer maintains its own state
try await workoutTimer.start(type: .timer(duration: 300))
try await restTimer.start(type: .timer(duration: 60))
```

### Advanced Configuration

```swift
let timer = PersistableTimer(
    id: "custom",
    dataSourceType: .userDefaults(.standard),
    shouldEmitTimeStream: true,      // Enable real-time updates
    updateInterval: 0.1,              // Update every 100ms (default: 1s)
    useFoundationTimer: false,        // Use AsyncTimerSequence (default)
    now: { Date() }                   // Custom date provider
)
```

### Accessing Timer State

```swift
// Check if timer is running
if timer.isTimerRunning() {
    print("Timer is active")
}

// Get current timer data
if let data = try? timer.getTimerData() {
    print("Started at: \(data.startDate)")
    print("Type: \(data.type)")
}

// Subscribe to updates
for await state in timer.timeStream {
    print("Elapsed: \(state.elapsedTime)s")
    print("Status: \(state.status)")

    switch state.type {
    case .stopwatch:
        print("Stopwatch time: \(state.time)s")
    case .timer(let duration):
        print("Remaining: \(state.time)s / \(duration)s")
    }
}
```

### Error Handling

```swift
do {
    try await timer.start(type: .stopwatch)
} catch PersistableTimerClientError.timerAlreadyStarted {
    print("Timer is already running")
} catch {
    print("Failed to start timer: \(error)")
}

// Common errors:
// - .timerAlreadyStarted: Cannot start when already running (use forceStart: true)
// - .timerAlreadyPaused: Cannot pause when already paused
// - .timerHasNotPaused: Cannot resume when not paused
// - .timerHasNotStarted: Cannot perform operation on non-existent timer
// - .invalidTimerType: Wrong operation for timer type (e.g., addRemainingTime on stopwatch)
```

## API Reference

### PersistableTimer

| Method | Description |
|--------|-------------|
| `start(type:forceStart:)` | Start a new timer (stopwatch or countdown) |
| `pause()` | Pause the running timer |
| `resume()` | Resume a paused timer |
| `finish(isResetTime:)` | Finish the timer, optionally resetting elapsed time |
| `restore()` | Restore timer state after app restart |
| `addElapsedTime(_:)` | Add elapsed time to stopwatch (moves start date back) |
| `addRemainingTime(_:)` | Add time to countdown timer |
| `isTimerRunning()` | Check if timer is currently active |
| `getTimerData()` | Get the current timer data |

### Core Types

**TimerState** - Complete timer state with computed properties
- `elapsedTime: TimeInterval` - Total elapsed time (adjusted for pauses)
- `status: TimerStatus` - `.running`, `.paused`, or `.finished`
- `type: RestoreType` - `.stopwatch` or `.timer(duration:)`
- `time: TimeInterval` - Elapsed time for stopwatch, remaining for countdown
- `displayDate: Date` - Date for UI display

**RestoreType** - Timer operation mode
- `.stopwatch` - Count up from zero
- `.timer(duration: TimeInterval)` - Count down from duration

**DataSourceType** - Storage backend
- `.userDefaults(UserDefaults)` - Persistent storage
- `.inMemory` - Temporary storage (testing/previews)

### SwiftUI Text Extension

```swift
Text(timerState: timerState, countsDown: true)
```
Automatically displays and updates timer in `MM:SS` format. Shows `--:--` when `timerState` is `nil`.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
