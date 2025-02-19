import SwiftUI

struct RuntimeAlertsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    @State private var isEnabled = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var hasRunningInstances = true
    let region: String
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Toggle("Enable Runtime Alerts", isOn: $isEnabled)
                            .disabled(isLoading || !hasRunningInstances)
                        if isLoading {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .onChange(of: isEnabled) { newValue in
                        Task {
                            isLoading = true
                            do {
                                // Set explicit disable flag if user is disabling alerts
                                if !newValue {
                                    UserDefaults.standard.set(true, forKey: "explicit_disable_\(region)")
                                } else {
                                    // Clear explicit disable flag when enabling
                                    UserDefaults.standard.removeObject(forKey: "explicit_disable_\(region)")
                                }
                                
                                try await notificationSettings.setRuntimeAlerts(
                                    enabled: newValue,
                                    region: region
                                )
                                
                                // Ensure the UI reflects the current state
                                await MainActor.run {
                                    self.isEnabled = notificationSettings.isRuntimeAlertsEnabled(for: region)
                                }
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                                // Revert the toggle
                                isEnabled = !newValue
                            }
                            isLoading = false
                        }
                    }
                } footer: {
                    Text("Get notified when instances exceed specified runtime durations")
                }
                
                if !hasRunningInstances || !isEnabled {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("Runtime Alerts are Disabled")
                                .font(.headline)
                            Text(getDisabledMessage())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
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
            .onAppear {
                // Load initial state
                isEnabled = notificationSettings.isRuntimeAlertsEnabled(for: region)
                
                // Check for running instances
                Task {
                    do {
                        let ec2Service = EC2Service.shared
                        let instances = try await ec2Service.fetchInstances()
                        let runningInstances = instances.filter { 
                            $0.region == region && $0.state == .running 
                        }
                        
                        await MainActor.run {
                            hasRunningInstances = !runningInstances.isEmpty
                            // Only disable if explicitly disabled by user
                            if !hasRunningInstances && !UserDefaults.standard.bool(forKey: "explicit_disable_\(region)") {
                                // Keep the current enabled state
                                isEnabled = notificationSettings.isRuntimeAlertsEnabled(for: region)
                            }
                        }
                    } catch {
                        print("Error checking instances: \(error)")
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RuntimeAlertsDisabled"))) { notification in
                if let disabledRegion = notification.object as? String,
                   disabledRegion == region {
                    isEnabled = false
                }
            }
        }
    }
    
    private func getDisabledMessage() -> String {
        if !hasRunningInstances {
            if UserDefaults.standard.bool(forKey: "explicit_disable_\(region)") {
                return "Runtime alerts have been manually disabled for this region. Enable them to get notified when your instances have been running for extended periods."
            } else {
                return "There are currently no running instances in this region. Runtime alerts will be active when you start instances."
            }
        } else if UserDefaults.standard.bool(forKey: "explicit_disable_\(region)") {
            return "Runtime alerts have been manually disabled for this region. Enable them to get notified when your instances have been running for extended periods."
        } else {
            return "Runtime alerts are disabled for this region. Enable them to get notified when your instances have been running for extended periods."
        }
    }
}

#Preview {
    NavigationView {
        RuntimeAlertsView(region: "Region1")
            .environmentObject(NotificationSettingsViewModel.shared)
    }
} 