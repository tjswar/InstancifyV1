import Foundation
import UserNotifications

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    @Published var pendingNotifications: [(notification: NotificationType, timestamp: Date)] = []
    @Published private(set) var isAuthorized = false
    @Published var mutedInstanceIds: Set<String> = []
    
    private let cleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private var lastCleanupTime: Date?
    
    private override init() {
        super.init()
        Task {
            await setupNotificationCategories()
            await requestAuthorization()
            await loadNotifications()
            await cleanupOldNotifications()
            
            // Schedule periodic cleanup
            Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
                Task { [weak self] in
                    await self?.cleanupOldNotifications()
                }
            }
        }
    }
    
    private func setupNotificationCategories() async {
        let stopAction = UNNotificationAction(
            identifier: "STOP_INSTANCE",
            title: "Stop Instance",
            options: [.destructive]
        )
        
        let muteAction = UNNotificationAction(
            identifier: "MUTE_INSTANCE",
            title: "Mute Notifications",
            options: []
        )
        
        let instanceCategory = UNNotificationCategory(
            identifier: "INSTANCE_NOTIFICATION",
            actions: [stopAction, muteAction],
            intentIdentifiers: [],
            options: []
        )
        
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([instanceCategory])
    }
    
    private func requestAuthorization() async {
        do {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            
            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
                isAuthorized = granted
                
            case .authorized:
                isAuthorized = true
                
            case .denied:
                isAuthorized = false
                
            case .provisional, .ephemeral:
                isAuthorized = true
                
            @unknown default:
                isAuthorized = false
            }
        } catch {
            isAuthorized = false
        }
    }
    
    func sendNotification(type: NotificationType) {
        guard isAuthorized else { return }
        
        // Check if notifications are muted for this instance
        if let instanceId = type.instanceId, mutedInstanceIds.contains(instanceId) {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "INSTANCE_NOTIFICATION"
        content.userInfo = [
            "instanceId": type.instanceId ?? "",
            "timestamp": Date().timeIntervalSince1970,
            "type": String(describing: type)
        ]
        
        // Add to pending notifications with timestamp
        let timestamp = Date()
        pendingNotifications.insert((notification: type, timestamp: timestamp), at: 0)
        saveNotifications()
        
        let request = UNNotificationRequest(
            identifier: type.id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                HapticManager.notification(.success)
            } catch {
                // Remove from pending if failed to schedule
                pendingNotifications.removeAll { $0.notification.id == type.id }
                saveNotifications()
            }
        }
    }
    
    func muteInstance(_ instanceId: String) {
        mutedInstanceIds.insert(instanceId)
        // Remove any pending notifications for this instance
        pendingNotifications.removeAll { $0.notification.instanceId == instanceId }
        Task {
            let center = UNUserNotificationCenter.current()
            await center.removeDeliveredNotifications(withIdentifiers: pendingNotifications.filter { $0.notification.instanceId == instanceId }.map { $0.notification.id })
        }
    }
    
    func unmuteInstance(_ instanceId: String) {
        mutedInstanceIds.remove(instanceId)
    }
    
    private func cleanupOldNotifications() async {
        let now = Date()
        guard lastCleanupTime == nil || now.timeIntervalSince(lastCleanupTime!) >= cleanupInterval else {
            return
        }
        
        let twentyFourHoursAgo = now.addingTimeInterval(-cleanupInterval)
        pendingNotifications.removeAll { $0.timestamp < twentyFourHoursAgo }
        
        lastCleanupTime = now
        saveNotifications()
        
        // Also cleanup delivered notifications
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        let oldNotifications = delivered.filter { notification in
            if let timestamp = notification.request.content.userInfo["timestamp"] as? TimeInterval {
                return Date(timeIntervalSince1970: timestamp) < twentyFourHoursAgo
            }
            return false
        }
        
        if !oldNotifications.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: oldNotifications.map { $0.request.identifier })
        }
    }
    
    private func saveNotifications() {
        let notificationsData = pendingNotifications.map { (notification, timestamp) in
            NotificationData(notification: notification, timestamp: timestamp)
        }
        if let encoded = try? JSONEncoder().encode(notificationsData) {
            UserDefaults.standard.set(encoded, forKey: "PendingNotifications")
        }
    }
    
    private func loadNotifications() async {
        if let data = UserDefaults.standard.data(forKey: "PendingNotifications"),
           let decoded = try? JSONDecoder().decode([NotificationData].self, from: data) {
            pendingNotifications = decoded.map { ($0.notification, $0.timestamp) }
            // Cleanup old notifications right after loading
            await cleanupOldNotifications()
        }
    }
    
    func clearNotifications() {
        pendingNotifications.removeAll()
        saveNotifications()
        Task {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
        }
    }
    
    func removeNotification(at index: Int) {
        guard index < pendingNotifications.count else { return }
        let notification = pendingNotifications[index].notification
        pendingNotifications.remove(at: index)
        saveNotifications()
        
        Task {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [notification.id])
            center.removeDeliveredNotifications(withIdentifiers: [notification.id])
        }
    }
    
    func removePendingNotification(withIdentifier identifier: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("  🧹 Removed pending notification: \(identifier)")
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let instanceId = response.notification.request.content.userInfo["instanceId"] as? String ?? ""
        
        switch response.actionIdentifier {
        case "STOP_INSTANCE":
            if !instanceId.isEmpty {
                // Stop the instance
                Task {
                    do {
                        try await EC2Service.shared.stopInstance(instanceId)
                        print("✅ Instance \(instanceId) stopped via notification action")
                    } catch {
                        print("❌ Failed to stop instance: \(error.localizedDescription)")
                    }
                }
            }
            
        case "MUTE_INSTANCE":
            if !instanceId.isEmpty {
                muteInstance(instanceId)
                print("🔕 Muted notifications for instance \(instanceId)")
            }
            
        default:
            break
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
}

// Helper struct for encoding/decoding notifications with timestamps
private struct NotificationData: Codable {
    let notification: NotificationType
    let timestamp: Date
} 