import Foundation
import KeychainAccess
import AWSEC2
import AWSCore
import SwiftUI

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    private let keychain = Keychain(service: "com.instancify.credentials")
    
    @Published var selectedRegion: AWSRegion = .usEast1  // Default to US East (N. Virginia)
    @Published var isAuthenticated = false
    @Published private(set) var accessKeyId: String = ""
    @Published private(set) var secretAccessKey: String = ""
    
    private init() {
        print("🔐 AuthManager: Initializing...")
        restoreFromKeychain()
    }
    
    func getAWSCredentials() throws -> AWSCredentials {
        guard !accessKeyId.isEmpty && !secretAccessKey.isEmpty else {
            throw AuthenticationError.invalidCredentials
        }
        return AWSCredentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey
        )
    }
    
    func signIn(accessKeyId: String, secretAccessKey: String) async throws {
        print("🔐 AuthManager: Starting sign in process...")
        
        // Reset authentication state
        self.isAuthenticated = false
        
        // Create temporary credentials for validation
        let credentials = AWSCredentials(
            accessKeyId: accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines),
            secretAccessKey: secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        do {
            // Update EC2Service configuration first
            EC2Service.shared.updateConfiguration(
                with: credentials,
                region: selectedRegion.awsRegionType
            )
            
            // Validate credentials
            try await EC2Service.shared.validateCredentials()
            
            // If validation succeeds, save credentials
            try keychain.set(credentials.accessKeyId, key: "accessKeyId")
            try keychain.set(credentials.secretAccessKey, key: "secretAccessKey")
            try keychain.set(selectedRegion.rawValue, key: "region")
            
            // Update local state
            self.accessKeyId = credentials.accessKeyId
            self.secretAccessKey = credentials.secretAccessKey
            self.isAuthenticated = true
            
            print("🔐 AuthManager: ✅ Sign in successful")
            
        } catch {
            print("🔐 AuthManager: ❌ Sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func signOut() {
        // Clear EC2Service data before signing out
        EC2Service.shared.clearAllData()
        
        // Clear credentials
        self.accessKeyId = ""
        self.secretAccessKey = ""
        try? keychain.removeAll()
        
        // Reset state
        self.isAuthenticated = false
        
        print("🔐 AuthManager: Signed out")
    }
    
    func handleAppActivation() async {
        print("🔐 AuthManager: Handling activation")
        await revalidateSession()
    }
    
    func didEnterBackground() {
        print("🔐 AuthManager: Entering background")
    }
    
    private func revalidateSession() async {
        print("🔐 AuthManager: Revalidating session...")
        do {
            let credentials = try getAWSCredentials()
            // Update EC2Service configuration
            EC2Service.shared.updateConfiguration(
                with: credentials,
                region: selectedRegion.awsRegionType
            )
            // Validate credentials with AWS
            try await EC2Service.shared.validateCredentials()
            isAuthenticated = true
            print("🔐 AuthManager: ✅ Session revalidated")
        } catch {
            isAuthenticated = false
            print("🔐 AuthManager: ❌ Session invalid: \(error)")
        }
    }
    
    private func restoreFromKeychain() {
        do {
            if let accessKeyId = try keychain.get("accessKeyId"),
               let secretAccessKey = try keychain.get("secretAccessKey"),
               let regionString = try keychain.get("region"),
               let region = AWSRegion(rawValue: regionString) {
                
                print("🔐 AuthManager: Restoring from keychain...")
                print("🔐 AuthManager: Region from keychain: \(regionString)")
                
                self.accessKeyId = accessKeyId
                self.secretAccessKey = secretAccessKey
                self.selectedRegion = region
                
                // Configure AWS with restored credentials
                let credentials = AWSCredentials(
                    accessKeyId: accessKeyId,
                    secretAccessKey: secretAccessKey
                )
                configureAWS(with: credentials)
                
                self.isAuthenticated = true
                print("🔐 AuthManager: ✅ Restored from Keychain")
            }
        } catch {
            print("🔐 AuthManager: ❌ Failed to restore from Keychain: \(error)")
        }
    }
    
    func updateRegion(_ newRegion: AWSRegion) async throws {
        guard newRegion != selectedRegion else { return }
        
        print("\n🌎 AuthManager: Changing region to \(newRegion.rawValue)")
        
        // Get current credentials
        let credentials = try getAWSCredentials()
        
        // Update region first
        selectedRegion = newRegion
        
        // Configure AWS with new region
        EC2Service.shared.updateConfiguration(
            with: credentials,
            region: newRegion.awsRegionType
        )
        
        // Save new region
        try keychain.set(newRegion.rawValue, key: "region")
        
        // Update widget's current region
        WidgetService.shared.updateCurrentRegion(newRegion.rawValue)
        
        print("✅ Region changed successfully to \(newRegion.rawValue)")
        
        // Clear any cached data for old region
        EC2Service.shared.clearAllData()
    }
    
    private func configureAWS(with credentials: AWSCredentials) {
        print("\n🔧 Configuring AWS with credentials...")
        
        // Update EC2Service configuration
        EC2Service.shared.updateConfiguration(
            with: credentials,
            region: selectedRegion.awsRegionType
        )
        
        print("✅ AWS configured with credentials for region \(selectedRegion.rawValue)")
    }
}

// Keep the AWSRegion extension
extension AWSRegion {
    var awsRegionType: AWSRegionType {
        switch self {
        case .usEast1: return .USEast1
        case .usEast2: return .USEast2
        case .usWest1: return .USWest1
        case .usWest2: return .USWest2
        case .euWest1: return .EUWest1
        case .euWest2: return .EUWest2
        case .euCentral1: return .EUCentral1
        case .apSoutheast1: return .APSoutheast1
        case .apSoutheast2: return .APSoutheast2
        }
    }
} 
