import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    func scheduleInstanceStatusNotification(for instance: EC2Instance) {
        let content = UNMutableNotificationContent()
        content.title = "Instance Status Update"
        content.body = "\(instance.name ?? "Instance") is \(instance.state.rawValue)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "instance-\(instance.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleCostAlertNotification(for instance: EC2Instance, threshold: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Cost Alert"
        content.body = "\(instance.name ?? "Instance") cost has exceeded $\(String(format: "%.2f", threshold))"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "cost-\(instance.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func verifyNotificationSettings() async {
        print("🔍 Verifying notification settings")
        
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        print("📱 Notification authorization status: \(settings.authorizationStatus.rawValue)")
        
        switch settings.authorizationStatus {
        case .authorized:
            print("✅ Notifications are authorized")
        case .denied:
            print("❌ Notifications are denied - user must enable in Settings")
        case .notDetermined:
            print("⚠️ Notification permission not requested yet")
            await requestNotificationPermission()
        case .provisional:
            print("📝 Provisional notification permission granted")
        case .ephemeral:
            print("⏳ Ephemeral notification permission granted")
        @unknown default:
            print("❓ Unknown notification authorization status")
        }
        
        // Check scheduled notifications
        let scheduledNotifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
        print("📋 Currently scheduled notifications: \(scheduledNotifications.count)")
        
        for notification in scheduledNotifications {
            print("🔔 Scheduled notification: \(notification.identifier)")
            if let trigger = notification.trigger as? UNTimeIntervalNotificationTrigger {
                print("⏰ Next trigger date: \(Date(timeIntervalSinceNow: trigger.timeInterval))")
            }
        }
    }
    
    private func requestNotificationPermission() async {
        print("🔐 Requesting notification permission")
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
        } catch {
            print("❌ Failed to request notification permission: \(error)")
        }
    }
} 