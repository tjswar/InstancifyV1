import Foundation
import AWSEC2
import SwiftUI

enum InstanceState: String, Codable, Equatable {
    case pending
    case running
    case shuttingDown = "shutting-down"
    case terminated
    case stopping
    case stopped
    case unknown
    
    var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return .red
        case .pending, .shuttingDown, .stopping: return .orange
        case .terminated: return .gray
        case .unknown: return .gray
        }
    }
    
    var displayString: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Running"
        case .shuttingDown: return "Shutting Down"
        case .terminated: return "Terminated"
        case .stopping: return "Stopping"
        case .stopped: return "Stopped"
        case .unknown: return "Unknown"
        }
    }
}

class EC2Instance: ObservableObject, Identifiable, Equatable {
    let id: String
    let instanceType: String
    @Published var state: InstanceState
    let name: String?
    let launchTime: Date?
    let publicIP: String?
    let privateIP: String?
    @Published var autoStopEnabled: Bool
    @Published var countdown: String?
    let stateTransitionTime: Date?
    let hourlyRate: Double
    @Published var runtime: Int
    @Published var currentCost: Double
    @Published var projectedDailyCost: Double
    let region: String
    
    var instanceId: String { id }
    
    static func == (lhs: EC2Instance, rhs: EC2Instance) -> Bool {
        return lhs.id == rhs.id &&
               lhs.instanceType == rhs.instanceType &&
               lhs.state == rhs.state &&
               lhs.name == rhs.name &&
               lhs.launchTime == rhs.launchTime &&
               lhs.publicIP == rhs.publicIP &&
               lhs.privateIP == rhs.privateIP &&
               lhs.autoStopEnabled == rhs.autoStopEnabled &&
               lhs.countdown == rhs.countdown &&
               lhs.stateTransitionTime == rhs.stateTransitionTime &&
               lhs.hourlyRate == rhs.hourlyRate &&
               lhs.runtime == rhs.runtime &&
               lhs.currentCost == rhs.currentCost &&
               lhs.projectedDailyCost == rhs.projectedDailyCost &&
               lhs.region == rhs.region
    }
    
    init(id: String, instanceType: String, state: InstanceState, name: String?, launchTime: Date?, publicIP: String?, privateIP: String?, autoStopEnabled: Bool, countdown: String?, stateTransitionTime: Date?, hourlyRate: Double, runtime: Int, currentCost: Double, projectedDailyCost: Double, region: String) {
        self.id = id
        self.instanceType = instanceType
        self.state = state
        self.name = name
        self.launchTime = launchTime
        self.publicIP = publicIP
        self.privateIP = privateIP
        self.autoStopEnabled = autoStopEnabled
        self.countdown = countdown
        self.stateTransitionTime = stateTransitionTime
        self.hourlyRate = hourlyRate
        self.runtime = runtime
        self.currentCost = currentCost
        self.projectedDailyCost = projectedDailyCost
        self.region = region
    }
    
    var runningTime: String {
        guard let launch = launchTime else { return "N/A" }
        let duration = Date().timeIntervalSince(launch)
        
        let hours = Int(floor(duration / 3600))
        let minutes = Int(floor(duration.truncatingRemainder(dividingBy: 3600) / 60))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var costStatus: String {
        switch state {
        case .running:
            return "Accumulating costs"
        case .stopped:
            return "Not incurring costs"
        default:
            return "Cost status unknown"
        }
    }
    
    func updateCosts(current: Double, projected: Double) {
        currentCost = current
        projectedDailyCost = projected
    }
}

#if DEBUG
extension EC2Instance {
    static func preview() -> EC2Instance {
        return EC2Instance(
            id: "i-123456789",
            instanceType: "t2.micro",
            state: .running,
            name: "Preview Instance",
            launchTime: Date(),
            publicIP: "54.123.45.67",
            privateIP: "172.16.0.100",
            autoStopEnabled: false,
            countdown: nil,
            stateTransitionTime: nil,
            hourlyRate: 0.0116,
            runtime: 0,
            currentCost: 0,
            projectedDailyCost: 0,
            region: "us-east-1"
        )
    }
    
    static func empty() -> EC2Instance {
        return EC2Instance(
            id: "empty",
            instanceType: "unknown",
            state: .unknown,
            name: "No instances found",
            launchTime: nil,
            publicIP: nil,
            privateIP: nil,
            autoStopEnabled: false,
            countdown: nil,
            stateTransitionTime: nil,
            hourlyRate: 0.0,
            runtime: 0,
            currentCost: 0,
            projectedDailyCost: 0,
            region: "unknown"
        )
    }
    
    static func error() -> EC2Instance {
        return EC2Instance(
            id: "error",
            instanceType: "unknown",
            state: .unknown,
            name: "Error loading instances",
            launchTime: nil,
            publicIP: nil,
            privateIP: nil,
            autoStopEnabled: false,
            countdown: nil,
            stateTransitionTime: nil,
            hourlyRate: 0.0,
            runtime: 0,
            currentCost: 0,
            projectedDailyCost: 0,
            region: "unknown"
        )
    }
}
#endif 

extension EC2Instance {
    convenience init?(from awsInstance: AWSEC2Instance) {
        guard let instanceId = awsInstance.instanceId else { return nil }
        
        let instanceType = String(describing: awsInstance.instanceType)
        
        let stateString: String
        if let stateCode = awsInstance.state?.code?.intValue {
            switch stateCode {
            case 0: stateString = "pending"
            case 16: stateString = "running"
            case 32: stateString = "shutting-down"
            case 48: stateString = "terminated"
            case 64: stateString = "stopping"
            case 80: stateString = "stopped"
            default: stateString = "unknown"
            }
        } else {
            stateString = "unknown"
        }
        
        let name = awsInstance.tags?.first(where: { $0.key == "Name" })?.value
        let stateTransitionTime = awsInstance.stateTransitionReason?.contains("User initiated") == true ? Date() : awsInstance.launchTime
        
        let hourlyRate: Double
        switch instanceType {
        case "t2.micro": hourlyRate = 0.0116
        case "t2.small": hourlyRate = 0.023
        case "t2.medium": hourlyRate = 0.0464
        default: hourlyRate = 0.0116
        }
        
        // Get region from EC2Service configuration
        let region = (AWSEC2.default().configuration.endpoint as? AWSEndpoint)?.regionName ?? "us-east-1"
        
        self.init(
            id: instanceId,
            instanceType: instanceType,
            state: InstanceState(rawValue: stateString) ?? .unknown,
            name: name,
            launchTime: awsInstance.launchTime,
            publicIP: awsInstance.publicIpAddress,
            privateIP: awsInstance.privateIpAddress,
            autoStopEnabled: false,
            countdown: nil,
            stateTransitionTime: stateTransitionTime,
            hourlyRate: hourlyRate,
            runtime: 0,
            currentCost: 0,
            projectedDailyCost: 0,
            region: region
        )
    }
} 

private extension Double {
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
} 