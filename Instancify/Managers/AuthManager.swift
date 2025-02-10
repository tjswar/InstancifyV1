import AWSCore
import AWSEC2
import AWSS3
import AWSDynamoDB
import Security

class AuthManager {
    static let shared = AuthManager()
    private let serviceKey = "DefaultKey"
    
    func configure(accessKey: String, secretKey: String, region: AWSRegionType) async throws {
        // Clear any existing configuration
        clearConfiguration()
        
        // Create credentials provider
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: accessKey,
            secretKey: secretKey
        )
        
        // Validate credentials
        try await validateCredentials(provider: credentialsProvider)
        
        // Create and set configuration
        let configuration = AWSServiceConfiguration(
            region: region,
            credentialsProvider: credentialsProvider
        )!
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Register AWS services
        AWSEC2.register(with: configuration, forKey: serviceKey)
        AWSS3.register(with: configuration, forKey: serviceKey)
        AWSDynamoDB.register(with: configuration, forKey: serviceKey)
        
        // Store credentials securely
        try await KeychainManager.shared.storeCredentials(
            accessKeyId: accessKey,
            secretAccessKey: secretKey,
            region: region.stringValue
        )
    }
    
    private func validateCredentials(provider: AWSCredentialsProvider) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            provider.credentials().continueWith { task in
                if let error = task.error {
                    continuation.resume(throwing: error)
                } else if let credentials = task.result,
                          !credentials.accessKey.isEmpty,
                          !credentials.secretKey.isEmpty {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AuthError.invalidCredentials)
                }
                return nil
            }
        }
    }
    
    func clearConfiguration() {
        AWSEC2.remove(forKey: serviceKey)
        AWSS3.remove(forKey: serviceKey)
        AWSDynamoDB.remove(forKey: serviceKey)
        AWSServiceManager.default().defaultServiceConfiguration = nil
    }
}

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid AWS credentials. Please check your Access Key ID and Secret Access Key."
        case .networkError:
            return "Network error. Please check your internet connection."
        }
    }
}

extension AWSRegionType {
    var stringValue: String {
        switch self {
        case .USEast1: return "us-east-1"
        case .USEast2: return "us-east-2"
        case .USWest1: return "us-west-1"
        case .USWest2: return "us-west-2"
        case .EUWest1: return "eu-west-1"
        case .EUCentral1: return "eu-central-1"
        case .APSoutheast1: return "ap-southeast-1"
        case .APSoutheast2: return "ap-southeast-2"
        default: return "us-east-1"
        }
    }
} 