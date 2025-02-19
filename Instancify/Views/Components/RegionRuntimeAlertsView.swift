import SwiftUI
import FirebaseFirestore
import FirebaseMessaging

extension RegionRuntimeAlert: Equatable {
    static func == (lhs: RegionRuntimeAlert, rhs: RegionRuntimeAlert) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Region: Identifiable {
    let id: String
    let name: String
}

struct RegionRuntimeAlertsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    @State private var showAddAlert = false
    @State private var showRuntimeAlertsToggle = false
    @State private var showActiveAlerts = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isExpanded = false
    @State private var hasRunningInstances = false
    
    var body: some View {
        mainContent
            .sheet(isPresented: $showAddAlert) {
                NavigationView {
                    AddRegionAlertView(region: viewModel.currentRegion)
                        .environmentObject(notificationSettings)
                }
            }
            .sheet(isPresented: $showRuntimeAlertsToggle) {
                RuntimeAlertsToggleView(region: viewModel.currentRegion)
                    .environmentObject(notificationSettings)
            }
            .onChange(of: viewModel.instances) { oldValue, newValue in
                handleInstancesChange(newValue)
            }
            .onChange(of: notificationSettings.runtimeAlerts) { oldValue, newValue in
                handleAlertsChange()
            }
            .onChange(of: viewModel.currentRegion) { oldValue, newValue in
                handleRegionChange()
            }
            .onAppear {
                // Check for running instances
                hasRunningInstances = viewModel.instances.contains { 
                    $0.region == viewModel.currentRegion && $0.state == .running 
                }
                // Restore alerts state when view appears
                handleRegionChange()
            }
    }
    
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            
            if isExpanded {
                expandedContent
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Region Alerts")
                        .font(.headline)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(viewModel.currentRegion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                statusLabel
            }
            
            Spacer()
            
            expandButton
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var statusLabel: some View {
        Group {
            if hasRunningInstances && notificationSettings.isRuntimeAlertsEnabled(for: viewModel.currentRegion) {
                Text("Active")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            } else if !hasRunningInstances {
                Text("Inactive")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            } else {
                Text("Disabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }
    
    private var expandButton: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
    }
    
    private var expandedContent: some View {
        VStack(spacing: 12) {
            quickActions
            alertsList
        }
    }
    
    private var quickActions: some View {
        HStack(spacing: 16) {
            toggleAlertsButton
            addAlertButton
        }
    }
    
    private var toggleAlertsButton: some View {
        Button {
            showRuntimeAlertsToggle = true
        } label: {
            HStack {
                Image(systemName: notificationSettings.isRuntimeAlertsEnabled(for: viewModel.currentRegion) ? "bell.fill" : "bell.slash")
                Text(notificationSettings.isRuntimeAlertsEnabled(for: viewModel.currentRegion) ? "Enabled" : "Disabled")
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(notificationSettings.isRuntimeAlertsEnabled(for: viewModel.currentRegion) ? Color.accentColor : Color.secondary)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(!viewModel.hasRunningInstances)
    }
    
    private var addAlertButton: some View {
        Button {
            showAddAlert = true
        } label: {
            HStack {
                Image(systemName: "plus")
                Text("Add Alert")
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(notificationSettings.isRuntimeAlertsEnabled(for: viewModel.currentRegion) && viewModel.hasRunningInstances ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2))
            .foregroundColor(notificationSettings.isRuntimeAlertsEnabled(for: viewModel.currentRegion) && viewModel.hasRunningInstances ? .accentColor : .secondary)
            .cornerRadius(8)
        }
        .disabled(!notificationSettings.isRuntimeAlertsEnabled(for: viewModel.currentRegion) || !viewModel.hasRunningInstances)
    }
    
    private var alertsList: some View {
        Group {
            if notificationSettings.isRuntimeAlertsEnabled(for: viewModel.currentRegion) {
                let alerts = notificationSettings.getAlertsForRegion(viewModel.currentRegion)
                if !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Alerts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ForEach(alerts) { alert in
                            HStack {
                                Image(systemName: "timer")
                                    .foregroundColor(.accentColor)
                                Text("\(alert.hours)h \(alert.minutes)m")
                                    .font(.system(.body, design: .monospaced))
                                
                                Spacer()
                                
                                Button {
                                    withAnimation {
                                        notificationSettings.deleteAlert(at: [notificationSettings.runtimeAlerts.firstIndex(where: { $0.id == alert.id })!])
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private func handleInstancesChange(_ newInstances: [EC2Instance]) {
        print("\n🔄 Instances state changed")
        
        // Update hasRunningInstances state
        hasRunningInstances = newInstances.contains { 
            $0.region == viewModel.currentRegion && $0.state == .running 
        }
        
        // Get instances in current region
        let regionInstances = newInstances.filter { $0.region == viewModel.currentRegion }
        let runningInstances = regionInstances.filter { $0.state == .running }
        
        if !runningInstances.isEmpty {
            print("🟢 Found \(runningInstances.count) running instances")
            
            // Get existing alerts for the region
            let alerts = notificationSettings.getAlertsForRegion(viewModel.currentRegion)
            
            // Schedule alerts for each running instance
            for instance in runningInstances {
                print("\n📝 Getting runtime alerts for region: \(viewModel.currentRegion)")
                
                if notificationSettings.isRuntimeAlertsEnabled(for: viewModel.currentRegion) && !alerts.isEmpty {
                    print("  📋 Found \(alerts.count) alerts to schedule")
                    handleInstanceStateChange(for: instance, in: AWSRegion(rawValue: viewModel.currentRegion) ?? .usEast2)
                } else {
                    print("  ❌ Runtime alerts are disabled for this region")
                }
            }
        }
    }
    
    private func handleAlertsChange() {
        // When alerts change, update all running instances in the current region
        let currentRegion = viewModel.currentRegion
        let runningInstances = viewModel.instances.filter { 
            $0.state == .running && $0.region == currentRegion
        }
        
        // If no running instances, disable alerts
        if runningInstances.isEmpty {
            print("⚠️ No running instances, disabling runtime alerts")
            Task {
                do {
                    try await notificationSettings.setRuntimeAlerts(enabled: false, region: currentRegion)
                } catch {
                    print("❌ Failed to disable runtime alerts: \(error.localizedDescription)")
                }
            }
            return
        }
        
        // Otherwise, schedule alerts for running instances
        for instance in runningInstances {
            handleInstanceStateChange(for: instance, in: AWSRegion(rawValue: currentRegion) ?? .usEast2)
        }
    }

    func handleInstanceStateChange(for instance: EC2Instance, in region: AWSRegion) {
        // Get existing alerts for the region using NotificationSettingsViewModel
        let existingAlerts = notificationSettings.getAlertsForRegion(region.rawValue)
        
        // If there are existing alerts, schedule them for the new instance
        if !existingAlerts.isEmpty {
            scheduleAlerts(existingAlerts, for: instance, in: region)
        }
    }

    func scheduleAlerts(_ alerts: [RegionRuntimeAlert], for instance: EC2Instance, in region: AWSRegion) {
        print("\n📝 Scheduling alerts for instance \(instance.id)")
        print("  • Instance Name: \(instance.name ?? instance.id)")
        print("  • Region: \(region.rawValue)")
        print("  • State: \(instance.state.rawValue)")
        
        // Only schedule alerts if instance is running
        guard instance.state == .running else {
            print("⚠️ Instance \(instance.id) is not running (state: \(instance.state.rawValue)), skipping alert scheduling")
            return
        }
        
        Task {
            do {
                // Get FCM token first
                let fcmToken = try await Messaging.messaging().token()
                
                // Create a batch for new alerts
                let batch = FirestoreManager.shared.db.batch()
                var scheduledCount = 0
                
                for alert in alerts {
                    // Calculate interval in seconds
                    let interval = TimeInterval(alert.hours * 3600 + alert.minutes * 60)
                    let scheduledTime = Date().addingTimeInterval(interval)
                    
                    // Create document ID in the format: region_instanceId_alertId
                    let documentId = "\(region.rawValue)_\(instance.id)_\(alert.id)"
                    let docRef = FirestoreManager.shared.db.collection("scheduledAlerts").document(documentId)
                    
                    // Add to Firestore with instance-specific information and alert status
                    let alertData: [String: Any] = [
                        "instanceID": instance.id,
                        "instanceName": instance.name ?? instance.id,
                        "region": region.rawValue,
                        "hours": alert.hours,
                        "minutes": alert.minutes,
                        "scheduledTime": scheduledTime,
                        "status": "pending",
                        "notificationSent": false,
                        "instanceState": instance.state.rawValue,
                        "deleted": false,
                        "launchTime": instance.launchTime ?? FieldValue.serverTimestamp(),
                        "type": "runtime_alert",
                        "fcmToken": fcmToken,
                        "threshold": alert.hours * 60 + alert.minutes
                    ]
                    
                    batch.setData(alertData, forDocument: docRef)
                    scheduledCount += 1
                    
                    print("⏰ Scheduled alert:")
                    print("  • Alert ID: \(alert.id)")
                    print("  • Time: \(alert.hours)h \(alert.minutes)m")
                    print("  • Scheduled for: \(scheduledTime)")
                }
                
                // Commit all alerts in one batch
                try await batch.commit()
                print("✅ Successfully scheduled \(scheduledCount) alerts for instance \(instance.id)")
                
            } catch {
                print("❌ Error scheduling alerts: \(error.localizedDescription)")
            }
        }
    }

    // Update the handleRegionChange function
    private func handleRegionChange() {
        print("\n🔄 Handling region change for \(viewModel.currentRegion)")
        
        Task {
            do {
                // First, check if alerts were enabled for this region
                let wasEnabled = UserDefaults.standard.bool(forKey: "runtimeAlerts_enabled_\(viewModel.currentRegion)")
                print("  • Alerts were \(wasEnabled ? "enabled" : "disabled") for this region")
                
                // Get all running instances in the current region
                let runningInstances = viewModel.instances.filter { 
                    $0.state == .running && $0.region == viewModel.currentRegion 
                }
                
                // If alerts were enabled and we have running instances, restore alerts
                if wasEnabled {
                    print("  • Found \(runningInstances.count) running instances")
                    
                    // First, try to restore alerts from Firestore
                    let alertsQuery = FirestoreManager.shared.db
                        .collection("scheduledAlerts")
                        .whereField("region", isEqualTo: viewModel.currentRegion)
                        .whereField("status", isEqualTo: "pending")
                        .whereField("appTerminated", isEqualTo: true)
                    
                    let snapshot = try await alertsQuery.getDocuments()
                    let existingAlerts = snapshot.documents.compactMap { doc -> RegionRuntimeAlert? in
                        let data = doc.data()
                        guard let hours = data["hours"] as? Int,
                              let minutes = data["minutes"] as? Int else {
                            return nil
                        }
                        return RegionRuntimeAlert(
                            id: doc.documentID,
                            enabled: true,
                            hours: hours,
                            minutes: minutes,
                            regions: [viewModel.currentRegion]
                        )
                    }
                    
                    if !existingAlerts.isEmpty {
                        print("  • Restored \(existingAlerts.count) alerts from Firestore")
                        // Re-enable alerts and restore the alerts
                        try await notificationSettings.setRuntimeAlerts(enabled: true, region: viewModel.currentRegion)
                        
                        // Schedule alerts for all running instances
                        for instance in runningInstances {
                            handleInstanceStateChange(for: instance, in: AWSRegion(rawValue: viewModel.currentRegion) ?? .usEast2)
                        }
                    } else {
                        print("  • No existing alerts found in Firestore")
                        // If no alerts found but region was enabled, try to restore from settings
                        let regionAlerts = notificationSettings.getAlertsForRegion(viewModel.currentRegion)
                        if !regionAlerts.isEmpty && !runningInstances.isEmpty {
                            print("  • Restoring \(regionAlerts.count) alerts from settings")
                            // Schedule alerts for all running instances
                            for instance in runningInstances {
                                scheduleAlerts(regionAlerts, for: instance, in: AWSRegion(rawValue: viewModel.currentRegion) ?? .usEast2)
                            }
                        }
                    }
                }
            } catch {
                print("❌ Failed to handle region change: \(error.localizedDescription)")
            }
        }
    }
}

struct RuntimeAlertsToggleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    @State private var isEnabled = false  // Set default value
    let region: String
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(region: String) {
        self.region = region
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("Enable Runtime Alerts", isOn: $isEnabled)
                        .onChange(of: isEnabled) { newValue in
                            Task {
                                do {
                                    try await notificationSettings.setRuntimeAlerts(
                                        enabled: newValue,
                                        region: region
                                    )
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                    isEnabled = !newValue // Revert on error
                                }
                            }
                        }
                } footer: {
                    Text("Get notified when instances exceed specified runtime durations")
                }
            }
            .navigationTitle("Runtime Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Set the initial value when the view appears and notificationSettings is available
                isEnabled = notificationSettings.isRuntimeAlertsEnabled(for: region)
            }
        }
    }
}

struct ActiveAlertsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    let region: String
    
    var body: some View {
        NavigationView {
            List {
                let alerts = notificationSettings.getAlertsForRegion(region)
                if alerts.isEmpty {
                    Text("No active alerts")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(alerts) { alert in
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.accentColor)
                            Text("\(alert.hours)h \(alert.minutes)m")
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                notificationSettings.deleteAlert(at: [notificationSettings.runtimeAlerts.firstIndex(where: { $0.id == alert.id })!])
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Active Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddRegionAlertView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    @State private var hours = 0
    @State private var minutes = 0
    let region: String
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    
    var body: some View {
        Form {
            Section {
                Stepper("Hours: \(hours)", value: $hours, in: 0...24)
                Stepper("Minutes: \(minutes)", value: $minutes, in: 0...59, step: 5)
                
                if hours > 0 || minutes > 0 {
                    Text("Alert after \(formatDuration(hours: hours, minutes: minutes))")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Alert Threshold")
            } footer: {
                Text("This alert will apply to \(region) region")
            }
        }
        .navigationTitle("Add Region Alert")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    Task {
                        do {
                            notificationSettings.addNewAlert(
                                hours: hours,
                                minutes: minutes,
                                regions: [region]
                            )
                            showSuccessAlert = true
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
                .disabled(hours == 0 && minutes == 0)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Runtime Alert Created", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("A runtime alert has been set for \(formatDuration(hours: hours, minutes: minutes)). You'll be notified when your instance exceeds this duration.")
        }
    }
    
    private func formatDuration(hours: Int, minutes: Int) -> String {
        if hours == 0 {
            return "\(minutes) minutes"
        } else if minutes == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) min"
        }
    }
}

struct RuntimeAlertRow: View {
    let alert: RegionRuntimeAlert
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDuration(hours: alert.hours, minutes: alert.minutes))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if alert.regions.isEmpty {
                    Text("Applies to all regions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Region specific")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "bell.fill")
                .foregroundColor(.accentColor)
                .font(.footnote)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(8)
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

#Preview {
    RegionRuntimeAlertsView(viewModel: DashboardViewModel())
        .environmentObject(NotificationSettingsViewModel.shared)
        .padding()
        .background(Color(.systemGroupedBackground))
} 