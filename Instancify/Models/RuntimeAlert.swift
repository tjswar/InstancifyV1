import Foundation
import FirebaseFirestore

struct RuntimeAlert: Codable, Identifiable {
    let id: String
    let instanceId: String
    let instanceName: String
    let region: String
    let threshold: Int
    let launchTime: Date
    let scheduledTime: Date
    var enabled: Bool = true
    var regions: Set<String> = []
    
    init(
        id: String = UUID().uuidString,
        instanceId: String,
        instanceName: String,
        region: String,
        threshold: Int,
        launchTime: Date,
        scheduledTime: Date,
        enabled: Bool = true,
        regions: Set<String> = []
    ) {
        self.id = id
        self.instanceId = instanceId
        self.instanceName = instanceName
        self.region = region
        self.threshold = threshold
        self.launchTime = launchTime
        self.scheduledTime = scheduledTime
        self.enabled = enabled
        self.regions = regions
    }
    
    // Firestore serialization
    init?(dictionary: [String: Any]) {
        guard let instanceId = dictionary["instanceId"] as? String,
              let instanceName = dictionary["instanceName"] as? String,
              let region = dictionary["region"] as? String,
              let threshold = dictionary["threshold"] as? Int,
              let launchTime = (dictionary["launchTime"] as? Timestamp)?.dateValue(),
              let scheduledTime = (dictionary["scheduledTime"] as? Timestamp)?.dateValue() else {
            return nil
        }
        
        self.id = dictionary["id"] as? String ?? UUID().uuidString
        self.instanceId = instanceId
        self.instanceName = instanceName
        self.region = region
        self.threshold = threshold
        self.launchTime = launchTime
        self.scheduledTime = scheduledTime
        self.enabled = dictionary["enabled"] as? Bool ?? true
        self.regions = Set(dictionary["regions"] as? [String] ?? [])
    }
    
    // Convert to dictionary for Firestore
    var dictionary: [String: Any] {
        [
            "id": id,
            "instanceId": instanceId,
            "instanceName": instanceName,
            "region": region,
            "threshold": threshold,
            "launchTime": Timestamp(date: launchTime),
            "scheduledTime": Timestamp(date: scheduledTime),
            "enabled": enabled,
            "regions": Array(regions)
        ]
    }
} 