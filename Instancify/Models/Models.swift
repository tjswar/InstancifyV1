import Foundation
import FirebaseFirestore

struct NotificationItem: Identifiable, Codable {
    let id: String
    let type: String
    let title: String
    let body: String
    let instanceId: String?
    let instanceName: String
    let region: String
    let runtime: Int?
    let threshold: Int?
    let timestamp: Date?
    let time: String?
    let formattedTime: String?
    let createdAt: Date?
    
    init(
        id: String,
        type: String,
        title: String,
        body: String,
        instanceId: String?,
        instanceName: String,
        region: String,
        runtime: Int? = nil,
        threshold: Int? = nil,
        timestamp: Date? = nil,
        time: String? = nil,
        formattedTime: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.instanceId = instanceId
        self.instanceName = instanceName
        self.region = region
        self.runtime = runtime
        self.threshold = threshold
        self.timestamp = timestamp
        self.time = time
        self.formattedTime = formattedTime
        self.createdAt = createdAt
    }
}

extension NotificationHistoryItem {
    init(from item: NotificationItem) {
        self.id = item.id
        self.type = item.type
        self.title = item.title
        self.body = item.body
        self.instanceId = item.instanceId ?? ""
        self.instanceName = item.instanceName
        self.threshold = item.threshold
        self.runtime = item.runtime
        self.timestamp = item.timestamp
        self.time = item.time
        self.formattedTime = item.formattedTime
        self.createdAt = item.createdAt
    }
}

// MARK: - Notification Item Extensions
extension NotificationItem {
    var formattedRuntime: String? {
        guard let runtime = runtime else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var formattedThreshold: String? {
        guard let threshold = threshold else { return nil }
        let hours = threshold / 60
        let minutes = threshold % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
} 