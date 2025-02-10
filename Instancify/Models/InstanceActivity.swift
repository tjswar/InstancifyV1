import Foundation

struct InstanceActivity: Identifiable, Equatable, Codable {
    let id: String
    let instanceId: String
    let timestamp: Date
    let type: ActivityType
    let details: String
    let runtime: TimeInterval
    let cost: Double?
    
    init(
        id: String = UUID().uuidString,
        instanceId: String,
        timestamp: Date = Date(),
        type: ActivityType,
        details: String,
        runtime: TimeInterval = 0,
        cost: Double? = nil
    ) {
        self.id = id
        self.instanceId = instanceId
        self.timestamp = timestamp
        self.type = type
        self.details = details
        self.runtime = runtime
        self.cost = cost
    }
    
    enum ActivityType: Codable, Equatable {
        case stateChange(from: String, to: String)
        case autoStop
        case userAction
        
        // Custom coding keys for encoding/decoding
        private enum CodingKeys: String, CodingKey {
            case type, from, to
        }
        
        // Computed property for display
        var rawValue: String {
            switch self {
            case .stateChange: return "State Change"
            case .autoStop: return "Auto-Stop"
            case .userAction: return "User Action"
            }
        }
        
        // Custom encoding
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .stateChange(let from, let to):
                try container.encode("stateChange", forKey: .type)
                try container.encode(from, forKey: .from)
                try container.encode(to, forKey: .to)
            case .autoStop:
                try container.encode("autoStop", forKey: .type)
            case .userAction:
                try container.encode("userAction", forKey: .type)
            }
        }
        
        // Custom decoding
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "stateChange":
                let from = try container.decode(String.self, forKey: .from)
                let to = try container.decode(String.self, forKey: .to)
                self = .stateChange(from: from, to: to)
            case "autoStop":
                self = .autoStop
            case "userAction":
                self = .userAction
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Invalid activity type"
                )
            }
        }
    }
    
    // Check if activity is older than 24 hours
    var isExpired: Bool {
        Calendar.current.dateComponents([.hour], from: timestamp, to: Date()).hour ?? 0 >= 24
    }
    
    // Format timestamp relative to now
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    // Static methods for activity management
    static func cleanupOldActivities(for instanceId: String) {
        var activities = loadActivities(for: instanceId)
        activities.removeAll { $0.isExpired }
        saveActivities(activities, for: instanceId)
    }
    
    static func addActivity(instanceId: String, type: ActivityType, details: String, runtime: TimeInterval = 0, cost: Double? = nil) {
        var activities = loadActivities(for: instanceId)
        
        // Add new activity
        let newActivity = InstanceActivity(
            instanceId: instanceId,
            type: type,
            details: details,
            runtime: runtime,
            cost: cost
        )
        activities.insert(newActivity, at: 0) // Add to beginning of array
        
        // Remove activities older than 24 hours
        activities.removeAll { $0.isExpired }
        
        // Keep only last 10 activities
        if activities.count > 10 {
            activities = Array(activities.prefix(10))
        }
        
        saveActivities(activities, for: instanceId)
    }
    
    static func loadActivities(for instanceId: String) -> [InstanceActivity] {
        let defaults = UserDefaults.standard
        let key = "instance_activities_\(instanceId)"
        guard let data = defaults.data(forKey: key),
              let activities = try? JSONDecoder().decode([InstanceActivity].self, from: data) else {
            return []
        }
        return activities
    }
    
    private static func saveActivities(_ activities: [InstanceActivity], for instanceId: String) {
        let defaults = UserDefaults.standard
        let key = "instance_activities_\(instanceId)"
        if let encoded = try? JSONEncoder().encode(activities) {
            defaults.set(encoded, forKey: key)
        }
    }
} 