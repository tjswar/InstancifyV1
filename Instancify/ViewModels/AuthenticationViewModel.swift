import SwiftUI
import AWSCore

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var accessKeyId = ""
    @Published var secretAccessKey = ""
    @Published var selectedRegion: AWSRegion = .usEast1
    @Published var isAuthenticating = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let authManager = AuthenticationManager.shared
    
    func signIn() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        do {
            try await authManager.signIn(
                accessKeyId: accessKeyId,
                secretAccessKey: secretAccessKey,
                region: selectedRegion
            )
        } catch AuthenticationError.invalidCredentials {
            errorMessage = "Invalid AWS credentials. Please check your Access Key ID and Secret Access Key."
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
} 