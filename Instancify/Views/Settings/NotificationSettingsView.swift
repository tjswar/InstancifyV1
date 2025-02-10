import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    @State private var showDebugInfo = false
    @State private var showingAddAlert = false
    @State private var newAlertHours = 0
    @State private var newAlertMinutes = 0
    
    var globalAlerts: [RegionRuntimeAlert] {
        notificationSettings.runtimeAlerts.filter { $0.regions.isEmpty }
    }
    
    var body: some View {
        Form {
            Section {
                PrimitiveToggle(
                    isOn: $notificationSettings.runtimeAlertsEnabled,
                    label: "Runtime Alerts"
                )
                .onChange(of: notificationSettings.runtimeAlertsEnabled) { newValue in
                    if !newValue {
                        // Disable all alerts when runtime alerts are disabled
                        for alert in notificationSettings.runtimeAlerts {
                            notificationSettings.updateAlert(id: alert.id, enabled: false)
                        }
                    }
                }
            } header: {
                Text("Runtime Alerts")
            } footer: {
                Text("Get notified when instances have been running for specific durations")
            }
            
            if notificationSettings.runtimeAlertsEnabled {
                Section {
                    if globalAlerts.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("No Global Alerts")
                                    .font(.headline)
                                Text("Add alerts that apply to all regions")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .padding()
                    } else {
                        ForEach(globalAlerts) { alert in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    PrimitiveToggle(
                                        isOn: .init(
                                            get: { alert.enabled },
                                            set: { newValue in
                                                notificationSettings.updateAlert(id: alert.id, enabled: newValue)
                                            }
                                        ),
                                        label: formatAlertDuration(hours: alert.hours, minutes: alert.minutes)
                                    )
                                    
                                    Spacer()
                                    
                                    Button(role: .destructive) {
                                        if let index = notificationSettings.runtimeAlerts.firstIndex(where: { $0.id == alert.id }) {
                                            notificationSettings.deleteAlert(at: IndexSet(integer: index))
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                    }
                    
                    Button {
                        newAlertHours = 0
                        newAlertMinutes = 0
                        showingAddAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Global Alert")
                        }
                    }
                } header: {
                    Text("Global Alert Thresholds")
                } footer: {
                    Text("These alerts apply to all regions. Region-specific alerts can be set from the dashboard.")
                }
            }
            
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
                    Text("Runtime Alerts: \(notificationSettings.runtimeAlertsEnabled ? "Enabled" : "Disabled")")
                    Text("Auto-Stop Warnings: \(notificationSettings.autoStopWarningsEnabled ? "Enabled" : "Disabled")")
                    Text("Countdown Updates: \(notificationSettings.autoStopCountdownEnabled ? "Enabled" : "Disabled")")
                    Text("Selected Warning Intervals: \(notificationSettings.selectedWarningIntervals.sorted().map { "\($0/60)m" }.joined(separator: ", "))")
                    Text("Runtime Alerts: \(notificationSettings.runtimeAlerts.map { "\($0.hours)h \($0.minutes)m (\($0.enabled ? "enabled" : "disabled"))" }.joined(separator: ", "))")
                } header: {
                    Text("Debug Information")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddAlert) {
            NavigationView {
                Form {
                    Section {
                        Stepper("Hours: \(newAlertHours)", value: $newAlertHours, in: 0...24)
                        Stepper("Minutes: \(newAlertMinutes)", value: $newAlertMinutes, in: 0...59, step: 5)
                        
                        if newAlertHours > 0 || newAlertMinutes > 0 {
                            Text("Alert after \(formatAlertDuration(hours: newAlertHours, minutes: newAlertMinutes))")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Alert Threshold")
                    } footer: {
                        Text("This alert will apply to all regions")
                    }
                }
                .navigationTitle("Add Global Alert")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddAlert = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            notificationSettings.addNewAlert(
                                hours: newAlertHours,
                                minutes: newAlertMinutes,
                                regions: Set()  // Empty set means global alert
                            )
                            showingAddAlert = false
                        }
                        .disabled(newAlertHours == 0 && newAlertMinutes == 0)
                    }
                }
            }
        }
    }
    
    private func formatAlertDuration(hours: Int, minutes: Int) -> String {
        if hours == 0 {
            return "\(minutes) minutes"
        } else if minutes == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) min"
        }
    }
} 