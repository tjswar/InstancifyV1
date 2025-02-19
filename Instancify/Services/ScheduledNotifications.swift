import UserNotifications

@MainActor
class ScheduledNotifications {
    static let shared = ScheduledNotifications()
    private let notificationSettings = NotificationSettingsViewModel.shared
    private let firebaseService = FirebaseNotificationService.shared
    
    private init() {}
    
    func scheduleRuntimeNotifications(instanceId: String, instanceName: String?, region: String, launchTime: Date) async {
        print("\n🔔 Starting runtime notification scheduling for instance \(instanceId)")
        print("📊 Instance Details:")
        print("  • Instance Name: \(instanceName ?? "unnamed")")
        print("  • Region: \(region)")
        print("  • Launch Time: \(launchTime)")
        
        // Verify if runtime alerts are enabled
        guard notificationSettings.runtimeAlertsEnabled else {
            print("❌ Runtime alerts are disabled in settings")
            return
        }
        
        // Calculate current runtime in minutes
        let currentRuntime = Int(Date().timeIntervalSince(launchTime) / 60)
        print("\n⏰ Runtime Analysis:")
        print("  • Current runtime: \(currentRuntime) minutes")
        
        // Get runtime alerts for this region
        let alerts = notificationSettings.getAlertsForRegion(region)
        
        print("\n📊 Alert Configuration Summary:")
        print("  • Total alerts found: \(alerts.count)")
        print("  • Global alerts: \(alerts.filter { $0.regions.isEmpty }.count)")
        print("  • Region-specific alerts: \(alerts.filter { !$0.regions.isEmpty }.count)")
        
        for alert in alerts {
            print("\n⚙️ Processing Alert Configuration:")
            print("  • Status: \(alert.enabled ? "Enabled" : "Disabled")")
            print("  • Threshold: \(alert.hours)h \(alert.minutes)m")
            print("  • Scope: \(alert.regions.isEmpty ? "Global" : "Region-specific")")
            
            guard alert.enabled else {
                print("  ⏭️ Skipping disabled alert")
                continue
            }
            
            let alertThreshold = alert.hours * 60 + alert.minutes
            print("\n📈 Threshold Analysis:")
            print("  • Alert threshold: \(alertThreshold) minutes")
            print("  • Current runtime: \(currentRuntime) minutes")
            
            if currentRuntime >= alertThreshold {
                print("  ⏭️ Skipping alert - runtime exceeds threshold")
                print("    • Runtime: \(currentRuntime)m")
                print("    • Threshold: \(alertThreshold)m")
                continue
            }
            
            // Calculate minutes until alert should trigger
            let minutesUntilAlert = alertThreshold - currentRuntime
            let triggerDate = Date().addingTimeInterval(TimeInterval(minutesUntilAlert * 60))
            
            print("\n⏰ Scheduling Details:")
            print("  • Minutes until alert: \(minutesUntilAlert)")
            print("  • Scheduled trigger time: \(triggerDate)")
            
            do {
                print("\n📱 Initiating alert scheduling...")
                // Schedule Firebase push notification
                try await firebaseService.scheduleRuntimeAlert(
                    instanceId: instanceId,
                    instanceName: instanceName ?? instanceId,
                    runtime: alertThreshold,
                    region: region,
                    triggerDate: triggerDate,
                    launchTime: launchTime
                )
                print("\n✅ Alert Successfully Scheduled:")
                print("  • Instance: \(instanceName ?? instanceId)")
                print("  • Threshold: \(alert.hours)h \(alert.minutes)m")
                print("  • Will trigger at: \(triggerDate)")
            } catch {
                print("\n❌ Alert Scheduling Failed:")
                print("  • Error: \(error.localizedDescription)")
            }
        }
        
        print("\n📋 Final Summary:")
        print("  • Total alerts processed: \(alerts.count)")
        print("  • Instance: \(instanceName ?? instanceId)")
        print("  • Region: \(region)")
        print("✅ Runtime notification scheduling completed")
    }
    
    func clearNotifications(instanceId: String, region: String? = nil) {
        print("\n🗑️ Clearing notifications")
        print("  • Instance: \(instanceId)")
        print("  • Region: \(region ?? "all")")
        
        Task {
            do {
                try await firebaseService.clearRuntimeAlerts(
                    instanceId: instanceId,
                    region: region
                )
                print("  ✅ Successfully cleared Firebase notifications")
            } catch {
                print("  ❌ Failed to clear Firebase notifications: \(error)")
            }
        }
    }
} 