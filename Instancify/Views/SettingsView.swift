import SwiftUI

struct SettingsView: View {
    @StateObject private var appLockService = AppLockService.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var appearanceViewModel = AppearanceSettingsViewModel.shared
    @StateObject private var notificationSettings = NotificationSettingsViewModel.shared
    @StateObject private var hapticManager = HapticManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                appLockSection
                appearanceSection
                hapticsSection
                awsSection
                notificationsSection
                pricingSection
                aboutSection
                signOutSection
            }
            .navigationTitle("Settings")
        }
    }
    
    private var appLockSection: some View {
        Section {
            NavigationLink {
                AppLockSettingsView()
                    .environmentObject(appLockService)
            } label: {
                Label("App Lock", systemImage: "lock")
            }
        } header: {
            Text("Security")
        }
    }
    
    private var appearanceSection: some View {
        Section {
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Appearance")
                        Text("Customize app colors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(appearanceViewModel.currentAccentColor)
                }
            }
        } header: {
            Text("Customization")
        }
    }
    
    private var hapticsSection: some View {
        Section {
            Toggle(isOn: $hapticManager.isEnabled) {
                Label {
                    VStack(alignment: .leading) {
                        Text("Haptic Feedback")
                        Text("Vibration on interaction")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "waveform")
                        .foregroundColor(.purple)
                }
            }
            .onChange(of: hapticManager.isEnabled) { _ in
                hapticManager.impact(.light)
            }
        } header: {
            Text("Feedback")
        }
    }
    
    private var awsSection: some View {
        Section {
            NavigationLink {
                if let credentials = try? authManager.getAWSCredentials() {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Access Key ID")
                            .font(.headline)
                        Text(credentials.accessKeyId)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Secret Access Key")
                            .font(.headline)
                        Text("••••••••")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .navigationTitle("AWS Credentials")
                }
            } label: {
                Label("AWS Credentials", systemImage: "key")
            }
            
            NavigationLink {
                Text("Current Region: \(authManager.selectedRegion.displayName)")
                    .navigationTitle("AWS Region")
            } label: {
                Label("AWS Region", systemImage: "globe")
            }
        } header: {
            Text("AWS Configuration")
        }
    }
    
    private var notificationsSection: some View {
        Section {
            NavigationLink {
                NotificationSettingsView()
                    .environmentObject(notificationSettings)
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Notifications")
                        Text("Runtime alerts & warnings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "bell.fill")
                        .foregroundColor(appearanceViewModel.currentAccentColor)
                }
            }
        } header: {
            Text("Notifications")
        }
    }
    
    private var pricingSection: some View {
        Section {
            NavigationLink {
                EC2PricingView()
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("EC2 Pricing")
                        Text("View instance pricing by region")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.green)
                }
            }
        } header: {
            Text("Pricing")
        }
    }
    
    private var aboutSection: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                Label("About", systemImage: "info.circle")
            }
        } header: {
            Text("About")
        }
    }
    
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                authManager.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppearanceSettingsViewModel.shared)
} 