import Foundation
import AWSCore

@MainActor
class LoginViewModel: ObservableObject {
    @Published var accessKeyId = ""
    @Published var secretAccessKey = ""
    @Published var selectedRegion: AWSRegion
    @Published var isLoading = false
    @Published var error: AppError? {
        didSet {
            showError = error != nil
        }
    }
    @Published var showError = false
    
    private let authManager = AuthenticationManager.shared
    
    init() {
        // Always start with US East as default region
        self.selectedRegion = .usEast1
        // Clear any previously saved region
        UserDefaults.standard.removeObject(forKey: SharedConfig.currentRegionKey)
        UserDefaults(suiteName: SharedConfig.userDefaultsSuite)?.removeObject(forKey: SharedConfig.currentRegionKey)
    }
    
    var isValid: Bool {
        !accessKeyId.isEmpty && !secretAccessKey.isEmpty
    }
    
    func signIn() async {
        isLoading = true
        self.error = nil
        
        do {
            print("🔑 LoginVM: Starting sign in...")
            print("🔑 LoginVM: Using region: \(selectedRegion.rawValue)")
            
            try await authManager.signIn(
                accessKeyId: accessKeyId,
                secretAccessKey: secretAccessKey,
                region: selectedRegion
            )
            
            print("🔑 LoginVM: ✅ Sign in successful")
        } catch AuthenticationError.invalidCredentials {
            self.error = .invalidCredentials
        } catch let error as NSError {
            print("🔑 LoginVM: ❌ Sign in failed: \(error.localizedDescription)")
            if error.domain == AWSServiceErrorDomain {
                self.error = .authenticationFailed(error.localizedDescription)
            } else {
                self.error = .unknown(error)
            }
        }
        
        isLoading = false
    }
} 