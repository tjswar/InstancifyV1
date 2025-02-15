import Foundation
import FirebaseCore
import FirebaseMessaging
import AWSEC2

@MainActor
class ScheduledNotificationService: ObservableObject {
    static let shared = ScheduledNotificationService()
    
    private let notificationService = FirebaseNotificationService.shared
    private let defaults = UserDefaults(suiteName: "group.tech.md.Instancify")
    private var lastScheduleTime: [String: Date] = [:] // Region-based rate limiting
    private let minimumScheduleInterval: TimeInterval = 5 // 5 seconds between schedules per region
    
    private init() {}
    
    // Schedule runtime notifications for an instance
    func scheduleRuntimeNotifications(
        instanceId: String,
        instanceName: String?,
        region: String,
        launchTime: Date
    ) async {
        // Rate limiting check
        if let lastTime = lastScheduleTime[region],
           Date().timeIntervalSince(lastTime) < minimumScheduleInterval {
            return // Skip if too soon
        }
        
        print("\n🔔 Starting runtime notification scheduling for instance \(instanceId)")
        print("  • Instance Name: \(instanceName ?? "unnamed")")
        print("  • Region: \(region)")
        print("  • Launch Time: \(launchTime)")
        
        // Get runtime alerts from settings
        let settings = NotificationSettingsViewModel.shared
        guard settings.runtimeAlertsEnabled else {
            print("⚠️ Runtime alerts are disabled in settings")
            return
        }
        
        // Calculate current runtime in minutes
        let currentRuntime = Int(Date().timeIntervalSince(launchTime) / 60)
        print("  • Current runtime: \(currentRuntime) minutes")
        
        // Get all alerts (both global and region-specific)
        let allAlerts = settings.runtimeAlerts
        
        // Filter alerts that apply to this instance
        let applicableAlerts = allAlerts.filter { alert in
            alert.enabled && (alert.regions.isEmpty || alert.regions.contains(region))
        }
        
        print("\n📊 Alert Summary:")
        print("  • Total active alerts: \(applicableAlerts.count)")
        print("  • Global alerts: \(applicableAlerts.filter { $0.regions.isEmpty }.count)")
        print("  • Region-specific alerts: \(applicableAlerts.filter { !$0.regions.isEmpty }.count)")
        
        // Filter and prepare alerts for batch processing
        var alertsToSchedule: [RuntimeAlert] = []
        
        // Process alerts in order: global alerts first, then region-specific
        let sortedAlerts = applicableAlerts.sorted { a1, a2 in
            // If one is global and the other isn't, global comes first
            if a1.regions.isEmpty != a2.regions.isEmpty {
                return a1.regions.isEmpty
            }
            // Otherwise sort by threshold
            let t1 = a1.hours * 60 + a1.minutes
            let t2 = a2.hours * 60 + a2.minutes
            return t1 < t2
        }
        
        for alert in sortedAlerts {
            let alertThreshold = alert.hours * 60 + alert.minutes
            print("\n⚙️ Processing \(alert.regions.isEmpty ? "Global" : "Region") Alert:")
            print("  • Threshold: \(alert.hours)h \(alert.minutes)m")
            print("  • Is Global: \(alert.regions.isEmpty)")
            
            if currentRuntime >= alertThreshold {
                print("  ⏭️ Skipping - runtime exceeds threshold")
                continue
            }
            
            // Calculate trigger date
            let minutesUntilAlert = alertThreshold - currentRuntime
            let triggerDate = Date().addingTimeInterval(TimeInterval(minutesUntilAlert * 60))
            
            print("  • Will trigger in: \(minutesUntilAlert) minutes")
            print("  • Scheduled for: \(triggerDate)")
            
            alertsToSchedule.append(RuntimeAlert(
                instanceId: instanceId,
                instanceName: instanceName ?? instanceId,
                region: region,
                threshold: alertThreshold,
                launchTime: launchTime,
                scheduledTime: triggerDate,
                enabled: true,
                regions: alert.regions
            ))
        }
        
        // Batch schedule alerts
        if !alertsToSchedule.isEmpty {
            do {
                print("\n📤 Scheduling \(alertsToSchedule.count) alerts...")
                try await notificationService.batchScheduleRuntimeAlerts(alertsToSchedule)
                lastScheduleTime[region] = Date()
                print("✅ Successfully scheduled alerts")
            } catch {
                print("❌ Failed to schedule runtime alerts: \(error)")
            }
        } else {
            print("\n⚠️ No alerts to schedule")
        }
        
        print("\n✅ Completed runtime notification scheduling")
        print("----------------------------------------")
    }
    
    func clearRuntimeAlerts(instanceId: String, region: String? = nil) async {
        do {
            try await notificationService.clearInstanceAlerts(instanceId: instanceId, region: region)
        } catch {
            print("❌ Failed to clear runtime alerts: \(error)")
        }
    }
    
    // Clear notifications for an instance
    func clearNotifications(instanceId: String, region: String? = nil) {
        let key = "scheduled_notifications"
        guard var notifications = defaults?.dictionary(forKey: key) as? [String: [String: Any]] else {
            return
        }
        
        if let region = region {
            // Clear notifications for specific region
            let notificationKey = "\(region)_\(instanceId)"
            notifications.removeValue(forKey: notificationKey)
        } else {
            // Clear notifications for all regions
            notifications = notifications.filter { !$0.key.contains(instanceId) }
        }
        
        defaults?.set(notifications, forKey: key)
        defaults?.synchronize()
    }
    
    // Store a scheduled notification
    private func storeScheduledNotification(
        instanceId: String,
        region: String,
        threshold: Int,
        scheduledTime: Date
    ) {
        let key = "scheduled_notifications"
        var notifications = defaults?.dictionary(forKey: key) as? [String: [String: Any]] ?? [:]
        let notificationKey = "\(region)_\(instanceId)"
        
        let notification: [String: Any] = [
            "instanceId": instanceId,
            "region": region,
            "threshold": threshold,
            "scheduledTime": scheduledTime.timeIntervalSince1970
        ]
        
        notifications[notificationKey] = notification
        defaults?.set(notifications, forKey: key)
        defaults?.synchronize()
    }
    
    // Handle instance state changes with optimized scheduling
    func handleInstanceStateChange(
        instanceId: String,
        region: String,
        state: InstanceState
    ) {
        switch state {
        case .running:
            Task {
                do {
                    if let instance = try await EC2Service.shared.getInstanceDetails(instanceId, region: region),
                       let launchTime = instance.launchTime {
                        await scheduleRuntimeNotifications(
                            instanceId: instanceId,
                            instanceName: instance.name,
                            region: region,
                            launchTime: launchTime
                        )
                    }
                } catch {
                    print("❌ Failed to get instance details: \(error)")
                }
            }
            
        case .stopped, .terminated:
            Task {
                await clearRuntimeAlerts(instanceId: instanceId, region: region)
                clearNotifications(instanceId: instanceId, region: region)
            }
            
        default:
            break
        }
    }
} 