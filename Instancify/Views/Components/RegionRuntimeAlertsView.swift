import SwiftUI

struct RegionRuntimeAlertsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @EnvironmentObject private var notificationSettings: NotificationSettingsViewModel
    @State private var showAddAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Region Runtime Alerts")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    showAddAlert = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            if notificationSettings.runtimeAlertsEnabled {
                let alerts = notificationSettings.runtimeAlerts.filter { 
                    $0.enabled && ($0.regions.isEmpty || $0.regions.contains(viewModel.currentRegion))
                }
                
                if alerts.isEmpty {
                    Text("No runtime alerts set for this region")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(alerts) { alert in
                        RuntimeAlertRow(alert: alert)
                    }
                }
            } else {
                Text("Runtime alerts are disabled")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showAddAlert) {
            NavigationView {
                NotificationSettingsView()
                    .navigationTitle("Add Runtime Alert")
            }
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