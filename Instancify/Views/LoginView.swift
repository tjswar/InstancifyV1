import SwiftUI
import AWSCore

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    @State private var showingAWSGuide = false
    @State private var showingFreeTierInfo = false
    
    private let commonRegions: [AWSRegion] = [
        .usEast1,      // N. Virginia
        .usEast2,      // Ohio
        .usWest1,      // N. California
        .usWest2,      // Oregon
        .euWest1,      // Ireland
        .euWest2,      // London
        .euCentral1,   // Frankfurt
        .apSoutheast1, // Singapore
        .apSoutheast2  // Sydney
    ]
    
    var body: some View {
        NavigationView {
            Form {
                regionSection
                credentialsSection
                helpSection
                connectButton
            }
            .navigationTitle("AWS Login")
            .alert("Connection Failed", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.error?.description ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showingAWSGuide) {
                AWSGuideView(isPresented: $showingAWSGuide)
            }
            .sheet(isPresented: $showingFreeTierInfo) {
                FreeTierInfoView(isPresented: $showingFreeTierInfo)
            }
            .tint(appearanceViewModel.currentAccentColor)
        }
    }
    
    private var regionSection: some View {
        Section {
            Picker("Select Region", selection: $viewModel.selectedRegion) {
                ForEach(commonRegions, id: \.self) { region in
                    Text(region.displayName)
                        .tag(region)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        } header: {
            Text("REGION")
                .foregroundColor(.secondary)
        } footer: {
            Text("Select the AWS region where your instances are located")
                .foregroundColor(.secondary)
        }
    }
    
    private var credentialsSection: some View {
        Section("CREDENTIALS") {
            TextField("Access Key ID", text: $viewModel.accessKeyId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
            
            SecureField("Secret Access Key", text: $viewModel.secretAccessKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
        }
    }
    
    private var helpSection: some View {
        Section("HELP") {
            Button {
                showingAWSGuide = true
            } label: {
                HelpRowView(
                    icon: "key.fill",
                    text: "How to get AWS Access Keys"
                )
            }
            
            Button {
                showingFreeTierInfo = true
            } label: {
                HelpRowView(
                    icon: "dollarsign.circle.fill",
                    text: "AWS Free Tier Info"
                )
            }
        }
    }
    
    private var connectButton: some View {
        Section {
            Button {
                Task {
                    await viewModel.signIn()
                }
            } label: {
                if viewModel.isLoading {
                    HStack {
                        Text("Connecting...")
                            .frame(maxWidth: .infinity)
                        ProgressView()
                    }
                } else {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                }
            }
            .listRowBackground(appearanceViewModel.currentAccentColor)
            .foregroundColor(.white)
            .disabled(!viewModel.isValid || viewModel.isLoading)
        }
    }
}

// Helper Views
struct HelpRowView: View {
    let icon: String
    let text: String
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(appearanceViewModel.currentAccentColor)
            Text(text)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
    }
}

struct AWSGuideView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("1. Log in to AWS Management Console")
                    Text("2. Click your username at the top right")
                    Text("3. Select 'Security credentials'")
                    Text("4. Under 'Access keys', create a new key")
                    Text("5. Copy and paste your keys here")
                }
                
                Section {
                    Link(destination: URL(string: "https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html")!) {
                        HStack {
                            Text("AWS Official Documentation")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }
            .navigationTitle("Get AWS Access Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

struct FreeTierInfoView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("AWS Free Tier includes:")
                        .font(.headline)
                    Text("• 750 hours of EC2 t2.micro instance per month")
                    Text("• 30GB of EBS storage")
                    Text("• 15GB of bandwidth out")
                    Text("Valid for 12 months for new AWS accounts")
                }
                
                Section {
                    Link(destination: URL(string: "https://aws.amazon.com/free/")!) {
                        HStack {
                            Text("Learn More About Free Tier")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }
            .navigationTitle("AWS Free Tier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppearanceSettingsViewModel())
} 