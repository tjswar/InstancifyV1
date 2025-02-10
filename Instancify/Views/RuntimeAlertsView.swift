import SwiftUI

struct RuntimeAlertsView: View {
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddAlert = false
    let currentRegion: String
    
    var regionSpecificAlerts: [RegionRuntimeAlert] {
        notificationSettings.runtimeAlerts.filter { !$0.regions.isEmpty && $0.regions.contains(currentRegion) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            VStack(spacing: 16) {
                // Enable Runtime Alerts Section
                VStack(spacing: 8) {
                    HStack {
                        Text("Enable Runtime Alerts")
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: $notificationSettings.runtimeAlertsEnabled)
                            .labelsHidden()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    
                    Text("Get notified when instances exceed specified runtime durations")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Region-specific Alerts Section
                if notificationSettings.runtimeAlertsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Region-Specific Alerts")
                                .font(.body)
                            Spacer()
                            Button(action: { showAddAlert = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Alert")
                                }
                                .foregroundColor(.pink)
                            }
                        }
                        
                        if regionSpecificAlerts.isEmpty {
                            HStack {
                                Spacer()
                                Text("No alerts configured")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        } else {
                            ForEach(regionSpecificAlerts) { alert in
                                AlertRow(alert: alert, notificationSettings: notificationSettings)
                                if alert.id != regionSpecificAlerts.last?.id {
                                    Divider()
                                }
                            }
                        }
                        
                        Text("Region-specific alerts only apply to instances in \(AWSRegion(rawValue: currentRegion)?.displayName ?? currentRegion)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                            .padding(.top)
                        
                        Text("Runtime Alerts are Disabled")
                            .font(.headline)
                        
                        Text("Enable runtime alerts to get notified when your instances have been running for extended periods, helping you manage costs and resource usage effectively.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Runtime Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.pink)
            }
        }
        .sheet(isPresented: $showAddAlert) {
            NavigationView {
                AddAlertView(currentRegion: currentRegion)
                    .environmentObject(notificationSettings)
            }
        }
    }
}

struct AlertRow: View {
    let alert: RegionRuntimeAlert
    let notificationSettings: NotificationSettingsViewModel
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundColor(.pink)
            Text(formatDuration(hours: alert.hours, minutes: alert.minutes))
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { alert.enabled },
                set: { newValue in
                    notificationSettings.updateAlert(id: alert.id, enabled: newValue)
                }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    if let index = notificationSettings.runtimeAlerts.firstIndex(where: { $0.id == alert.id }) {
                        notificationSettings.deleteAlert(at: IndexSet(integer: index))
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
            .tint(.red)
        }
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Alert", systemImage: "trash.fill")
            }
        }
        .alert("Delete Alert", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let index = notificationSettings.runtimeAlerts.firstIndex(where: { $0.id == alert.id }) {
                    withAnimation {
                        notificationSettings.deleteAlert(at: IndexSet(integer: index))
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this alert?")
        }
    }
    
    private func formatDuration(hours: Int, minutes: Int) -> String {
        var components: [String] = []
        if hours > 0 {
            components.append("\(hours)h")
        }
        if minutes > 0 {
            components.append("\(minutes)m")
        }
        return components.joined(separator: " ")
    }
}

struct AddAlertView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    let currentRegion: String
    @State private var hours = 0
    @State private var minutes = 0
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.pink)
                    Text(AWSRegion(rawValue: currentRegion)?.displayName ?? currentRegion)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Stepper("Hours: \(hours)", value: $hours, in: 0...24)
                Stepper("Minutes: \(minutes)", value: $minutes, in: 0...59, step: 5)
                
                if hours > 0 || minutes > 0 {
                    HStack {
                        Image(systemName: "bell.circle.fill")
                            .foregroundColor(.pink)
                        Text("Alert after \(formatDuration(hours: hours, minutes: minutes))")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Alert Duration")
            }
        }
        .navigationTitle("Add Alert")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.pink)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    notificationSettings.addNewAlert(
                        hours: hours,
                        minutes: minutes,
                        regions: Set([currentRegion])
                    )
                    dismiss()
                }
                .disabled(hours == 0 && minutes == 0)
                .foregroundColor(.pink)
            }
        }
    }
    
    private func formatDuration(hours: Int, minutes: Int) -> String {
        var components: [String] = []
        if hours > 0 {
            components.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 {
            components.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        return components.joined(separator: " ")
    }
}

#Preview {
    NavigationView {
        RuntimeAlertsView(currentRegion: "us-east-1")
            .environmentObject(NotificationSettingsViewModel.shared)
    }
} 