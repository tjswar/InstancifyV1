import Foundation

enum AWSService: String, CaseIterable, Hashable {
    case ec2
    case cloudWatch
    case s3
    case dynamoDB
    
    var displayName: String {
        switch self {
        case .ec2: return "EC2"
        case .cloudWatch: return "CloudWatch"
        case .s3: return "S3"
        case .dynamoDB: return "DynamoDB"
        }
    }
    
    var isEnabled: Bool {
        switch self {
        case .ec2: return true // EC2 is always enabled
        case .cloudWatch: return UserDefaults.standard.bool(forKey: "enable_\(rawValue)")
        case .s3: return UserDefaults.standard.bool(forKey: "enable_\(rawValue)")
        case .dynamoDB: return UserDefaults.standard.bool(forKey: "enable_\(rawValue)")
        }
    }
} 