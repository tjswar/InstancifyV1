import Foundation
import SwiftUI

enum AWSServiceType: String, CaseIterable, Identifiable, Codable {
    case ec2 = "EC2"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .ec2: return "EC2 Instances"
        }
    }
    
    var description: String {
        switch self {
        case .ec2: return "Manage virtual servers"

        }
    }
    
    var iconName: String {
        switch self {
        case .ec2: return "server.rack"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .ec2: return .blue
        }
    }
} 
