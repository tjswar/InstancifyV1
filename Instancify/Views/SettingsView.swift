import SwiftUI

struct SettingsView: View {
    @StateObject private var appLockService = AppLockService.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var appearanceViewModel = AppearanceSettingsViewModel.shared
    @StateObject private var notificationSettings = NotificationSettingsViewModel.shared
    @StateObject private var hapticManager = HapticManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: String?
    
    var body: some View {
        List(selection: $selectedSection) {
            appLockSection
            appearanceSection
            hapticsSection
            awsSection
            notificationsSection
            pricingSection
            aboutSection
            signOutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedSection)
        .tint(appearanceViewModel.currentAccentColor)
    }
    
    private var appLockSection: some View {
        Section {
            NavigationLink {
                AppLockSettingsView()
                    .environmentObject(appLockService)
            } label: {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Lock")
                            .font(.body)
                        Text(appLockService.isPasswordSet() ? "PIN protection enabled" : "Set up PIN protection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .modifier(SettingsRowStyle())
        } header: {
            SettingsSectionHeader(text: "Security")
        }
    }
    
    private var appearanceSection: some View {
        Section {
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(appearanceViewModel.currentAccentColor)
                        .font(.system(size: 20))
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Appearance")
                            .font(.body)
                        Text("Customize app colors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .modifier(SettingsRowStyle())
        } header: {
            SettingsSectionHeader(text: "Customization")
        }
    }
    
    private var hapticsSection: some View {
        Section {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.purple)
                    .font(.system(size: 20))
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Haptic Feedback")
                        .font(.body)
                    Text("Vibration on interaction")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $hapticManager.isEnabled)
                    .labelsHidden()
                    .tint(appearanceViewModel.currentAccentColor)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                hapticManager.isEnabled.toggle()
                if hapticManager.isEnabled {
                    hapticManager.impact(.light)
                }
            }
            .modifier(SettingsRowStyle())
        } header: {
            SettingsSectionHeader(text: "Feedback")
        }
    }
    
    private var awsSection: some View {
        Section {
            NavigationLink {
                if let credentials = try? authManager.getAWSCredentials() {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            credentialCard(title: "Access Key ID", value: credentials.accessKeyId)
                            credentialCard(title: "Secret Access Key", value: "••••••••")
                        }
                        .padding()
                    }
                    .navigationTitle("AWS Credentials")
                    .background(Color(.systemGroupedBackground))
                }
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 20))
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AWS Credentials")
                            .font(.body)
                        Text("View access credentials")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .modifier(SettingsRowStyle())
            
            NavigationLink {
                Text("Current Region: \(authManager.selectedRegion.displayName)")
                    .navigationTitle("AWS Region")
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AWS Region")
                            .font(.body)
                        Text(authManager.selectedRegion.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .modifier(SettingsRowStyle())
        } header: {
            SettingsSectionHeader(text: "AWS Configuration")
        }
    }
    
    private var notificationsSection: some View {
        Section {
            NavigationLink {
                NotificationSettingsView()
                    .environmentObject(notificationSettings)
            } label: {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(appearanceViewModel.currentAccentColor)
                        .font(.system(size: 20))
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications")
                            .font(.body)
                        Text("Runtime alerts & warnings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .modifier(SettingsRowStyle())
        } header: {
            SettingsSectionHeader(text: "Notifications")
        }
    }
    
    private var pricingSection: some View {
        Section {
            NavigationLink {
                EC2PricingView()
            } label: {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EC2 Pricing")
                            .font(.body)
                        Text("View instance pricing by region")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .modifier(SettingsRowStyle())
        } header: {
            SettingsSectionHeader(text: "Pricing")
        }
    }
    
    private var aboutSection: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("About")
                            .font(.body)
                        Text("App information & help")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .modifier(SettingsRowStyle())
        } header: {
            SettingsSectionHeader(text: "About")
        }
    }
    
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                withAnimation {
                    authManager.signOut()
                }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sign Out")
                            .font(.body)
                        Text("Log out of your AWS account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            .modifier(SettingsRowStyle())
        }
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : .white)
    }
    
    private func credentialCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
        )
    }
}

// Helper view for consistent row styling
private struct SettingsRowStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : .white)
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

// Helper view for section headers
private struct SettingsSectionHeader: View {
    let text: String
    
    var body: some View {
        Text(text)
            .textCase(.uppercase)
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.leading, 16)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppearanceSettingsViewModel.shared)
} 