import Foundation
import SwiftUI

enum AWSResourceType: String {
    case ec2 = "EC2"
    case sagemaker = "SageMaker"
    case rds = "RDS"
    
    var iconName: String {
        switch self {
        case .ec2: return "server.rack"
        case .sagemaker: return "brain"
        case .rds: return "database"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .ec2: return .blue
        case .sagemaker: return .purple
        case .rds: return .green
        }
    }
    
    var title: String {
        switch self {
        case .ec2: return "EC2 Instances"
        case .sagemaker: return "SageMaker Notebooks"
        case .rds: return "RDS Databases"
        }
    }
    
    var description: String {
        switch self {
        case .ec2: return "Manage virtual servers"
        case .sagemaker: return "Machine learning notebooks"
        case .rds: return "Relational databases"
        }
    }
} 