import Foundation

struct NotificationHistoryItem: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let body: String
    let instanceId: String
    let instanceName: String
    let threshold: Int?
    let runtime: Int?
    let timestamp: Date?
    let time: String?
    let formattedTime: String?
    let createdAt: Date?
    
    // For backward compatibility with older stored data
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body = "message"
        case instanceId
        case instanceName
        case threshold
        case runtime
        case timestamp
        case time
        case formattedTime
        case createdAt
    }
    
    init(id: String = UUID().uuidString,
         type: String,
         title: String,
         body: String,
         instanceId: String,
         instanceName: String,
         threshold: Int? = nil,
         runtime: Int? = nil,
         timestamp: Date? = nil,
         time: String? = nil,
         formattedTime: String? = nil,
         createdAt: Date? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.instanceId = instanceId
        self.instanceName = instanceName
        self.threshold = threshold
        self.runtime = runtime
        self.timestamp = timestamp
        self.time = time
        self.formattedTime = formattedTime
        self.createdAt = createdAt
    }
} 