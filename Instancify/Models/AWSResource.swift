import Foundation

struct AWSResource: Identifiable {
    let id: String
    let instance: EC2Instance
    let type: AWSResourceType
    
    init(from instance: EC2Instance) {
        self.id = instance.id
        self.instance = instance
        self.type = .ec2
    }
    
    static func error(_ message: String) -> AWSResource {
        let errorInstance = EC2Instance(
            id: "error",
            instanceType: "unknown",
            state: .unknown,
            name: message,
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
        return AWSResource(from: errorInstance)
    }
} 