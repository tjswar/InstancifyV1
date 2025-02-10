import Foundation

struct NotificationHistoryItem: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let message: String
    let instanceId: String?
    let threshold: Int?
    let runtime: Int?
    
    // Alias for date to maintain compatibility
    var timestamp: Date {
        return date
    }
    
    // Alias for message to maintain compatibility
    var body: String {
        return message
    }
}

class NotificationHistoryManager {
    static let shared = NotificationHistoryManager()
    private let historyKey = "notificationHistory"
    private let maxHistoryCount = 100
    
    private init() {}
    
    func addToNotificationHistory(_ item: NotificationHistoryItem) async {
        var history = await getHistory()
        history.insert(item, at: 0)
        
        // Trim history if needed
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        await saveHistory(history)
    }
    
    private func getHistory() async -> [NotificationHistoryItem] {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([NotificationHistoryItem].self, from: data) {
            return history
        }
        return []
    }
    
    private func saveHistory(_ history: [NotificationHistoryItem]) async {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
} 