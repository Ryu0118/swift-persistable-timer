import SwiftUI

public struct TimePicker: View {
    public let hours: Int
    public let minutes: Int
    public let seconds: Int

    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    @Binding var selectedSeconds: Int

    public init(
        hours: Int = 24,
        minutes: Int = 59,
        seconds: Int = 59,
        selectedHours: Binding<Int>,
        selectedMinutes: Binding<Int>,
        selectedSeconds: Binding<Int>
    ) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        _selectedHours = selectedHours
        _selectedMinutes = selectedMinutes
        _selectedSeconds = selectedSeconds
    }

    public var body: some View {
        HStack {
            Picker("", selection: $selectedHours) {
                ForEach(0 ... hours, id: \.self) { hour in
                    Text("\(hour)hours")
                        .tag(hour)
                }
            }
            Picker("", selection: $selectedMinutes) {
                ForEach(0 ... minutes, id: \.self) { minute in
                    Text("\(minute)min")
                        .tag(minute)
                }
            }
            Picker("", selection: $selectedSeconds) {
                ForEach(0 ... seconds, id: \.self) { minute in
                    Text("\(minute)sec")
                        .tag(minute)
                }
            }
        }
        .pickerStyle(.wheel)
    }
}
