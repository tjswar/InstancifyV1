import UIKit
import SwiftUI
import UserNotifications
import BackgroundTasks
import FirebaseCore
import FirebaseMessaging
import AWSCore
import AWSEC2

// Remove the AWSConnection struct declaration here
// Use the existing one from Models/AWSConnection.swift

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = AppDelegate()
    private var isBackgroundTaskScheduled = false
    private var backgroundTimer: Timer?
    private let appGroup = "group.tech.md.Instancify"
    private var activeRegions: Set<String> = []
    
    func initializeAWS() {
        print("\n🌐 Initializing AWS SDK")
        
        do {
            let credentials = try KeychainManager.shared.retrieveCredentials()
            let region = try KeychainManager.shared.getRegion()
            
            let credentialsProvider = AWSStaticCredentialsProvider(
                accessKey: credentials.accessKeyId,
                secretKey: credentials.secretAccessKey
            )
            
            let configuration = AWSServiceConfiguration(
                region: mapRegionToAWSType(region),
                credentialsProvider: credentialsProvider
            )
            AWSServiceManager.default().defaultServiceConfiguration = configuration
            print("✅ AWS SDK configured with stored credentials")
        } catch {
            print("⚠️ Failed to load credentials: \(error)")
            // Handle unauthenticated state
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("\n🚀 Application did finish launching")
        
        // Initialize Firebase first
        FirebaseApp.configure()
        
        // Set messaging delegate
        Messaging.messaging().delegate = self
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions first
        Task {
            do {
                let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)
                
                await MainActor.run {
                    if granted {
                        print("✅ Notification permissions granted")
                        // Register for remote notifications after permissions are granted
                        UIApplication.shared.registerForRemoteNotifications()
                    } else {
                        print("⚠️ Notification permissions denied")
                    }
                }
            } catch {
                print("❌ Failed to request notification permissions: \(error)")
            }
        }
        
        // Initialize notification settings
        _ = NotificationSettingsViewModel.shared
        
        // Initialize AWS and related services
        Task { @MainActor in
            do {
                // Initialize AuthManager
                print("🔐 Initializing AuthManager...")
                _ = AuthenticationManager.shared
                
                // Initialize AWS with credentials from keychain
                let credentials = try KeychainManager.shared.retrieveCredentials()
                let region = try KeychainManager.shared.getRegion()
                
                print("🔑 Found credentials in keychain")
                let credentialsProvider = AWSStaticCredentialsProvider(
                    accessKey: credentials.accessKeyId,
                    secretKey: credentials.secretAccessKey
                )
                
                let configuration = AWSServiceConfiguration(
                    region: mapRegionToAWSType(region),
                    credentialsProvider: credentialsProvider
                )
                
                // Set the default configuration
                AWSServiceManager.default().defaultServiceConfiguration = configuration
                print("✅ AWS SDK configured with stored credentials")
                
                // Initialize AWS Configuration Service
                try AWSConfigurationService.shared.configure()
                print("✅ AWS Configuration Service initialized")
                
                // Initialize monitoring service
                print("🔄 Initializing monitoring service...")
                try await InstanceMonitoringService.shared.initialize()
                
                // Setup notifications after initialization
                await FirebaseNotificationService.shared.setupNotifications()
                
                print("✅ All services initialized successfully")
            } catch AWSError.noCredentialsFound {
                print("⚠️ No AWS credentials found in keychain - skipping service initialization")
            } catch AWSError.invalidCredentials {
                print("⚠️ Invalid AWS credentials in keychain - skipping service initialization")
            } catch AWSError.configurationFailed {
                print("⚠️ AWS configuration failed - skipping service initialization")
            } catch {
                print("❌ Failed to initialize services: \(error)")
            }
        }
        
        return true
    }

    // MARK: - Background Task Registration
    private func registerBackgroundTasks() {
        print("\n⏰ Registering background tasks...")
        
        // Register refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "tech.md.Instancify.refresh",
            using: nil
        ) { task in
            print("🔄 Background refresh task started")
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
        print("✅ Registered refresh task")
        
        // Register immediate check task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "tech.md.Instancify.immediate-check",
            using: nil
        ) { task in
            print("🔄 Immediate check task started")
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
        print("✅ Registered immediate check task")
        
        // Register periodic check task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "tech.md.Instancify.periodic-check",
            using: nil
        ) { task in
            print("🔄 Periodic check task started")
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
        print("✅ Registered periodic check task")
        
        print("✅ All background tasks registered successfully")
    }

    // MARK: - Background Task Handling
    private func handleBackgroundTask(_ task: BGTask) {
        let backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            print("⚠️ Background task expiring")
        }
        
        Task {
            let defaults = UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
            
            // Get runtime alerts from NotificationSettings
            var runtimeAlerts: [Int] = []
            
            // Get alerts from NotificationSettingsViewModel
            if let data = defaults.data(forKey: "runtimeAlerts"),
               let alerts = try? JSONDecoder().decode([RuntimeAlert].self, from: data) {
                runtimeAlerts = alerts
                    .filter { $0.enabled }
                    .map { $0.hours * 60 + $0.minutes }
                    .sorted()
            }
            
            guard !runtimeAlerts.isEmpty else {
                print("ℹ️ No runtime alerts configured")
                task.setTaskCompleted(success: true)
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                return
            }
            
            print("🔔 Checking instances with thresholds: \(runtimeAlerts)")
            await checkAllRegions(thresholds: Set(runtimeAlerts))
            
            task.setTaskCompleted(success: true)
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            await scheduleBackgroundTasks()
        }
    }

    // MARK: - Instance Monitoring Core Logic
    private func checkAllRegions(thresholds: Set<Int>) async {
        let currentCredentials = AWSManager.shared.currentConnectionDetails
        let originalRegion = currentCredentials?.region ?? "us-east-1"
        
        // Get all enabled runtime alert thresholds from the NotificationSettingsViewModel
        let defaults = UserDefaults(suiteName: appGroup)
        var enabledThresholds: Set<Int> = []
        if let data = defaults?.data(forKey: "runtimeAlerts"),
           let alerts = try? JSONDecoder().decode([RuntimeAlert].self, from: data) {
            enabledThresholds = Set(alerts
                .filter { $0.enabled }
                .map { $0.hours * 60 + $0.minutes })
        }
        
        guard !enabledThresholds.isEmpty else {
            print("ℹ️ No runtime alerts enabled")
            return
        }
        
        // Store original configuration
        guard let originalConfig = AWSServiceManager.default().defaultServiceConfiguration else {
            print("❌ No AWS configuration found")
            return
        }
        
        // Process each region independently
        for region in AWSRegion.allCases {
            print("🌎 Processing region: \(region.rawValue)")
            
            do {
                // Configure AWS for this region
                guard let credentials = currentCredentials else {
                    print("❌ No credentials available")
                    continue
                }
                
                let regionConfig = AWSServiceConfiguration(
                    region: mapRegionToAWSType(region.rawValue),
                    credentialsProvider: AWSStaticCredentialsProvider(
                        accessKey: credentials.accessKeyId,
                        secretKey: credentials.secretKey
                    )
                )!
                
                // Register EC2 service with this configuration
                let serviceKey = "MonitoringService-\(region.rawValue)"
                AWSEC2.register(with: regionConfig, forKey: serviceKey)
                
                // Create EC2 client with the registered configuration
                let monitoringEC2Service = AWSEC2(forKey: serviceKey)
                
                // Fetch instances in this region
                let request = AWSEC2DescribeInstancesRequest()!
                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AWSEC2DescribeInstancesResult, Error>) in
                    monitoringEC2Service.describeInstances(request) { response, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let response = response {
                            continuation.resume(returning: response)
                        } else {
                            continuation.resume(throwing: NSError(domain: "EC2Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response from AWS"]))
                        }
                    }
                }
                
                guard let reservations = result.reservations else { continue }
                
                // Process instances in this region
                for reservation in reservations {
                    guard let instances = reservation.instances else { continue }
                    
                    for instance in instances {
                        guard let instanceId = instance.instanceId,
                              let state = instance.state,
                              state.name == .running,
                              let launchTime = instance.launchTime else { continue }
                        
                        // Get instance name from tags
                        let name = instance.tags?.first(where: { $0.key == "Name" })?.value ?? instanceId
                        
                        // Process runtime alerts for each enabled threshold
                        for threshold in enabledThresholds {
                            await FirebaseNotificationService.shared.handleInstanceRuntimeAlert(
                                instanceId: instanceId,
                                region: region.rawValue,
                                name: name,
                                launchTime: launchTime,
                                runtimeThreshold: threshold,
                                instanceState: "running"
                            )
                        }
                    }
                }
            } catch {
                print("❌ Failed to process region \(region.rawValue): \(error.localizedDescription)")
            }
        }
        
        // Restore original configuration
        AWSServiceManager.default().defaultServiceConfiguration = originalConfig
    }

    // MARK: - AWS Region Helper
    private func mapRegionToAWSType(_ region: String) -> AWSRegionType {
        switch region {
            case "us-east-1": return .USEast1
            case "us-east-2": return .USEast2
            case "us-west-1": return .USWest1
            case "us-west-2": return .USWest2
            case "eu-west-1": return .EUWest1
            case "eu-west-2": return .EUWest2
            case "eu-central-1": return .EUCentral1
            case "ap-southeast-1": return .APSoutheast1
            case "ap-southeast-2": return .APSoutheast2
            case "ap-northeast-1": return .APNortheast1
            case "ap-northeast-2": return .APNortheast2
            case "sa-east-1": return .SAEast1
            default: return .USEast1
        }
    }

    // MARK: - AWS Configuration Helper
    private func configureAWS(region: String, credentials: AWSConnection) {
        // Map region string to AWSRegionType
        let regionType: AWSRegionType
        switch region {
            case "us-east-1": regionType = .USEast1
            case "us-east-2": regionType = .USEast2
            case "us-west-1": regionType = .USWest1
            case "us-west-2": regionType = .USWest2
            case "eu-west-1": regionType = .EUWest1
            case "eu-west-2": regionType = .EUWest2
            case "eu-central-1": regionType = .EUCentral1
            case "ap-southeast-1": regionType = .APSoutheast1
            case "ap-southeast-2": regionType = .APSoutheast2
            case "ap-northeast-1": regionType = .APNortheast1
            case "ap-northeast-2": regionType = .APNortheast2
            case "sa-east-1": regionType = .SAEast1
            default: regionType = .USEast1
        }
        
        let config = AWSServiceConfiguration(
            region: regionType,
            credentialsProvider: AWSStaticCredentialsProvider(
                accessKey: credentials.accessKeyId,
                secretKey: credentials.secretKey
            )
        )
        
        AWSServiceManager.default().defaultServiceConfiguration = config
        print("✅ AWS configured for region: \(region)")
    }

    // MARK: - Background Timer (Fixed)
    private func startBackgroundTimer() {
        stopBackgroundTimer()
        
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                print("\n⏰ Background timer fired (2-minute interval)")
                let defaults = UserDefaults(suiteName: self.appGroup) ?? UserDefaults.standard
                
                // Get runtime alerts from NotificationSettings
                var runtimeAlerts: [Int] = []
                
                // First try to get from NotificationSettings
                if let settings = defaults.dictionary(forKey: "NotificationSettings") as? [String: Bool] {
                    print("📝 Found notification settings: \(settings)")
                    runtimeAlerts = self.parseRuntimeAlerts(from: settings)
                }
                
                // If no alerts found, try getting from notified-thresholds
                if runtimeAlerts.isEmpty {
                    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("notified-thresholds-") {
                        if let thresholds = defaults.array(forKey: key) as? [Int] {
                            runtimeAlerts.append(contentsOf: thresholds)
                        }
                    }
                }
                
                guard !runtimeAlerts.isEmpty else {
                    print("ℹ️ No runtime alerts configured in UserDefaults")
                    print("📦 Current UserDefaults: \(defaults.dictionaryRepresentation())")
                    return
                }
                
                let uniqueThresholds = Set(runtimeAlerts)
                print("🔔 Starting check with thresholds: \(Array(uniqueThresholds).sorted())")
                await self.checkAllRegions(thresholds: uniqueThresholds)
                await self.scheduleBackgroundTasks()
            }
        }
        backgroundTimer?.tolerance = 5
        print("🕒 Started background timer")
    }

    // MARK: - Background Task Scheduling (Updated)
    func scheduleBackgroundTasks() async {
        print("\n📅 Scheduling background tasks...")
        BGTaskScheduler.shared.cancelAllTaskRequests()
        
        // Schedule immediate check (5 minutes)
        let immediateRequest = BGAppRefreshTaskRequest(identifier: "tech.md.Instancify.immediate-check")
        immediateRequest.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        
        // Schedule periodic check (10 minutes)
        let periodicRequest = BGAppRefreshTaskRequest(identifier: "tech.md.Instancify.periodic-check")
        periodicRequest.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60)
        
        // Schedule refresh task (15 minutes)
        let refreshRequest = BGAppRefreshTaskRequest(identifier: "tech.md.Instancify.refresh")
        refreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(immediateRequest)
            try BGTaskScheduler.shared.submit(periodicRequest)
            try BGTaskScheduler.shared.submit(refreshRequest)
            
            print("\n📊 Scheduled background tasks:")
            print("  • Immediate check: \(immediateRequest.earliestBeginDate?.description ?? "unknown")")
            print("  • Periodic check: \(periodicRequest.earliestBeginDate?.description ?? "unknown")")
            print("  • Refresh: \(refreshRequest.earliestBeginDate?.description ?? "unknown")")
            } catch {
            print("❌ Failed to schedule background tasks: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate Methods
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        print("📱 Will present notification: \(notification.request.identifier)")
        return [.banner, .badge, .sound]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        print("📱 Did receive notification response: \(response.notification.request.identifier)")
        let userInfo = response.notification.request.content.userInfo
        
        // Handle the notification based on its type
        if let type = userInfo["type"] as? String {
            switch type {
            case "runtime_alert":
                if let instanceId = userInfo["instanceId"] as? String {
                    // Handle runtime alert action
                    print("📱 Handling runtime alert for instance: \(instanceId)")
                }
            case "auto_stop":
                if let instanceId = userInfo["instanceId"] as? String {
                    // Handle auto-stop notification action
                    print("📱 Handling auto-stop for instance: \(instanceId)")
                }
            default:
                print("📱 Unknown notification type: \(type)")
            }
        }
    }
    
    // MARK: - MessagingDelegate Methods
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("\n📱 Firebase registration token: \(fcmToken ?? "nil")")
        
        // Update token in FirebaseNotificationService
        if let token = fcmToken {
            Task { @MainActor in
                FirebaseNotificationService.shared.updateToken(token)
                // Resubscribe to topics with new token
                await FirebaseNotificationService.shared.resubscribeToSavedRegions()
            }
        }
    }
    
    // Handle incoming remote notifications when app is in background
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📱 Received remote notification in background")
        print("Notification payload: \(userInfo)")
        
        // Process the notification
        if let aps = userInfo["aps"] as? [String: Any] {
            print("APS content: \(aps)")
        }
        
        // Handle different notification types
        if let type = userInfo["type"] as? String {
            switch type {
            case "runtime_alert":
                if let instanceId = userInfo["instanceId"] as? String {
                    print("📱 Processing runtime alert for instance: \(instanceId)")
                    // Handle runtime alert
                    completionHandler(.newData)
                    return
                }
            case "auto_stop":
                if let instanceId = userInfo["instanceId"] as? String {
                    print("📱 Processing auto-stop for instance: \(instanceId)")
                    // Handle auto-stop notification
                    completionHandler(.newData)
                    return
                }
            default:
                print("📱 Unknown notification type: \(type)")
            }
        }
        
        completionHandler(.noData)
    }

    // Add this function to handle timer cleanup
    private func stopBackgroundTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        print("🕒 Stopped background timer")
    }

    private func parseRuntimeAlerts(from settings: [String: Bool]) -> [Int] {
        return settings.compactMap { key, isEnabled in
            guard isEnabled,
                  key.hasPrefix("runtime_alert_") else { return nil }
            
            let components = key.replacingOccurrences(of: "runtime_alert_", with: "")
                .components(separatedBy: "h")
            
            guard let hours = Int(components[0]) else { return nil }
            let minutes = components.count > 1 ? (Int(components[1].replacingOccurrences(of: "m", with: "")) ?? 0) : 0
            
            return (hours * 60) + minutes
        }.sorted()
    }

    // Add this method to handle APNS token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("\n📱 Received APNS token")
        Messaging.messaging().apnsToken = deviceToken
        
        // Now that we have the APNS token, we can safely get the FCM token
        Task {
            do {
                let token = try await Messaging.messaging().token()
                print("✅ FCM token refreshed: \(token)")
                
                // Update token in FirebaseNotificationService
                await FirebaseNotificationService.shared.updateToken(token)
                await FirebaseNotificationService.shared.resubscribeToSavedRegions()
            } catch {
                print("❌ Failed to get FCM token after APNS token: \(error)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}
