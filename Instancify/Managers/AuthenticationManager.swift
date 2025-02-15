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
    
    #if DEBUG
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    #endif
    
    private init() {
        print("🔐 AuthManager: Initializing...")
        #if DEBUG
        if isPreview {
            print("🔐 AuthManager: Running in preview mode")
            return
        }
        #endif
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
        
        // Unregister AWS services
        print("🔄 Unregistering AWS services...")
        AWSEC2.remove(forKey: "defaultKey")
        
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
    
    @MainActor
    func configureAWSServices() async throws {
        print("\n🔧 Configuring AWS services...")
        
        // Get credentials
        let credentials = try getAWSCredentials()
        
        // Clean up any existing AWS configurations
        AWSServiceManager.default().defaultServiceConfiguration = nil
        AWSEC2.remove(forKey: "defaultKey")
        
        // Create credential provider
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: credentials.accessKeyId,
            secretKey: credentials.secretAccessKey
        )
        
        // Create service configuration
        let configuration = AWSServiceConfiguration(
            region: selectedRegion.awsRegionType,
            credentialsProvider: credentialsProvider
        )!
        
        // Set default service configuration
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Register AWS services
        print("📝 Registering AWS services...")
        AWSEC2.register(with: configuration, forKey: "defaultKey")
        
        // Update EC2Service configuration
        EC2Service.shared.updateConfiguration(
            with: credentials,
            region: selectedRegion.awsRegionType
        )
        
        print("✅ AWS configured with credentials for region \(selectedRegion.rawValue)")
        
        // Validate credentials immediately
        try await EC2Service.shared.validateCredentials()
        print("✅ AWS credentials validated successfully")
    }
    
    private func restoreFromKeychain() {
        print("🔐 AuthManager: Attempting to restore from keychain...")
        do {
            guard let accessKeyId = try keychain.get("accessKeyId"),
                  let secretAccessKey = try keychain.get("secretAccessKey"),
                  let regionString = try keychain.get("region"),
                  let region = AWSRegion(rawValue: regionString) else {
                print("🔐 AuthManager: No credentials found in Keychain")
                return
            }
            
            print("🔐 AuthManager: Found credentials in keychain")
            print("🔐 AuthManager: Region from keychain: \(regionString)")
            
            self.accessKeyId = accessKeyId
            self.secretAccessKey = secretAccessKey
            self.selectedRegion = region
            
            // Set authenticated state
            self.isAuthenticated = true
            print("🔐 AuthManager: ✅ Restored from Keychain")
            
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
        
        // Unregister existing services
        print("🔄 Unregistering AWS services for region change...")
        AWSEC2.remove(forKey: "defaultKey")
        
        // Configure AWS with new region
        try await configureAWSServices()
        
        // Save new region
        try keychain.set(newRegion.rawValue, key: "region")
        
        // Update widget's current region
        WidgetService.shared.updateCurrentRegion(newRegion.rawValue)
        
        print("✅ Region changed successfully to \(newRegion.rawValue)")
        
        // Clear any cached data for old region
        EC2Service.shared.clearAllData()
    }
} 
