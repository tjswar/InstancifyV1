import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    @State private var showDebugInfo = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    PrimitiveToggle(
                        isOn: $notificationSettings.autoStopWarningsEnabled,
                        label: "Auto-Stop Warnings"
                    )
                    
                    if notificationSettings.autoStopWarningsEnabled {
                        ForEach(notificationSettings.availableWarningIntervals, id: \.0) { interval, label in
                            HStack {
                                Text(label)
                                Spacer()
                                PrimitiveToggle(
                                    isOn: .init(
                                        get: { notificationSettings.selectedWarningIntervals.contains(interval) },
                                        set: { _ in notificationSettings.toggleWarningInterval(interval) }
                                    ),
                                    label: ""
                                )
                            }
                        }
                    }
                    
                    PrimitiveToggle(
                        isOn: $notificationSettings.autoStopCountdownEnabled,
                        label: "Countdown Updates"
                    )
                } header: {
                    Text("Auto-Stop Notifications")
                } footer: {
                    Text("Get notified before instances are automatically stopped")
                }
                
                Button("Show Debug Info") {
                    showDebugInfo.toggle()
                }
                
                if showDebugInfo {
                    Section {
                        Text("Auto-Stop Warnings: \(notificationSettings.autoStopWarningsEnabled ? "Enabled" : "Disabled")")
                        Text("Countdown Updates: \(notificationSettings.autoStopCountdownEnabled ? "Enabled" : "Disabled")")
                        Text("Selected Warning Intervals: \(notificationSettings.selectedWarningIntervals.sorted().map { "\($0/60)m" }.joined(separator: ", "))")
                        Text("Runtime Alerts: \(notificationSettings.runtimeAlerts.map { "\($0.hours)h \($0.minutes)m (\($0.enabled ? "enabled" : "disabled"))" }.joined(separator: ", "))")
                    } header: {
                        Text("Debug Information")
                    }
                }
            }
            .navigationTitle("Notification Settings")
        }
    }
} 