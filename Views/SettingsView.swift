import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: GeoVM

    var body: some View {
        Form {
            Section("Dwell & Debounce") {
                Stepper("Dwell: \(vm.settings.dwellSeconds)s", value: $vm.settings.dwellSeconds, in: 5...180, step: 5)
                Stepper("Exit Debounce: \(vm.settings.exitDebounceSeconds)s", value: $vm.settings.exitDebounceSeconds, in: 5...180, step: 5)
            }
            Section("Battery") {
                Picker("Mode", selection: $vm.settings.batteryMode) {
                    ForEach(BatteryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Limits") {
                Stepper("Monitor up to: \(vm.settings.maxMonitored)", value: $vm.settings.maxMonitored, in: 1...20)
                Text("System hard limit is 20.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Save Settings") { vm.save() }
            }
        }
        .navigationTitle("Settings")
    }
}
