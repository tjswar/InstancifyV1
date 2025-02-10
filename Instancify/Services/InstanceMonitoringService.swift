import Foundation
import Combine
import AWSEC2
import AWSCloudWatch
import UserNotifications
import BackgroundTasks
import UIKit

@MainActor
class InstanceMonitoringService: ObservableObject {
    static let shared = InstanceMonitoringService()
    private let notificationManager = NotificationManager.shared
    private let ec2Service = EC2Service.shared
    private let defaults: UserDefaults?
    
    // Lazy load notification settings to prevent initialization deadlock
    private lazy var notificationSettings: NotificationSettingsViewModel = {
        NotificationSettingsViewModel.shared
    }()
    
    @Published private(set) var notificationHistory: [NotificationHistoryItem] = []
    private let maxHistoryItems = 100 // Keep last 100 notifications
    
    @Published private(set) var isMonitoring = false
    private var monitoringTask: Task<Void, Never>?
    private var instances: [EC2Instance] = []
    private var notifiedThresholds: [String: [String: Set<Int>]] = [:]
    private var currentRegion: String = "us-east-1" // Default region
    private var isInitialized = false
    
    private init() {
        if let bundleId = Bundle.main.bundleIdentifier {
            let appGroupId = "group.\(bundleId)"
            defaults = UserDefaults(suiteName: appGroupId)
        } else {
            defaults = nil
        }
        
        isMonitoring = defaults?.bool(forKey: "isMonitoring") ?? false
    }
    
    func initialize() async {
        guard !isInitialized else { return }
        
        await loadNotificationHistory()
        await loadNotifiedThresholds()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRuntimeAlertsChanged),
            name: NSNotification.Name("RuntimeAlertsChanged"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRegionChange(_:)),
            name: NSNotification.Name("RegionChanged"),
            object: nil
        )
        
        if notificationSettings.runtimeAlertsEnabled {
            await startMonitoring()
        }
        
        isInitialized = true
    }
    
    @objc private func handleRegionChange(_ notification: Notification) {
        if let newRegion = notification.object as? String {
            currentRegion = newRegion
            
            Task {
                await resetAllNotificationState()
                await clearScheduledNotifications()
                
                if notificationSettings.runtimeAlertsEnabled {
                    await startMonitoring()
                }
            }
        }
    }
    
    @objc private func handleRuntimeAlertsChanged() {
        Task {
            await resetAllNotificationState()
            
            if notificationSettings.runtimeAlertsEnabled {
                if !isMonitoring {
                    await restartMonitoring()
                } else {
                    await checkAllRegions()
                }
            } else {
                stopMonitoring()
            }
        }
    }
    
    private func restartMonitoring() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        
        isMonitoring = true
        monitoringTask?.cancel()
        
        monitoringTask = Task {
            if !Task.isCancelled {
                await checkAllRegions()
            }
            
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 120_000_000_000) // 2 minutes
                    if !Task.isCancelled {
                        await checkAllRegions()
                    }
                } catch {
                    if !Task.isCancelled {
                        break
                    }
                }
            }
        }
    }
    
    func startMonitoring() async {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringTask = Task {
            while !Task.isCancelled {
                await checkAllRegions()
                try? await Task.sleep(nanoseconds: 60 * NSEC_PER_SEC)
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        
        Task {
            await resetAllNotificationState()
        }
    }
    
    func checkAllRegions() async {
        guard notificationSettings.runtimeAlertsEnabled else { return }
        
        guard let credentials = try? AuthenticationManager.shared.getAWSCredentials() else { return }
        
        let originalRegion = currentRegion
        var allInstances: [EC2Instance] = []
        let regions = AWSRegion.allCases
        
        for region in regions {
            do {
                currentRegion = region.rawValue
                
                EC2Service.shared.updateConfiguration(
                    with: credentials,
                    region: region.toAWSRegionType()
                )
                
                let instances = try await ec2Service.fetchInstances()
                allInstances.append(contentsOf: instances)
                await checkInstances(instances, in: region.rawValue)
            } catch {
                continue
            }
        }
        
        // Restore original region and configuration
        currentRegion = originalRegion
        EC2Service.shared.updateConfiguration(
            with: credentials,
            region: AWSRegion(rawValue: originalRegion)?.toAWSRegionType() ?? .USEast1
        )
        
        // Update total instances
        self.instances = allInstances
    }
    
    func checkInstances(_ instances: [EC2Instance], in region: String) async {
        let runningInstances = instances.filter { $0.state == .running }
        
        for instance in runningInstances {
            await checkRuntimeAlerts(for: instance, in: region)
        }
        
        print("\n📊 Current Notification State for \(region):")
        print(notifiedThresholds[region] ?? [:])
    }
    
    private func checkRuntimeAlerts(for instance: EC2Instance, in region: String) async {
        guard let launchTime = instance.launchTime else { return }
        
        let runtime = Int(Date().timeIntervalSince(launchTime))
        let enabledAlerts = notificationSettings.runtimeAlerts
            .filter { $0.enabled }
            .map { $0.hours * 3600 + $0.minutes * 60 }
            .sorted()
        
        print("\n⏰ Runtime Check for \(instance.name ?? instance.id):")
        print("  • Launch time: \(launchTime)")
        print("  • Current time: \(Date())")
        print("  • Current runtime: \(formatRuntime(runtime))")
        print("  • Enabled alerts: \(enabledAlerts.map { formatRuntime($0) }.joined(separator: ", "))")
        
        // Initialize region and instance thresholds if needed
        if notifiedThresholds[region] == nil {
            notifiedThresholds[region] = [:]
        }
        if notifiedThresholds[region]?[instance.id] == nil {
            notifiedThresholds[region]?[instance.id] = Set<Int>()
        }
        
        print("  • Previously notified thresholds: \(notifiedThresholds[region]?[instance.id] ?? [])")
        
        for threshold in enabledAlerts {
            print("\n  📊 Checking threshold: \(formatRuntime(threshold))")
            print("    • Current runtime: \(formatRuntime(runtime))")
            
            if runtime >= threshold {
                if !(notifiedThresholds[region]?[instance.id]?.contains(threshold) ?? false) {
                    // Send notification
                    let notification = NotificationType.runtimeAlert(
                        instanceId: instance.id,
                        instanceName: instance.name ?? instance.id,
                        runtime: runtime,
                        threshold: threshold
                    )
                    notificationManager.sendNotification(type: notification)
                    
                    // Mark threshold as notified in instance's actual region
                    notifiedThresholds[region]?[instance.id]?.insert(threshold)
                    saveNotifiedThresholds()
                }
            } else {
                let timeUntil = threshold - runtime
                print("    ⏳ Time until threshold: \(formatRuntime(timeUntil))")
            }
        }
    }
    
    private func addToHistory(_ item: NotificationHistoryItem) {
        var currentHistory = notificationHistory
        currentHistory.insert(item, at: 0)
        
        if currentHistory.count > maxHistoryItems {
            currentHistory = Array(currentHistory.prefix(maxHistoryItems))
        }
        
        notificationHistory = currentHistory
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(currentHistory) {
            defaults?.set(data, forKey: "NotificationHistory")
        }
    }
    
    private func cleanupOldNotifications() async {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        notificationHistory = notificationHistory.filter { $0.date > oneDayAgo }
        
        // Save cleaned up history
        if let encoded = try? JSONEncoder().encode(notificationHistory) {
            defaults?.set(encoded, forKey: "NotificationHistory")
            defaults?.synchronize()
        }
    }
    
    private func sendThresholdNotification(for instance: EC2Instance, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Runtime Alert"
        content.body = "\(instance.name ?? instance.id) has been running for \(formatRuntime(instance.runtime))"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "INSTANCE_NOTIFICATION"
        content.userInfo = ["instanceId": instance.id]
        
        let request = UNNotificationRequest(
            identifier: "runtime-\(instance.id)-\(threshold)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ Runtime notification scheduled for instance \(instance.id)")
                
                // Add to notification history
                let historyItem = NotificationHistoryItem(
                    date: Date(),
                    title: content.title,
                    message: content.body,
                    instanceId: instance.id,
                    threshold: threshold,
                    runtime: instance.runtime
                )
                await addToNotificationHistory(historyItem)
            } catch {
                print("❌ Failed to schedule runtime notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func hasNotifiedThreshold(for instanceId: String, threshold: Int) -> Bool {
        let regionThresholds = notifiedThresholds[currentRegion] ?? [:]
        let instanceThresholds = regionThresholds[instanceId] ?? Set<Int>()
        return instanceThresholds.contains(threshold)
    }
    
    private func markThresholdNotified(for instanceId: String, threshold: Int) {
        if notifiedThresholds[currentRegion] == nil {
            notifiedThresholds[currentRegion] = [:]
        }
        if notifiedThresholds[currentRegion]?[instanceId] == nil {
            notifiedThresholds[currentRegion]?[instanceId] = Set<Int>()
        }
        notifiedThresholds[currentRegion]?[instanceId]?.insert(threshold)
        saveNotifiedThresholds()
        print("✅ Marked threshold \(threshold) as notified for \(instanceId) in region \(currentRegion)")
    }
    
    private func resetThresholds(for instanceId: String) {
        print("\n🔄 Resetting thresholds for instance \(instanceId) in region \(currentRegion)...")
        
        // Only reset if instance is actually stopped
        guard let instance = instances.first(where: { $0.id == instanceId }) else {
            print("  ❌ Instance not found")
            return
        }
        
        guard instance.state == .stopped else {
            print("  ⚠️ Not resetting thresholds - instance is not stopped (current state: \(instance.state.rawValue))")
            return
        }
        
        // Clear thresholds for this instance in the current region
        notifiedThresholds[currentRegion]?[instanceId]?.removeAll()
        saveNotifiedThresholds()
        print("  ✅ Thresholds reset successfully")
    }
    
    private func saveNotifiedThresholds() {
        print("\n💾 Saving notified thresholds...")
        // Convert Set to Array for UserDefaults storage
        var thresholdsToSave: [String: [String: [Int]]] = [:]
        for (region, instanceThresholds) in notifiedThresholds {
            thresholdsToSave[region] = [:]
            for (instanceId, thresholds) in instanceThresholds {
                thresholdsToSave[region]?[instanceId] = Array(thresholds)
            }
        }
        defaults?.set(thresholdsToSave, forKey: "NotifiedThresholds")
        defaults?.synchronize()
        
        // Print current state
        print("  📊 Current state by region:")
        for (region, instanceThresholds) in notifiedThresholds {
            print("  • Region: \(region)")
            for (instanceId, thresholds) in instanceThresholds {
                let instanceName = instances.first(where: { $0.id == instanceId })?.name ?? instanceId
                print("    - \(instanceName): \(thresholds.sorted().map { "\($0)m" }.joined(separator: ", "))")
            }
        }
    }
    
    private func clearScheduledNotifications() async {
        print("\n🧹 Clearing scheduled notifications...")
        let center = UNUserNotificationCenter.current()
        
        // Get all pending notifications
        let pendingRequests = await center.pendingNotificationRequests()
        let thresholdNotifications = pendingRequests.filter { 
            $0.identifier.starts(with: "threshold-")
        }
        
        if !thresholdNotifications.isEmpty {
            print("  • Removing \(thresholdNotifications.count) threshold notifications")
            center.removePendingNotificationRequests(withIdentifiers: thresholdNotifications.map { $0.identifier })
        }
        
        // Also clear delivered notifications
        let deliveredNotifications = await center.deliveredNotifications()
        let thresholdDelivered = deliveredNotifications.filter {
            $0.request.identifier.starts(with: "threshold-")
        }
        
        if !thresholdDelivered.isEmpty {
            print("  • Removing \(thresholdDelivered.count) delivered notifications")
            center.removeDeliveredNotifications(withIdentifiers: thresholdDelivered.map { $0.request.identifier })
        }
        
        // Reset badge count
        await setBadgeCount(0)
        
        print("✅ Notifications cleared")
    }
    
    private func formatRuntime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
    
    private func scheduleThresholdNotification(for instance: EC2Instance, threshold: Int, timeInterval: TimeInterval) async {
        print("\n📅 Scheduling threshold notification...")
        print("  • Instance: \(instance.name ?? instance.id)")
        print("  • Threshold: \(threshold)m")
        
        // Calculate exact trigger time using Calendar
        let calendar = Calendar.current
        let triggerDate = calendar.date(byAdding: .second, value: Int(timeInterval), to: Date()) ?? Date()
        let components = calendar.dateComponents([.hour, .minute], from: Date(), to: triggerDate)
        let formattedTime = String(format: "%dh %dm", components.hour ?? 0, components.minute ?? 0)
        print("  • Will trigger in: \(formattedTime)")
        
        // Check authorization status before proceeding
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            print("  ❌ Notification authorization not granted")
            return
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Runtime Alert"
        content.body = "\(instance.name ?? instance.id) has been running for \(threshold) minutes"
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "threshold-\(instance.id)"
        content.userInfo = [
            "instanceId": instance.id,
            "threshold": threshold,
            "scheduledAt": Date().timeIntervalSince1970
        ]
        
        // Create trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // Create unique identifier
        let identifier = "threshold-\(instance.id)-\(threshold)-scheduled"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            // Remove any existing scheduled notifications for this threshold
            let center = UNUserNotificationCenter.current()
            let pendingRequests = await center.pendingNotificationRequests()
            let existingIdentifiers = pendingRequests
                .filter { $0.identifier == identifier }
                .map { $0.identifier }
            
            if !existingIdentifiers.isEmpty {
                print("  🧹 Removing existing scheduled notification")
                center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)
            }
            
            // Schedule new notification
            try await center.add(request)
            print("  ✅ Notification scheduled successfully")
            
            // Verify scheduled notifications
            let updatedPending = await center.pendingNotificationRequests()
            print("\n  📊 Verification:")
            print("    • Pending notifications: \(updatedPending.count)")
            print("    • Scheduled trigger time: \(Date(timeIntervalSinceNow: timeInterval))")
            
        } catch {
            print("  ❌ Failed to schedule notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func resetRuntimeAlerts(for instanceId: String) {
        print("\n🔄 Resetting runtime alerts for instance \(instanceId)")
        let notifiedKey = "notified-thresholds-\(instanceId)"
        defaults?.removeObject(forKey: notifiedKey)
        defaults?.synchronize()
        print("✅ Runtime alerts reset")
    }
    
    private func setupNotificationCategories() async {
        let stopAction = UNNotificationAction(
            identifier: "STOP_INSTANCE",
            title: "Stop Instance",
            options: [.destructive]
        )
        
        let runtimeCategory = UNNotificationCategory(
            identifier: "RUNTIME_ALERT",
            actions: [stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([runtimeCategory])
        print("✅ Notification categories configured")
    }
    
    // Set badge count using new API
    private func setBadgeCount(_ count: Int) async {
        do {
            let center = UNUserNotificationCenter.current()
            try await center.setBadgeCount(count)
        } catch {
            print("❌ Failed to set badge count: \(error)")
        }
    }
    
    private func resetAllNotificationState() async {
        print("\n🧹 Clearing all notification state...")
        
        // Only clear pending notifications, not delivered ones
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        // Reset badge count
        await setBadgeCount(0)
        
        // Don't clear notified thresholds, just ensure we have entries for all regions
        for region in notifiedThresholds.keys {
            if notifiedThresholds[region] == nil {
                notifiedThresholds[region] = [:]
            }
        }
        
        print("✅ Notification state reset")
    }
    
    private func loadNotificationHistory() async {
        if let historyData = defaults?.data(forKey: "NotificationHistory"),
           let history = try? JSONDecoder().decode([NotificationHistoryItem].self, from: historyData) {
            notificationHistory = history
            print("✅ Loaded \(notificationHistory.count) notification history items")
        } else {
            print("❌ Failed to load notification history")
        }
    }
    
    private func resetNotificationsForInstance(_ instanceId: String, inRegion region: String) async {
        print("\n🧹 Clearing notifications for instance \(instanceId) in region \(region)...")
        
        // Clear thresholds for this instance in the specified region
        notifiedThresholds[region]?[instanceId]?.removeAll()
        saveNotifiedThresholds()
        
        // Clear any pending notifications for this instance in this region
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        let instanceRequests = pendingRequests.filter { 
            $0.identifier.contains(instanceId) && $0.identifier.contains(region)
        }
        center.removePendingNotificationRequests(withIdentifiers: instanceRequests.map { $0.identifier })
        
        print("✅ Notifications cleared for instance \(instanceId) in region \(region)")
    }
    
    private func handleInstanceStarted(instance: EC2Instance) async {
        // Send notification
        let notification = NotificationType.instanceStarted(
            instanceId: instance.id,
            name: instance.name ?? instance.id
        )
        notificationManager.sendNotification(type: notification)
        
        // Reset notifications for this instance
        await resetNotificationsForInstance(instance.id, inRegion: instance.region)
    }
    
    private func handleInstanceStopped(instance: EC2Instance) async {
        // Send notification
        let notification = NotificationType.instanceStopped(
            instanceId: instance.id,
            name: instance.name ?? instance.id
        )
        notificationManager.sendNotification(type: notification)
        
        // Reset notifications for this instance
        await resetNotificationsForInstance(instance.id, inRegion: instance.region)
    }
    
    private func loadNotifiedThresholds() async {
        if let data = defaults?.data(forKey: "NotifiedThresholds"),
           let decoded = try? JSONDecoder().decode([String: [String: Set<Int>]].self, from: data) {
            notifiedThresholds = decoded
            print("✅ Loaded notified thresholds")
        } else {
            print("❌ Failed to load notified thresholds")
        }
    }
    
    private func addToNotificationHistory(_ item: NotificationHistoryItem) async {
        var history = notificationHistory
        history.insert(item, at: 0)
        
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        
        notificationHistory = history
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(history) {
            defaults?.set(data, forKey: "NotificationHistory")
        }
    }
} 