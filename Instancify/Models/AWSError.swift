import Foundation

enum AWSError: LocalizedError {
    case notConfigured
    case invalidCredentials
    case invalidRegion
    case noCredentialsFound
    case configurationFailed
    case requestFailed
    case timeout
    case metricsNotAvailable
    case serviceError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AWS services are not properly configured"
        case .invalidCredentials:
            return "Invalid AWS credentials. Please check your Access Key ID and Secret Access Key"
        case .invalidRegion:
            return "Invalid AWS region selected"
        case .noCredentialsFound:
            return "No AWS credentials found. Please add your credentials in Settings"
        case .configurationFailed:
            return "Failed to configure AWS services"
        case .requestFailed:
            return "Failed to complete AWS request"
        case .timeout:
            return "Operation timed out. Please try again"
        case .metricsNotAvailable:
            return "Cost metrics are not available at this time"
        case .serviceError(let message):
            return "AWS Service Error: \(message)"
        case .unknown(let message):
            return message
        }
    }
    
    init(_ message: String) {
        self = .unknown(message)
    }
} 