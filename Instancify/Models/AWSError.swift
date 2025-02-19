import Foundation

enum AWSError: LocalizedError {
    case notConfigured
    case invalidRegion
    case invalidCredentials
    case invalidConfiguration(String)
    case serviceUnavailable
    case serviceError(String)
    case networkError
    case noCredentialsFound
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AWS is not configured"
        case .invalidRegion:
            return "Invalid AWS region"
        case .invalidCredentials:
            return "Invalid AWS credentials"
        case .invalidConfiguration(let message), .configurationError(let message):
            return "AWS configuration error: \(message)"
        case .serviceUnavailable:
            return "AWS service is unavailable"
        case .serviceError(let message):
            return "AWS service error: \(message)"
        case .networkError:
            return "Network error occurred"
        case .noCredentialsFound:
            return "No AWS credentials found"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .notConfigured:
            return "AWS services have not been configured"
        case .invalidRegion:
            return "The specified AWS region is not valid"
        case .invalidCredentials:
            return "The provided AWS credentials are invalid or expired"
        case .invalidConfiguration(let message), .configurationError(let message):
            return message
        case .serviceUnavailable:
            return "The requested AWS service is not available"
        case .serviceError(let message):
            return message
        case .networkError:
            return "A network error occurred while communicating with AWS"
        case .noCredentialsFound:
            return "No AWS credentials were found in the keychain or environment"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Configure AWS services before making any requests"
        case .invalidRegion:
            return "Check the region name and try again"
        case .invalidCredentials:
            return "Verify your AWS access key and secret key"
        case .invalidConfiguration, .configurationError:
            return "Check your AWS configuration settings"
        case .serviceUnavailable:
            return "Try again later or contact AWS support"
        case .serviceError:
            return "Check AWS service status and try again"
        case .networkError:
            return "Check your internet connection and try again"
        case .noCredentialsFound:
            return "Add AWS credentials to the keychain or set them as environment variables"
        }
    }
} 