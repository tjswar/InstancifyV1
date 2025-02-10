import Foundation

enum AppError: Error, CustomStringConvertible {
    case authenticationFailed(String)
    case networkError(String)
    case invalidCredentials
    case unknown(Error)
    
    var description: String {
        switch self {
        case .authenticationFailed(let message):
            return message
        case .networkError(let message):
            return message
        case .invalidCredentials:
            return "Invalid AWS credentials. Please check your Access Key ID and Secret Access Key."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
} 