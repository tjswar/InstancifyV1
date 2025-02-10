import Foundation
import AWSCore
import AWSEC2

class AWSConfigurationService {
    static let shared = AWSConfigurationService()
    private var isConfigured = false
    
    private init() {}
    
    func configure() throws {
        do {
            let credentials = try KeychainManager.shared.retrieveCredentials()
            let region = try KeychainManager.shared.getRegion()
            
            let credentialsProvider = AWSStaticCredentialsProvider(
                accessKey: credentials.accessKeyId,
                secretKey: credentials.secretAccessKey
            )
            
            let configuration = AWSServiceConfiguration(
                region: mapRegionToAWSType(region),
                credentialsProvider: credentialsProvider
            )
            
            AWSServiceManager.default().defaultServiceConfiguration = configuration
            isConfigured = true
            print("✅ AWS SDK configured with stored credentials")
        } catch {
            isConfigured = false
            print("❌ AWS configuration failed: \(error)")
            throw error // Propagate the error
        }
    }
    
    func validateConfiguration() throws {
        guard isConfigured else {
            throw NSError(domain: "AWSConfig", code: 401, userInfo: [NSLocalizedDescriptionKey: "AWS not configured"])
        }
    }
    
    private func mapRegionToAWSType(_ region: String) -> AWSRegionType {
        switch region {
        case "us-east-1": return .USEast1
        case "us-east-2": return .USEast2
        case "us-west-1": return .USWest1
        case "us-west-2": return .USWest2
        case "eu-west-1": return .EUWest1
        case "eu-west-2": return .EUWest2
        case "eu-central-1": return .EUCentral1
        case "ap-southeast-1": return .APSoutheast1
        case "ap-southeast-2": return .APSoutheast2
        case "ap-northeast-1": return .APNortheast1
        case "ap-northeast-2": return .APNortheast2
        case "sa-east-1": return .SAEast1
        default: return .USEast1
        }
    }
    
    static func updateConfiguration(
        accessKeyId: String,
        secretAccessKey: String,
        region: AWSRegionType
    ) {
        print("🔧 AWSConfig: Updating configuration...")
        print("🔧 AWSConfig: Region: \(region)")
        print("🔧 AWSConfig: Region string value: \(region.stringValue)")
        
        // Clean up existing configuration
        AWSServiceManager.default().defaultServiceConfiguration = nil
        AWSEC2.remove(forKey: "DefaultKey")
        AWSEC2.remove(forKey: "ValidationKey")
        
        // Create credentials provider
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines),
            secretKey: secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // Create endpoint
        let regionString = region.stringValue.lowercased()
        let serviceEndpoint = "ec2.\(regionString).amazonaws.com"
        let url = URL(string: "https://\(serviceEndpoint)")!
        
        print("🔧 AWSConfig: Using endpoint: \(serviceEndpoint)")
        
        let endpoint = AWSEndpoint(
            region: region,
            serviceName: "ec2",
            url: url
        )
        
        // Create and set configuration
        let configuration = AWSServiceConfiguration(
            region: region,
            endpoint: endpoint,
            credentialsProvider: credentialsProvider
        )!
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        print("🔧 AWSConfig: ✅ Configuration updated successfully")
    }
    
    private static func unregisterServices() {
        AWSEC2.remove(forKey: "DefaultKey")
    }
    
    private static func registerServices(with configuration: AWSServiceConfiguration) {
        AWSEC2.register(with: configuration, forKey: "DefaultKey")
    }
} 