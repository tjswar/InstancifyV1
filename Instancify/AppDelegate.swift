import UIKit
import Firebase
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications
import BackgroundTasks
import CoreData
import AWSEC2

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = AppDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("\n🚀 Application did finish launching")
        
        // Only configure Firebase if it hasn't been configured yet
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("✅ Firebase configured in AppDelegate")
        } else {
            print("ℹ️ Firebase already configured")
        }
        
        // Setup background tasks
        setupBackgroundTasks()
        
        // Setup Firebase Messaging
        Messaging.messaging().delegate = self
        
        // Request notification authorization
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print(granted ? "✅ Notification authorization granted" : "❌ Notification authorization denied")
            if let error = error {
                print("❌ Notification authorization error: \(error)")
            }
        }
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        // Restore alerts state
        Task {
            await restoreAlertsState()
        }
        
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("\n📱 Application will terminate")
        Task {
            await saveAlertsState()
        }
    }
    
    private func saveAlertsState() async {
        print("\n💾 Saving alerts state")
        do {
            let db = Firestore.firestore()
            let alertsQuery = db.collection("scheduledAlerts")
                .whereField("status", isEqualTo: "pending")
                .whereField("notificationSent", isEqualTo: false)
            
            let snapshot = try await alertsQuery.getDocuments()
            if !snapshot.documents.isEmpty {
                print("  • Found \(snapshot.documents.count) active alerts")
                let batch = db.batch()
                
                for doc in snapshot.documents {
                    let docRef = db.collection("scheduledAlerts").document(doc.documentID)
                    batch.updateData([
                        "appTerminated": true,
                        "lastUpdated": FieldValue.serverTimestamp()
                    ], forDocument: docRef)
                }
                
                try await batch.commit()
                print("✅ Successfully marked alerts as terminated")
            }
        } catch {
            print("❌ Failed to save alerts state: \(error)")
        }
    }
    
    private func restoreAlertsState() async {
        print("\n🔄 Restoring alerts state")
        do {
            let db = Firestore.firestore()
            let alertsQuery = db.collection("scheduledAlerts")
                .whereField("appTerminated", isEqualTo: true)
                .whereField("status", isEqualTo: "pending")
            
            let snapshot = try await alertsQuery.getDocuments()
            if !snapshot.documents.isEmpty {
                print("  • Found \(snapshot.documents.count) alerts to restore")
                
                // Group alerts by region
                var alertsByRegion: [String: [(String, String, Date)]] = [:]
                for doc in snapshot.documents {
                    let data = doc.data()
                    if let region = data["region"] as? String,
                       let instanceId = data["instanceID"] as? String,
                       let launchTime = (data["launchTime"] as? Timestamp)?.dateValue() {
                        alertsByRegion[region, default: []].append((instanceId, doc.documentID, launchTime))
                    }
                }
                
                // Process each region
                for (region, alerts) in alertsByRegion {
                    print("  • Processing region: \(region)")
                    
                    // Check if alerts should be enabled for this region
                    if UserDefaults.standard.bool(forKey: "runtimeAlerts_enabled_\(region)") {
                        // Re-enable alerts for the region
                        try await NotificationSettingsViewModel.shared.setRuntimeAlerts(enabled: true, region: region)
                        
                        // Restore alerts for each instance
                        for (instanceId, alertId, launchTime) in alerts {
                            print("    - Restoring alert for instance: \(instanceId)")
                            // Create a temporary EC2Instance for restoration
                            let instance = EC2Instance(
                                id: instanceId,
                                instanceType: "t2.micro", // Default type since we don't have it
                                state: .running,
                                name: instanceId,
                                launchTime: launchTime,
                                publicIP: nil,
                                privateIP: nil,
                                autoStopEnabled: false,
                                countdown: nil,
                                stateTransitionTime: nil,
                                hourlyRate: 0.0,
                                runtime: 0,
                                currentCost: 0.0,
                                projectedDailyCost: 0.0,
                                region: region
                            )
                            try await InstanceMonitoringService.shared.handleInstanceStateChange(instance, region: region)
                        }
                    }
                }
                
                print("✅ Successfully restored alerts state")
            } else {
                print("ℹ️ No terminated alerts found to restore")
            }
        } catch {
            print("❌ Failed to restore alerts state: \(error)")
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation creates and returns a container, having loaded the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Instancify")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // MARK: - Background Tasks
    
    private func setupBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "tech.md.Instancify.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "tech.md.Instancify.immediate-check", using: nil) { task in
            self.handleImmediateCheck(task: task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "tech.md.Instancify.periodic-check", using: nil) { task in
            self.handlePeriodicCheck(task: task as! BGProcessingTask)
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule next refresh first
        scheduleNextRefresh()
        
        // Create a task for monitoring
        let monitoringTask = Task {
            do {
                if NotificationSettingsViewModel.shared.runtimeAlertsEnabled {
                    try await InstanceMonitoringService.shared.checkAllRegions()
                }
            } catch {
                print("❌ Background refresh monitoring failed: \(error)")
            }
        }
        
        // Ensure the task is cancelled if we run out of time
        task.expirationHandler = {
            monitoringTask.cancel()
        }
        
        // Wait for the monitoring to complete
        Task {
            await monitoringTask.value
            task.setTaskCompleted(success: true)
        }
    }
    
    private func handleImmediateCheck(task: BGProcessingTask) {
        // Schedule next check first
        scheduleNextCheck()
        
        // Create a task for monitoring
        let monitoringTask = Task {
            do {
                if NotificationSettingsViewModel.shared.runtimeAlertsEnabled {
                    try await InstanceMonitoringService.shared.checkAllRegions()
                }
            } catch {
                print("❌ Background immediate check monitoring failed: \(error)")
            }
        }
        
        // Ensure the task is cancelled if we run out of time
        task.expirationHandler = {
            monitoringTask.cancel()
        }
        
        // Wait for the monitoring to complete
        Task {
            await monitoringTask.value
            task.setTaskCompleted(success: true)
        }
    }
    
    private func handlePeriodicCheck(task: BGProcessingTask) {
        // Schedule next periodic check first
        scheduleNextPeriodicCheck()
        
        // Create a task for monitoring
        let monitoringTask = Task {
            do {
                if NotificationSettingsViewModel.shared.runtimeAlertsEnabled {
                    try await InstanceMonitoringService.shared.checkAllRegions()
                }
            } catch {
                print("❌ Background periodic check monitoring failed: \(error)")
            }
        }
        
        // Ensure the task is cancelled if we run out of time
        task.expirationHandler = {
            monitoringTask.cancel()
        }
        
        // Wait for the monitoring to complete
        Task {
            await monitoringTask.value
            task.setTaskCompleted(success: true)
        }
    }
    
    func scheduleBackgroundTasks() {
        scheduleNextRefresh()
        scheduleNextCheck()
        scheduleNextPeriodicCheck()
    }
    
    private func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "tech.md.Instancify.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled next app refresh")
        } catch {
            print("❌ Could not schedule app refresh: \(error)")
        }
    }
    
    private func scheduleNextCheck() {
        let request = BGProcessingTaskRequest(identifier: "tech.md.Instancify.immediate-check")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled next immediate check")
        } catch {
            print("❌ Could not schedule immediate check: \(error)")
        }
    }
    
    private func scheduleNextPeriodicCheck() {
        let request = BGProcessingTaskRequest(identifier: "tech.md.Instancify.periodic-check")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled next periodic check")
        } catch {
            print("❌ Could not schedule periodic check: \(error)")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    // MARK: - Remote Notification Handling
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 Successfully registered for remote notifications with token: \(deviceToken)")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Firebase Messaging Delegate
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            print("📱 Firebase registration token: \(token)")
            // Here you can send this token to your server
        }
    }
} 