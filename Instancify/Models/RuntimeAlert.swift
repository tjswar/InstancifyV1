import Foundation

struct RuntimeAlert: Codable, Identifiable {
    var id: String
    var enabled: Bool
    var hours: Int
    var minutes: Int
    
    var totalMinutes: Int {
        return hours * 60 + minutes
    }
    
    init(id: String = UUID().uuidString, enabled: Bool = true, hours: Int = 2, minutes: Int = 0) {
        self.id = id
        self.enabled = enabled
        self.hours = hours
        self.minutes = minutes
    }
    
    static let example = RuntimeAlert(enabled: true, hours: 2, minutes: 30)
} 