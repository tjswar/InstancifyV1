import Foundation

struct AutoStopConfig: Codable, CustomStringConvertible {
    let instanceId: String
    let stopTime: Date
    
    var description: String {
        return "AutoStopConfig(instanceId: \(instanceId), stopTime: \(stopTime))"
    }
} 