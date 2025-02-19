import SwiftUI
import AWSAuthUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @State private var showSetupGuide = false
    @State private var showRegionPicker = false
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Logo and Title Section
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                        .frame(width: 120, height: 120)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(30)
                        .shadow(radius: 10)
                    
                    Text("INSTANCIFY")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(2)
                    
                    Text("Manage AWS EC2 Instances")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Credentials Section
                VStack(spacing: 24) {
                    // AWS Credentials Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("AWS CREDENTIALS")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .tracking(1)
                        
                        // Access Key Field
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Access Key ID", text: $viewModel.accessKeyId)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        
                        // Secret Key Field
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Secret Access Key", text: $viewModel.secretAccessKey)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Region Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("AWS REGION")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .tracking(1)
                        
                        AuthenticationRegionPickerView(viewModel: viewModel)
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    // Sign In Button
                    Button {
                        Task {
                            await viewModel.signIn()
                        }
                    } label: {
                        HStack {
                            Text("Sign In")
                                .fontWeight(.semibold)
                            if viewModel.isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.leading, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isAuthenticating)
                    
                    // Help Button
                    Button {
                        showSetupGuide = true
                    } label: {
                        Text("Need help setting up AWS credentials?")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showSetupGuide) {
            AWSSetupGuideView()
        }
        .alert("Authentication Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

#Preview {
    AuthenticationView()
} 