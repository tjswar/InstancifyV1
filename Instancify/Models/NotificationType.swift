import Foundation
import SwiftUI

enum NotificationType: Identifiable, Codable {
    case instanceStarted(instanceId: String, name: String)
    case instanceStopped(instanceId: String, name: String)
    case instanceError(message: String)
    case autoStopEnabled(instanceId: String, name: String, stopTime: Date)
    case autoStopWarning(instanceId: String, name: String, secondsRemaining: Int)
    case instanceAutoStopped(instanceId: String, name: String)
    case instanceStateChanged(instanceId: String, name: String, from: String, to: String)
    case instanceRunningLong(instanceId: String, name: String, runtime: TimeInterval, cost: Double?)
    case runtimeAlert(instanceId: String, instanceName: String, runtime: Int, threshold: Int)
    
    var id: String {
        switch self {
        case .instanceStarted(let instanceId, _): return "start-\(instanceId)-\(UUID().uuidString)"
        case .instanceStopped(let instanceId, _): return "stop-\(instanceId)-\(UUID().uuidString)"
        case .instanceError: return "error-\(UUID().uuidString)"
        case .autoStopEnabled(let instanceId, _, _): return "enabled-\(instanceId)-\(UUID().uuidString)"
        case .autoStopWarning(let instanceId, _, _): return "warning-\(instanceId)-\(UUID().uuidString)"
        case .instanceAutoStopped(let instanceId, _): return "autostop-\(instanceId)-\(UUID().uuidString)"
        case .instanceStateChanged(let instanceId, _, _, _): return "state-\(instanceId)-\(UUID().uuidString)"
        case .instanceRunningLong(let instanceId, _, _, _): return "runtime-\(instanceId)-\(UUID().uuidString)"
        case .runtimeAlert(let instanceId, _, _, _): return "alert-\(instanceId)-\(UUID().uuidString)"
        }
    }
    
    var instanceId: String? {
        switch self {
        case .instanceStarted(let instanceId, _),
             .instanceStopped(let instanceId, _),
             .autoStopEnabled(let instanceId, _, _),
             .autoStopWarning(let instanceId, _, _),
             .instanceAutoStopped(let instanceId, _),
             .instanceStateChanged(let instanceId, _, _, _),
             .instanceRunningLong(let instanceId, _, _, _),
             .runtimeAlert(let instanceId, _, _, _):
            return instanceId
        case .instanceError:
            return nil
        }
    }
    
    var title: String {
        switch self {
        case .instanceStarted: return "Instance Started"
        case .instanceStopped: return "Instance Stopped"
        case .instanceError: return "Error"
        case .autoStopEnabled: return "Auto-Stop Scheduled"
        case .autoStopWarning: return "Auto-Stop Warning"
        case .instanceAutoStopped: return "Auto-Stop Complete"
        case .instanceStateChanged: return "Instance State Changed"
        case .instanceRunningLong: return "⚠️ Long Running Instance"
        case .runtimeAlert: return "⚠️ Runtime Alert"
        }
    }
    
    var body: String {
        switch self {
        case .instanceStarted(_, let name):
            return "Instance '\(name)' has been started"
        case .instanceStopped(_, let name):
            return "Instance '\(name)' has been stopped"
        case .instanceError(let message):
            return message
        case .autoStopEnabled(_, let name, let stopTime):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Instance '\(name)' will be stopped at \(formatter.string(from: stopTime))"
        case .autoStopWarning(_, let name, let seconds):
            return "Instance '\(name)' will be stopped in \(seconds) seconds"
        case .instanceAutoStopped(_, let name):
            return "Instance '\(name)' has been automatically stopped"
        case .instanceStateChanged(_, let name, let from, let to):
            return "Instance '\(name)' state changed from \(from) to \(to)"
        case .instanceRunningLong(_, let name, let runtime, let cost):
            let hours = Int(runtime) / 3600
            let minutes = Int(runtime) / 60 % 60
            if let cost = cost {
                return "Instance '\(name)' has been running for \(hours)h \(minutes)m (Cost: $\(String(format: "%.2f", cost)))"
            } else {
                return "Instance '\(name)' has been running for \(hours)h \(minutes)m"
            }
        case .runtimeAlert(_, let name, let runtime, _):
            let hours = runtime / 3600
            let minutes = (runtime % 3600) / 60
            return "Instance '\(name)' has been running for \(hours)h \(minutes)m"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, instanceId, name, message, stopTime, secondsRemaining
        case runtime, cost, from, to, threshold
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "instanceStarted":
            let instanceId = try container.decode(String.self, forKey: .instanceId)
            let name = try container.decode(String.self, forKey: .name)
            self = .instanceStarted(instanceId: instanceId, name: name)
        case "instanceStopped":
            let instanceId = try container.decode(String.self, forKey: .instanceId)
            let name = try container.decode(String.self, forKey: .name)
            self = .instanceStopped(instanceId: instanceId, name: name)
        case "instanceError":
            let message = try container.decode(String.self, forKey: .message)
            self = .instanceError(message: message)
        case "autoStopEnabled":
            let instanceId = try container.decode(String.self, forKey: .instanceId)
            let name = try container.decode(String.self, forKey: .name)
            let stopTime = try container.decode(Date.self, forKey: .stopTime)
            self = .autoStopEnabled(instanceId: instanceId, name: name, stopTime: stopTime)
        case "autoStopWarning":
            let instanceId = try container.decode(String.self, forKey: .instanceId)
            let name = try container.decode(String.self, forKey: .name)
            let secondsRemaining = try container.decode(Int.self, forKey: .secondsRemaining)
            self = .autoStopWarning(instanceId: instanceId, name: name, secondsRemaining: secondsRemaining)
        case "instanceAutoStopped":
            let instanceId = try container.decode(String.self, forKey: .instanceId)
            let name = try container.decode(String.self, forKey: .name)
            self = .instanceAutoStopped(instanceId: instanceId, name: name)
        case "instanceStateChanged":
            let instanceId = try container.decode(String.self, forKey: .instanceId)
            let name = try container.decode(String.self, forKey: .name)
            let from = try container.decode(String.self, forKey: .from)
            let to = try container.decode(String.self, forKey: .to)
            self = .instanceStateChanged(instanceId: instanceId, name: name, from: from, to: to)
        case "instanceRunningLong":
            let instanceId = try container.decode(String.self, forKey: .instanceId)
            let name = try container.decode(String.self, forKey: .name)
            let runtime = try container.decode(TimeInterval.self, forKey: .runtime)
            let cost = try container.decodeIfPresent(Double.self, forKey: .cost)
            self = .instanceRunningLong(instanceId: instanceId, name: name, runtime: runtime, cost: cost)
        case "runtimeAlert":
            let instanceId = try container.decode(String.self, forKey: .instanceId)
            let name = try container.decode(String.self, forKey: .name)
            let runtime = try container.decode(Int.self, forKey: .runtime)
            let threshold = try container.decode(Int.self, forKey: .threshold)
            self = .runtimeAlert(instanceId: instanceId, instanceName: name, runtime: runtime, threshold: threshold)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid notification type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .instanceStarted(let instanceId, let name):
            try container.encode("instanceStarted", forKey: .type)
            try container.encode(instanceId, forKey: .instanceId)
            try container.encode(name, forKey: .name)
        case .instanceStopped(let instanceId, let name):
            try container.encode("instanceStopped", forKey: .type)
            try container.encode(instanceId, forKey: .instanceId)
            try container.encode(name, forKey: .name)
        case .instanceError(let message):
            try container.encode("instanceError", forKey: .type)
            try container.encode(message, forKey: .message)
        case .autoStopEnabled(let instanceId, let name, let stopTime):
            try container.encode("autoStopEnabled", forKey: .type)
            try container.encode(instanceId, forKey: .instanceId)
            try container.encode(name, forKey: .name)
            try container.encode(stopTime, forKey: .stopTime)
        case .autoStopWarning(let instanceId, let name, let secondsRemaining):
            try container.encode("autoStopWarning", forKey: .type)
            try container.encode(instanceId, forKey: .instanceId)
            try container.encode(name, forKey: .name)
            try container.encode(secondsRemaining, forKey: .secondsRemaining)
        case .instanceAutoStopped(let instanceId, let name):
            try container.encode("instanceAutoStopped", forKey: .type)
            try container.encode(instanceId, forKey: .instanceId)
            try container.encode(name, forKey: .name)
        case .instanceStateChanged(let instanceId, let name, let from, let to):
            try container.encode("instanceStateChanged", forKey: .type)
            try container.encode(instanceId, forKey: .instanceId)
            try container.encode(name, forKey: .name)
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
        case .instanceRunningLong(let instanceId, let name, let runtime, let cost):
            try container.encode("instanceRunningLong", forKey: .type)
            try container.encode(instanceId, forKey: .instanceId)
            try container.encode(name, forKey: .name)
            try container.encode(runtime, forKey: .runtime)
            try container.encode(cost, forKey: .cost)
        case .runtimeAlert(let instanceId, let name, let runtime, let threshold):
            try container.encode("runtimeAlert", forKey: .type)
            try container.encode(instanceId, forKey: .instanceId)
            try container.encode(name, forKey: .name)
            try container.encode(runtime, forKey: .runtime)
            try container.encode(threshold, forKey: .threshold)
        }
    }
} 