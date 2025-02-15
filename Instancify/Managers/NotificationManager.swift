import Foundation
import UIKit
import FirebaseMessaging
import UserNotifications

// Wrapper struct to make notifications codable
private struct NotificationEntry: Codable {
    let notification: NotificationType
    let timestamp: Date
}

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var pendingNotifications: [(notification: NotificationType, timestamp: Date)] = []
    @Published private(set) var isAuthorized = false
    @Published var mutedInstanceIds: Set<String> = []
    
    private let cleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let notificationService = FirebaseNotificationService.shared
    private var lastCleanupTime: Date?
    
    private init() {
        Task {
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
    
    private func requestAuthorization() async {
        do {
            let granted = try await notificationService.requestAuthorization()
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }
    
    private func loadNotifications() async {
        // Load notifications from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "pendingNotifications"),
           let entries = try? JSONDecoder().decode([NotificationEntry].self, from: data) {
            pendingNotifications = entries.map { ($0.notification, $0.timestamp) }
        }
    }
    
    private func cleanupOldNotifications() async {
        let now = Date()
        if let lastCleanup = lastCleanupTime,
           now.timeIntervalSince(lastCleanup) < cleanupInterval {
            return
        }
        
        pendingNotifications.removeAll { now.timeIntervalSince($0.timestamp) > cleanupInterval }
        lastCleanupTime = now
        
        // Save updated notifications
        saveNotifications()
    }
    
    func addNotification(_ notification: NotificationType) {
        pendingNotifications.append((notification, Date()))
        saveNotifications()
    }
    
    func removeNotification(at index: Int) {
        pendingNotifications.remove(at: index)
        saveNotifications()
    }
    
    func clearNotifications() {
        pendingNotifications.removeAll()
        saveNotifications()
    }
    
    private func saveNotifications() {
        let entries = pendingNotifications.map { NotificationEntry(notification: $0.notification, timestamp: $0.timestamp) }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "pendingNotifications")
        }
    }
    
    func muteInstance(_ instanceId: String) {
        mutedInstanceIds.insert(instanceId)
        UserDefaults.standard.set(Array(mutedInstanceIds), forKey: "mutedInstanceIds")
    }
    
    func unmuteInstance(_ instanceId: String) {
        mutedInstanceIds.remove(instanceId)
        UserDefaults.standard.set(Array(mutedInstanceIds), forKey: "mutedInstanceIds")
    }
    
    func isInstanceMuted(_ instanceId: String) -> Bool {
        mutedInstanceIds.contains(instanceId)
    }
    
    func sendNotification(type: NotificationType) {
        addNotification(type)
    }
    
    // Add instance state notification method
    func sendInstanceStateNotification(instanceId: String, instanceName: String?, state: InstanceState) async throws {
        let notification = NotificationType.instanceStateChanged(
            instanceId: instanceId,
            name: instanceName ?? instanceId,
            from: "unknown",
            to: state.rawValue
        )
        addNotification(notification)
    }
    
    func scheduleNotification(for instance: EC2Instance, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Instance Alert"
        content.body = "Your instance \(instance.id) will be stopped soon"
        content.sound = .default
        content.userInfo = [
            "instanceId": instance.id,
            "region": instance.region
        ]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "instance_alert_\(instance.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification scheduled for \(date)")
            }
        }
    }
} 