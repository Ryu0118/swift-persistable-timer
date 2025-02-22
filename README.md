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

### Initialization

Instantiate `PersistableTimer` with your preferred data source and configuration:

```swift
import PersistableTimer

// For testing or previews:
let timer = PersistableTimer(dataSourceType: .inMemory)

// For production (using UserDefaults):
let timer = PersistableTimer(dataSourceType: .userDefaults(.standard))

// With a custom update interval:
let timer = PersistableTimer(dataSourceType: .userDefaults(.standard), updateInterval: 0.5)
```

### Starting a Timer

Start a stopwatch or a countdown timer. You can also force-start a new timer even if one is already running:

```swift
// Start a stopwatch
try await timer.start(type: .stopwatch)

// Start a countdown timer with a duration of 100 seconds
try await timer.start(type: .timer(duration: 100))

// Force start a new timer even if one is already active:
try await timer.start(type: .timer(duration: 100), forceStart: true)
```

### Pausing, Resuming, and Finishing

Control the timer state as needed:

```swift
// Pause the timer
try await timer.pause()

// Resume a paused timer
try await timer.resume()

// Finish the timer (optionally reset the elapsed time)
try await timer.finish(isResetTime: false)
```

### Dynamic Time Adjustments

Adjust the timer on the fly:

```swift
// For countdown timers: add extra time to the remaining duration.
try await timer.addRemainingTime(5) // Adds 5 seconds

// For stopwatches: add extra elapsed time (i.e., effectively moving the start date earlier).
try await timer.addElapsedTime(5) // Adds 5 seconds to the elapsed time
```

### Restoring Timer State

Restore the timer's previous state after an app restart:

```swift
try timer.restore()
```

### Receiving Timer Updates

Subscribe to the asynchronous time stream to update your UI in real time:

```swift
for await timeState in timer.timeStream {
    // Update your UI with the current timer state.
    print("Elapsed time: \(timeState.elapsedTime)")
}
```

### SwiftUI Integration with PersistableTimerText

Display the timer state easily in your SwiftUI views using the provided Text initializer:

```swift
import SwiftUI
import PersistableTimerText

struct TimerView: View {
    @State private var timerState: TimerState?

    var body: some View {
        Text(timerState: timerState)
            .font(.title)
            .onAppear {
                // Update `timerState` with your PersistableTimer's current state.
            }
    }
}
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
