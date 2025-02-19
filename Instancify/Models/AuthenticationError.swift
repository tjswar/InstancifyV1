import Foundation

enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case networkError
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid AWS credentials. Please check your Access Key ID and Secret Access Key."
        case .networkError:
            return "Network error. Please check your internet connection."
        case .configurationError:
            return "Failed to configure AWS services."
        }
    }
} 