import Foundation
import BackgroundTasks
import UserNotifications

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
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                let stoppedAny = try await stopScheduledInstances()
                task.setTaskCompleted(success: stoppedAny)
                
                if let nextStopTime = getNextScheduledStopTime() {
                    scheduleBackgroundTask(for: nextStopTime)
                }
            } catch {
                print("❌ Error in background task: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    func scheduleAutoStop(for instance: EC2Instance, at time: Date) {
        let stopTime = time
        
        // Store auto-stop info
        let autoStopInfo = AutoStopInfo(
            instanceId: instance.id,
            scheduledTime: stopTime,
            instanceName: instance.name ?? instance.id
        )
        
        if let encoded = try? JSONEncoder().encode(autoStopInfo) {
            UserDefaults.standard.set(encoded, forKey: "autoStop-\(instance.id)")
        }
        
        // Schedule background task
        scheduleBackgroundTask(for: stopTime)
        
        // Schedule local notifications
        scheduleNotifications(for: instance, stopTime: stopTime)
        
        // Send notification
        notificationManager.sendNotification(
            type: .autoStopEnabled(
                instanceId: instance.id,
                name: instance.name ?? instance.id,
                stopTime: stopTime
            )
        )
        
        print("🕒 Auto-stop scheduled for \(instance.name ?? instance.id) at \(stopTime)")
    }
    
    private func scheduleBackgroundTask(for stopTime: Date) {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = stopTime
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background task scheduled for \(stopTime)")
        } catch {
            print("❌ Could not schedule background task: \(error)")
        }
    }
    
    private func scheduleNotifications(for instance: EC2Instance, stopTime: Date) {
        // Schedule countdown notifications
        let countdowns = [3600, 1800, 900, 300, 60] // 1 hour, 30 min, 15 min, 5 min, 1 min
        
        for countdown in countdowns {
            let notificationTime = stopTime.addingTimeInterval(-Double(countdown))
            if notificationTime > Date() {
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
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func stopScheduledInstances() async throws -> Bool {
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
                } catch {
                    print("❌ Failed to auto-stop instance \(info.instanceId): \(error)")
                }
            }
        }
        
        return stoppedAny
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
            // Send notification before stopping
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