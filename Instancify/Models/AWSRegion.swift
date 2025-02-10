import Foundation
import AWSCore

enum AWSRegion: String, CaseIterable, Identifiable {
    case usEast1 = "us-east-1"
    case usEast2 = "us-east-2"
    case usWest1 = "us-west-1"
    case usWest2 = "us-west-2"
    case euWest1 = "eu-west-1"
    case euWest2 = "eu-west-2"
    case euCentral1 = "eu-central-1"
    case apSoutheast1 = "ap-southeast-1"
    case apSoutheast2 = "ap-southeast-2"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .usEast1: return "US East (N. Virginia)"
        case .usEast2: return "US East (Ohio)"
        case .usWest1: return "US West (N. California)"
        case .usWest2: return "US West (Oregon)"
        case .euWest1: return "EU (Ireland)"
        case .euWest2: return "EU (London)"
        case .euCentral1: return "EU (Frankfurt)"
        case .apSoutheast1: return "Asia Pacific (Singapore)"
        case .apSoutheast2: return "Asia Pacific (Sydney)"
        }
    }
    
    func toAWSRegionType() -> AWSRegionType {
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