import SwiftUI
import AWSAuthUI

struct AuthenticationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    @State private var accessKeyId = ""
    @State private var secretKey = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showHowTo = false
    @State private var showSecretKey = false
    
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
            ZStack {
                ScrollView {
                    VStack(spacing: 32) {
                        // App Icon and Title
                        VStack(spacing: 20) {
                            // Server Icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                appearanceViewModel.currentAccentColor.opacity(0.2),
                                                appearanceViewModel.currentAccentColor.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "server.rack")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                appearanceViewModel.currentAccentColor,
                                                appearanceViewModel.currentAccentColor.opacity(0.8)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            .shadow(color: appearanceViewModel.currentAccentColor.opacity(0.3), radius: 10, y: 5)
                            
                            VStack(spacing: 8) {
                                Text("Welcome to Instancify")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Manage your AWS EC2 instances with ease")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Region Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("REGION")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.semibold)
                            
                            Picker("Select Region", selection: $authManager.selectedRegion) {
                                ForEach(commonRegions, id: \.self) { region in
                                    Text(region.displayName)
                                        .tag(region)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            
                            Text("Select the AWS region where your instances are located")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        // Login Form
                        VStack(spacing: 24) {
                            // Access Key Field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Access Key ID", systemImage: "key.fill")
                                    .font(.headline)
                                    .foregroundStyle(appearanceViewModel.currentAccentColor)
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.secondary)
                                    TextField("Enter your AWS access key ID", text: $accessKeyId)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                    if !accessKeyId.isEmpty {
                                        Button {
                                            accessKeyId = ""
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(appearanceViewModel.currentAccentColor.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
                            }
                            
                            // Secret Key Field
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Secret Access Key", systemImage: "lock.fill")
                                    .font(.headline)
                                    .foregroundStyle(appearanceViewModel.currentAccentColor)
                                
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundStyle(.secondary)
                                    Group {
                                        if showSecretKey {
                                            TextField("Enter your AWS secret access key", text: $secretKey)
                                        } else {
                                            SecureField("Enter your AWS secret access key", text: $secretKey)
                                        }
                                    }
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    
                                    Button {
                                        showSecretKey.toggle()
                                    } label: {
                                        Image(systemName: showSecretKey ? "eye.slash.fill" : "eye.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(appearanceViewModel.currentAccentColor.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
                            }
                            
                            // Sign In Button
                            Button {
                                signIn()
                            } label: {
                                HStack(spacing: 12) {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            appearanceViewModel.currentAccentColor,
                                            appearanceViewModel.currentAccentColor.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: appearanceViewModel.currentAccentColor.opacity(0.3), radius: 5, y: 2)
                            }
                            .disabled(isLoading || accessKeyId.isEmpty || secretKey.isEmpty)
                            .opacity(isLoading || accessKeyId.isEmpty || secretKey.isEmpty ? 0.6 : 1)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                        
                        // Help Section
                        VStack(spacing: 20) {
                            NavigationLink {
                                AWSCredentialsGuideView()
                            } label: {
                                Label("How to get AWS credentials", systemImage: "questionmark.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(appearanceViewModel.currentAccentColor)
                            }
                        }
                    }
                    .padding()
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemGroupedBackground).opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                
                // Loading Tips Overlay
                if isLoading {
                    Color(.systemBackground)
                        .opacity(0.9)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        Text("Connecting to AWS")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        LoadingTipsView()
                            .padding(.horizontal)
                    }
                    .transition(.opacity)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func signIn() {
        Task {
            do {
                // First show loading state
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoading = true
                }
                
                // Show initial tips for 5 seconds before attempting authentication
                try await Task.sleep(nanoseconds: 5_000_000_000)
                
                // Attempt authentication
                try await authManager.signIn(
                    accessKeyId: accessKeyId,
                    secretAccessKey: secretKey
                )
                
                // Show more tips after successful authentication
                try await Task.sleep(nanoseconds: 10_000_000_000)
                
                // Complete the sign in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoading = false
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                withAnimation {
                    isLoading = false
                }
            }
        }
    }
} 