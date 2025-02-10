import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("Instancify")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Version 1.0 (1)")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
            }
            
            Section {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Privacy Policy")
                            Text("How we handle your data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                NavigationLink {
                    DataUsageView()
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Data Usage")
                            Text("Information about app data usage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("ACKNOWLEDGMENTS")) {
                Text("This app uses the AWS SDK for iOS and other open source software.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            }
            
            Section {
                Text("Last updated: January 25, 2024")
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Data Collection")) {
                Text("Instancify does not collect any personal data. All AWS credentials are stored securely in your device's keychain and are never transmitted to our servers.")
            }
            
            Section(header: Text("AWS Usage")) {
                Text("The app only uses your AWS credentials to interact with AWS services on your behalf. All communication is directly between your device and AWS servers.")
            }
            
            Section(header: Text("Local Storage")) {
                Text("App settings and preferences are stored locally on your device and are never shared with third parties.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

struct DataUsageView: View {
    var body: some View {
        List {
            Section {
                Text("Data Usage")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            }
            
            Section(header: Text("Network Usage")) {
                Text("API calls to AWS services")
                Text("Instance state monitoring")
                Text("Cost and usage data retrieval")
            }
            
            Section(header: Text("Local Storage")) {
                Text("AWS credentials (in Keychain)")
                Text("App settings and preferences")
                Text("Instance monitoring configurations")
            }
            
            Section(header: Text("Background Activity")) {
                Text("Instance state monitoring")
                Text("Auto-stop timer tracking")
                Text("Local notifications")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data Usage")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
} 