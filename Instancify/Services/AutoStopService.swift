import Foundation
import BackgroundTasks
import UserNotifications
import FirebaseFirestore

@MainActor
class AutoStopService: ObservableObject {
    static let shared = AutoStopService()
    private let ec2Service = EC2Service.shared
    private let notificationManager = NotificationManager.shared
    
    // Background task identifier
    private let backgroundTaskIdentifier = "com.instancify.autostop"
    
    init() {
        setupBackgroundTask()
    }
    
    private func setupBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.processBackgroundTask(task as! BGProcessingTask)
        }
    }
    
    func processBackgroundTask(_ task: BGProcessingTask) {
        print("\n🔄 Processing background auto-stop task")
        
        // Set up expiration handler
        task.expirationHandler = {
            print("❌ Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Create a task for monitoring
        let monitoringTask = Task {
            do {
                let stoppedAny = try await stopScheduledInstances()
                
                // Schedule next check regardless of whether we stopped anything
                if let nextStopTime = getNextScheduledStopTime() {
                    scheduleBackgroundTask(for: nextStopTime)
                    print("✅ Scheduled next check for: \(nextStopTime)")
                }
                
                task.setTaskCompleted(success: stoppedAny)
            } catch {
                print("❌ Error in background task: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
        
        // Ensure the task is cancelled if we run out of time
        task.expirationHandler = {
            monitoringTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    private func stopScheduledInstances() async throws -> Bool {
        print("🔍 Checking for instances to stop...")
        var stoppedAny = false
        let defaults = UserDefaults.standard
        
        // Get all auto-stop keys
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("autoStop-") }
        
        for key in keys {
            guard let data = defaults.data(forKey: key),
                  let info = try? JSONDecoder().decode(AutoStopInfo.self, from: data) else {
                continue
            }
            
            if Date() >= info.scheduledTime {
                print("⏰ Stop time reached for instance: \(info.instanceId)")
                do {
                    try await ec2Service.stopInstance(info.instanceId, isAutoStop: true)
                    defaults.removeObject(forKey: key)
                    stoppedAny = true
                    
                    // Send success notification
                    notificationManager.sendNotification(
                        type: .instanceAutoStopped(
                            instanceId: info.instanceId,
                            name: info.instanceName
                        )
                    )
                    print("✅ Successfully stopped instance: \(info.instanceId)")
                } catch {
                    print("❌ Failed to stop instance \(info.instanceId): \(error)")
                }
            } else {
                print("⏳ Instance \(info.instanceId) not yet ready to stop. Scheduled for: \(info.scheduledTime)")
            }
        }
        
        return stoppedAny
    }
    
    private func scheduleBackgroundTask(for stopTime: Date) {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = stopTime
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            // Cancel any existing scheduled tasks first
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
            
            // Submit the new task
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background task scheduled for: \(stopTime)")
        } catch {
            print("❌ Could not schedule background task: \(error)")
        }
    }
    
    func scheduleAutoStop(for instance: EC2Instance, at time: Date) {
        print("\n⏰ Scheduling auto-stop for instance: \(instance.id)")
        let stopTime = time
        
        // Store auto-stop info
        let autoStopInfo = AutoStopInfo(
            instanceId: instance.id,
            scheduledTime: stopTime,
            instanceName: instance.name ?? instance.id
        )
        
        if let encoded = try? JSONEncoder().encode(autoStopInfo) {
            UserDefaults.standard.set(encoded, forKey: "autoStop-\(instance.id)")
            print("✅ Saved auto-stop info to UserDefaults")
        }
        
        // Schedule background task
        scheduleBackgroundTask(for: stopTime)
        
        // Schedule local notifications
        scheduleNotifications(for: instance, stopTime: stopTime)
        
        // Send confirmation notification
        notificationManager.sendNotification(
            type: .autoStopEnabled(
                instanceId: instance.id,
                name: instance.name ?? instance.id,
                stopTime: stopTime
            )
        )
        
        print("✅ Auto-stop scheduled for \(instance.name ?? instance.id) at \(stopTime)")
    }
    
    private func scheduleNotifications(for instance: EC2Instance, stopTime: Date) {
        // Schedule countdown notifications
        let countdowns = [3600, 1800, 900, 300, 60] // 1 hour, 30 min, 15 min, 5 min, 1 min
        
        for countdown in countdowns {
            let notificationTime = stopTime.addingTimeInterval(-Double(countdown))
            if notificationTime > Date() {
                // Create notification data
                let db = Firestore.firestore()
                let notificationRef = db.collection("notificationHistory").document()
                
                let firestoreData: [String: Any] = [
                    "timestamp": FieldValue.serverTimestamp(),
                    "type": "auto_stop_warning",
                    "title": "Auto-Stop Warning",
                    "body": "Instance '\(instance.name ?? instance.id)' will be stopped in \(formatTimeRemaining(countdown))",
                    "instanceId": instance.id,
                    "instanceName": instance.name ?? instance.id,
                    "region": instance.region,
                    "secondsRemaining": countdown,
                    "stopTime": Timestamp(date: stopTime),
                    "notificationTime": Timestamp(date: notificationTime),
                    "status": "pending"
                ]
                
                // Save to Firestore
                Task {
                    do {
                        try await notificationRef.setData(firestoreData)
                        print("✅ Auto-stop warning notification saved to history")
                        print("  • Type: auto_stop_warning")
                        print("  • Instance: \(instance.name ?? instance.id)")
                        print("  • Time remaining: \(formatTimeRemaining(countdown))")
                    } catch {
                        print("❌ Failed to save notification to history: \(error)")
                    }
                }
                
                // Send the notification
                notificationManager.sendNotification(
                    type: .autoStopWarning(
                        instanceId: instance.id,
                        name: instance.name ?? instance.id,
                        secondsRemaining: countdown
                    )
                )
            }
        }
        
        // Schedule final notification
        let content = UNMutableNotificationContent()
        content.title = "Instance Auto-Stopped"
        content.body = "Instance '\(instance.name ?? instance.id)' has been automatically stopped."
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: stopTime
            ),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "autoStop-final-\(instance.id)",
            content: content,
            trigger: trigger
        )
        
        // Save final notification to history
        let db = Firestore.firestore()
        let finalNotificationRef = db.collection("notificationHistory").document()
        
        let finalFirestoreData: [String: Any] = [
            "timestamp": FieldValue.serverTimestamp(),
            "type": "instance_auto_stopped",
            "title": content.title,
            "body": content.body,
            "instanceId": instance.id,
            "instanceName": instance.name ?? instance.id,
            "region": instance.region,
            "stopTime": Timestamp(date: stopTime),
            "notificationTime": Timestamp(date: stopTime),
            "status": "pending"
        ]
        
        Task {
            do {
                try await finalNotificationRef.setData(finalFirestoreData)
                print("✅ Final auto-stop notification saved to history")
                print("  • Type: instance_auto_stopped")
                print("  • Instance: \(instance.name ?? instance.id)")
            } catch {
                print("❌ Failed to save final notification to history: \(error)")
            }
        }
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func formatTimeRemaining(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else if seconds >= 60 {
            let minutes = seconds / 60
            return "\(minutes) minute\(minutes > 1 ? "s" : "")"
        } else {
            return "\(seconds) second\(seconds > 1 ? "s" : "")"
        }
    }
    
    private func getNextScheduledStopTime() -> Date? {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("autoStop-") }
        
        return keys.compactMap { key -> Date? in
            guard let data = defaults.data(forKey: key),
                  let info = try? JSONDecoder().decode(AutoStopInfo.self, from: data) else {
                return nil
            }
            return info.scheduledTime
        }.min()
    }
    
    func handleAutoStop(for instance: EC2Instance) async {
        do {
            print("\n🔄 Handling auto-stop for instance: \(instance.id)")
            print("  • Instance Name: \(instance.name ?? instance.id)")
            print("  • Region: \(instance.region)")
            
            // Use the instance's region instead of accessing EC2Service directly
            let region = instance.region
            
            // Save notification to history first
            let db = Firestore.firestore()
            let notificationRef = db.collection("notificationHistory").document()
            
            let firestoreData: [String: Any] = [
                "timestamp": FieldValue.serverTimestamp(),
                "type": "instance_auto_stopped",
                "title": "Instance Auto-Stopped",
                "body": "Instance '\(instance.name ?? instance.id)' has been automatically stopped",
                "instanceId": instance.id,
                "instanceName": instance.name ?? instance.id,
                "region": region,
                "notificationTime": Timestamp(date: Date()),
                "status": "completed"
            ]
            
            try await notificationRef.setData(firestoreData)
            print("✅ Auto-stop notification saved to history")
            
            // Send notification
            notificationManager.sendNotification(
                type: .instanceAutoStopped(
                    instanceId: instance.id,
                    name: instance.name ?? instance.id
                )
            )
            
            // Stop the instance
            try await ec2Service.stopInstance(instance.id, isAutoStop: true)
            
            // Clear auto-stop settings
            await ec2Service.cancelAutoStop(for: instance.id)
            
            print("✅ Auto-stop sequence completed for instance: \(instance.id)")
        } catch {
            print("❌ Failed to auto-stop instance: \(error.localizedDescription)")
        }
    }
}

private struct AutoStopInfo: Codable {
    let instanceId: String
    let scheduledTime: Date
    let instanceName: String
}