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
} 