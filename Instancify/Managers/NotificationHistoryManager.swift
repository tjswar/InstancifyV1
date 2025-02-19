import Foundation

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