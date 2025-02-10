import Foundation

struct AWSConnection: Identifiable, Codable {
    let id = UUID()
    let name: String
    let accessKeyId: String
    let secretKey: String
    let region: String
    let lastSync: Date
    
    init(name: String, accessKeyId: String, secretKey: String, region: String, lastSync: Date = Date()) {
        self.name = name
        self.accessKeyId = accessKeyId
        self.secretKey = secretKey
        self.region = region
        self.lastSync = lastSync
    }
} 