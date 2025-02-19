import Foundation

struct AWSConnection: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let accessKeyId: String
    let secretKey: String
    let region: String
    
    init(id: UUID = UUID(), name: String, accessKeyId: String, secretKey: String, region: String) {
        self.id = id
        self.name = name
        self.accessKeyId = accessKeyId
        self.secretKey = secretKey
        self.region = region
    }
}

// MARK: - Equatable
extension AWSConnection {
    static func == (lhs: AWSConnection, rhs: AWSConnection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Display Helpers
extension AWSConnection {
    var displayName: String {
        name.isEmpty ? "Unnamed Connection" : name
    }
    
    var shortId: String {
        String(id.uuidString.prefix(8))
    }
    
    var displayRegion: String {
        region.isEmpty ? "Unknown Region" : region
    }
} 