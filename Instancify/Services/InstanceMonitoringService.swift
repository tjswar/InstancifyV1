import Foundation
import Combine
import AWSEC2
import AWSCloudWatch
import UserNotifications
import BackgroundTasks
import UIKit
import AWSCore
import FirebaseFirestore

@MainActor
class InstanceMonitoringService: ObservableObject {
    static let shared = InstanceMonitoringService()
    private let notificationManager = NotificationManager.shared
    private let ec2Service = EC2Service.shared
    private let defaults: UserDefaults?
    private let notificationSettings = NotificationSettingsViewModel.shared
    private let scheduledNotifications = ScheduledNotificationService.shared
    
    @Published private(set) var notificationHistory: [NotificationHistoryItem] = []
    private let maxHistoryItems = 100 // Keep last 100 notifications
    
    @Published private(set) var isMonitoring = false
    private var monitoringTask: Task<Void, Never>?
    private var instances: [EC2Instance] = []
    private var notifiedThresholds: [String: [String: Set<Int>]] = [:]
    private var currentRegion: String
    private var isInitialized = false
    
    private init() {
        // Initialize with the current region from AuthenticationManager
        self.currentRegion = AuthenticationManager.shared.selectedRegion.rawValue
        
        if let bundleId = Bundle.main.bundleIdentifier {
            let appGroupId = "group.\(bundleId)"
            defaults = UserDefaults(suiteName: appGroupId)
        } else {
            defaults = nil
        }
        
        isMonitoring = defaults?.bool(forKey: "isMonitoring") ?? false
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillTerminate() {
        // Save monitoring state before app termination
        defaults?.set(isMonitoring, forKey: "isMonitoring")
        defaults?.synchronize()
    }
    
    @objc private func handleAppDidBecomeActive() {
        // Restore monitoring state when app becomes active
        Task {
            do {
                try await initialize()
                
                // Check instance states and clear alerts for stopped instances
                let settings = NotificationSettingsViewModel.shared
                if settings.runtimeAlertsEnabled {
                    try await checkAndCleanupAlerts()
                    if isMonitoring {
                        try await checkAllRegions()
                    } else {
                        try await startMonitoring()
                    }
                }
            } catch {
                print("❌ Failed to restore monitoring state: \(error)")
                // Try to recover monitoring state
                if let wasMonitoring = defaults?.bool(forKey: "isMonitoring"), wasMonitoring {
                    print("🔄 Attempting to recover monitoring state")
                    Task {
                        do {
                            try await startMonitoring()
                        } catch {
                            print("❌ Failed to recover monitoring state: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    @objc private func handleRegionChange(_ notification: Notification) {
        if let newRegion = notification.object as? String {
            // Update current region
            currentRegion = newRegion
            print("\n🌎 Region changed to: \(newRegion)")
            
            // Post notification for UI update
            NotificationCenter.default.post(
                name: NSNotification.Name("RegionUpdated"),
                object: newRegion
            )
            
            Task {
                do {
                    // Get current credentials
                    let authManager = AuthenticationManager.shared
                    let credentials = try authManager.getAWSCredentials()
                    
                    // Configure AWS services for new region
                    try await AWSManager.shared.configure(
                        accessKey: credentials.accessKeyId,
                        secretKey: credentials.secretAccessKey,
                        region: authManager.selectedRegion.awsRegionType
                    )
                    
                    // Update EC2Service configuration
                    EC2Service.shared.updateConfiguration(
                        with: credentials,
                        region: authManager.selectedRegion.rawValue
                    )
                    
                    print("✅ AWS credentials reconfigured for region: \(newRegion)")
                    
                    // Check all regions to maintain alerts across regions
                    try await checkAllRegions()
                    
                    // Restore alerts for this region if they were enabled
                    if notificationSettings.runtimeAlertsEnabled {
                        try await startMonitoring()
                    }
                } catch {
                    print("❌ Failed to handle region change: \(error)")
                }
            }
        }
    }
    
    @objc private func handleRuntimeAlertsChanged() {
        Task {
            do {
                if notificationSettings.runtimeAlertsEnabled {
                    if !isMonitoring {
                        try await restartMonitoring()
                    } else {
                        try await checkAllRegions()
                    }
                } else {
                    stopMonitoring()
                }
            } catch {
                print("❌ Failed to handle runtime alerts change: \(error)")
            }
        }
    }
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        try await loadNotificationHistory()
        try await loadNotifiedThresholds()
        
        // Ensure AWS credentials are configured before proceeding
        let authManager = AuthenticationManager.shared
        
        do {
            let credentials = try authManager.getAWSCredentials()
            
            // Update current region from AuthenticationManager
            self.currentRegion = authManager.selectedRegion.rawValue
            
            // Configure AWS services with credentials
            try await AWSManager.shared.configure(
                accessKey: credentials.accessKeyId,
                secretKey: credentials.secretAccessKey,
                region: authManager.selectedRegion.awsRegionType
            )
            
            // Update EC2Service configuration
            EC2Service.shared.updateConfiguration(
                with: credentials,
                region: authManager.selectedRegion.rawValue
            )
            
            print("✅ AWS credentials configured for region: \(authManager.selectedRegion.rawValue)")
            
            // Setup notification observers
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
            
            // Start monitoring if alerts are enabled
            if notificationSettings.runtimeAlertsEnabled {
                try await startMonitoring()
            }
            
            isInitialized = true
        } catch {
            print("❌ Failed to initialize with error: \(error)")
            // Try to recover credentials
            if let savedCredentials = try? KeychainManager.shared.retrieveCredentials(),
               let savedRegion = try? KeychainManager.shared.getRegion() {
                print("🔄 Attempting to recover using saved credentials")
                let regionType = mapRegionToAWSType(savedRegion)
                try await AWSManager.shared.configure(
                    accessKey: savedCredentials.accessKeyId,
                    secretKey: savedCredentials.secretAccessKey,
                    region: regionType
                )
                
                EC2Service.shared.updateConfiguration(
                    with: savedCredentials,
                    region: savedRegion
                )
                
                print("✅ Recovered using saved credentials")
                isInitialized = true
            } else {
                throw error
            }
        }
    }
    
    func startMonitoring() async throws {
        print("\n🔄 Starting instance monitoring")
        
        // Try to get credentials from multiple sources
        let credentials: AWSCredentials
        let region: String
        
        do {
            credentials = try AuthenticationManager.shared.getAWSCredentials()
            region = AuthenticationManager.shared.selectedRegion.rawValue
        } catch {
            print("⚠️ Failed to get credentials from AuthManager, trying Keychain")
            credentials = try KeychainManager.shared.retrieveCredentials()
            region = try KeychainManager.shared.getRegion()
        }
        
        // Create credentials provider
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: credentials.accessKeyId,
            secretKey: credentials.secretAccessKey
        )
        
        // Create service configuration
        let configuration = AWSServiceConfiguration(
            region: mapRegionToAWSType(region),
            credentialsProvider: credentialsProvider
        )!
        
        // Set default configuration
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Register EC2 service with this configuration
        AWSEC2.register(with: configuration, forKey: "DefaultKey")
        
        print("✅ AWS configuration updated with credentials")
        print("  • Access Key ID: \(credentials.accessKeyId)")
        print("  • Region: \(region)")
        
        // Start monitoring
        isMonitoring = true
        defaults?.set(true, forKey: "isMonitoring")
        defaults?.synchronize()
        
        monitoringTask?.cancel()
        monitoringTask = Task {
            do {
                while isMonitoring {
                    try await checkAllRegions()
                    try await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // Check every 5 minutes
                }
            } catch {
                print("❌ Failed to check regions: \(error)")
                isMonitoring = false
                defaults?.set(false, forKey: "isMonitoring")
                defaults?.synchronize()
            }
        }
        
        print("✅ Instance monitoring started")
        
        // Schedule background tasks
        await AppDelegate.shared.scheduleBackgroundTasks()
    }
    
    private func stopMonitoring() {
        isMonitoring = false
        defaults?.set(false, forKey: "isMonitoring")
        defaults?.synchronize()
        
        monitoringTask?.cancel()
        monitoringTask = nil
        
        Task {
            do {
                try await resetAllNotificationState()
            } catch {
                print("❌ Failed to reset notification state: \(error)")
            }
        }
    }
    
    private func restartMonitoring() async throws {
        stopMonitoring()
        try await startMonitoring()
    }
    
    private func resetAllNotificationState() async throws {
        notifiedThresholds.removeAll()
        try saveNotifiedThresholds()
    }
    
    private func clearScheduledNotifications() async throws {
        // Clear all scheduled notifications for current region
        scheduledNotifications.clearNotifications(instanceId: "", region: currentRegion)
    }
    
    func checkAllRegions() async throws {
        print("\n🔍 Checking all regions for runtime alerts")
        
        // Get credentials first
        guard let credentials = try? AuthenticationManager.shared.getAWSCredentials() else {
            print("❌ No AWS credentials available")
            throw AWSError.noCredentialsFound
        }
        
        // Get all enabled alerts
        let settings = NotificationSettingsViewModel.shared
        let alerts = settings.runtimeAlerts.filter { $0.enabled }
        
        // Get unique regions to check
        let regionsToCheck = Set(alerts.flatMap { $0.regions })
        print("📍 Monitoring regions: \(regionsToCheck)")
        print("🌍 Global alerts: \(alerts.filter { $0.regions.isEmpty }.count)")
        
        // Process global alerts first
        if alerts.contains(where: { $0.regions.isEmpty }) {
            print("\n🌐 Processing global alerts...")
            try await processGlobalAlerts(with: credentials)
        }
        
        // Then process region-specific alerts
        for region in regionsToCheck {
            print("\n🗺️ Processing alerts for region: \(region)")
            try await processRegionAlerts(region: region, with: credentials)
        }
        
        print("\n✅ Completed runtime alert check")
    }
    
    private func processGlobalAlerts(with credentials: AWSCredentials) async throws {
        // Configure AWS for global check
        let configuration = AWSServiceConfiguration(
            region: .USEast1,
            credentialsProvider: AWSStaticCredentialsProvider(
                accessKey: credentials.accessKeyId,
                secretKey: credentials.secretAccessKey
            )
        )!
        
        AWSEC2.register(with: configuration, forKey: "GlobalCheck")
        let ec2Client = AWSEC2(forKey: "GlobalCheck")
        
        let request = AWSEC2DescribeInstancesRequest()!
        let result = try await ec2Client.describeInstances(request)
        
        if let instances = result.reservations?.flatMap({ $0.instances ?? [] }) {
            print("📊 Found \(instances.count) instances for global alerts")
            
            for instance in instances {
                guard let instanceId = instance.instanceId,
                      let state = instance.state,
                      state.name == .running,
                      let launchTime = instance.launchTime else { continue }
                
                let name = instance.tags?.first(where: { $0.key == "Name" })?.value ?? instanceId
                print("\n⏰ Scheduling global alerts for instance: \(instanceId)")
                print("  • Name: \(name)")
                print("  • Launch Time: \(launchTime)")
                
                try await scheduledNotifications.scheduleRuntimeNotifications(
                    instanceId: instanceId,
                    instanceName: name,
                    region: "us-east-1",
                    launchTime: launchTime
                )
            }
        }
    }
    
    private func processRegionAlerts(region: String, with credentials: AWSCredentials) async throws {
        print("🔄 Processing region: \(region)")
        
        // Configure AWS for region check
        guard let regionType = AWSRegion(rawValue: region)?.awsRegionType else {
            print("❌ Invalid region: \(region)")
            return
        }
        
        let configuration = AWSServiceConfiguration(
            region: regionType,
            credentialsProvider: AWSStaticCredentialsProvider(
                accessKey: credentials.accessKeyId,
                secretKey: credentials.secretAccessKey
            )
        )!
        
        AWSEC2.register(with: configuration, forKey: "RegionCheck-\(region)")
        let ec2Client = AWSEC2(forKey: "RegionCheck-\(region)")
        
        let request = AWSEC2DescribeInstancesRequest()!
        let result = try await ec2Client.describeInstances(request)
        
        if let instances = result.reservations?.flatMap({ $0.instances ?? [] }) {
            print("📊 Found \(instances.count) instances in region \(region)")
            
            for instance in instances {
                guard let instanceId = instance.instanceId,
                      let state = instance.state,
                      state.name == .running,
                      let launchTime = instance.launchTime else { continue }
                
                let name = instance.tags?.first(where: { $0.key == "Name" })?.value ?? instanceId
                print("\n⏰ Scheduling alerts for instance: \(instanceId)")
                print("  • Name: \(name)")
                print("  • Launch Time: \(launchTime)")
                
                try await scheduledNotifications.scheduleRuntimeNotifications(
                    instanceId: instanceId,
                    instanceName: name,
                    region: region,
                    launchTime: launchTime
                )
            }
        }
    }
    
    private func loadNotificationHistory() async throws {
        if let data = defaults?.data(forKey: "NotificationHistory") {
            do {
                notificationHistory = try JSONDecoder().decode([NotificationHistoryItem].self, from: data)
            } catch {
                print("❌ Failed to decode notification history: \(error)")
                notificationHistory = []
                throw error
            }
        }
    }
    
    private func loadNotifiedThresholds() async throws {
        if let data = defaults?.data(forKey: "NotifiedThresholds") {
            do {
                notifiedThresholds = try JSONDecoder().decode([String: [String: Set<Int>]].self, from: data)
            } catch {
                print("❌ Failed to decode notified thresholds: \(error)")
                notifiedThresholds = [:]
                throw error
            }
        }
    }
    
    private func saveNotifiedThresholds() throws {
        do {
            let encoded = try JSONEncoder().encode(notifiedThresholds)
            defaults?.set(encoded, forKey: "NotifiedThresholds")
        } catch {
            print("❌ Failed to encode notified thresholds: \(error)")
            throw error
        }
    }
    
    // Handle instance state changes
    func handleInstanceStateChange(_ instance: EC2Instance, region: String) async throws {
        print("\n🔄 Handling state change for instance \(instance.id) in region \(region)")
        print("  • Instance: \(instance.name ?? "unnamed")")
        print("  • State: \(instance.state)")
        print("  • Launch Time: \(instance.launchTime?.description ?? "unknown")")

        switch instance.state {
        case .running:
            print("✅ Instance is running, scheduling runtime alerts")
            // Schedule runtime alerts
            try await scheduledNotifications.scheduleRuntimeNotifications(
                instanceId: instance.id,
                instanceName: instance.name,
                region: region,
                launchTime: instance.launchTime ?? Date()
            )
            
        case .stopped, .stopping, .terminated, .shuttingDown:
            print("\n🗑️ Instance is \(instance.state), cleaning up alerts")
            // Clear alerts from Firestore
            let db = Firestore.firestore()
            let alertsRef = db.collection("scheduledAlerts")
            
            print("  • Querying alerts for instance \(instance.id)")
            // Get all alerts for this instance
            let alerts = try await alertsRef
                .whereField("instanceID", isEqualTo: instance.id)
                .whereField("region", isEqualTo: region)
                .getDocuments()
            
            print("  • Found \(alerts.documents.count) alerts")
            
            if !alerts.isEmpty {
                let batch = db.batch()
                alerts.documents.forEach { doc in
                    print("  • Deleting alert: \(doc.documentID)")
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
                print("✅ Successfully deleted \(alerts.documents.count) alerts")
                
                // Add cleanup notification to history
                let historyRef = db.collection("notificationHistory").document()
                let notificationData: [String: Any] = [
                    "type": "alert_cleanup",
                    "title": "Alerts Cancelled",
                    "body": "All runtime alerts for \(instance.name ?? instance.id) have been cancelled because the instance was \(instance.state.rawValue)",
                    "instanceId": instance.id,
                    "instanceName": instance.name ?? instance.id,
                    "region": region,
                    "timestamp": FieldValue.serverTimestamp(),
                    "time": Date().ISO8601Format(),
                    "status": "completed",
                    "createdAt": FieldValue.serverTimestamp(),
                    "formattedTime": DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
                ]
                try await historyRef.setData(notificationData)
                print("✅ Added cleanup notification to history")
            } else {
                print("ℹ️ No alerts found to delete")
            }
            
            // Clear local notifications
            print("  • Clearing local notifications")
            scheduledNotifications.clearNotifications(instanceId: instance.id, region: region)
            
        default:
            print("⏳ Instance in transition state: \(instance.state)")
        }
        
        // Send state change notification
        try await notificationManager.sendInstanceStateNotification(
            instanceId: instance.id,
            instanceName: instance.name,
            state: instance.state
        )
    }
    
    private func checkAndCleanupAlerts() async throws {
        print("\n🧹 Checking and cleaning up alerts...")
        
        // Get credentials
        guard let credentials = try? AuthenticationManager.shared.getAWSCredentials() else {
            print("❌ No AWS credentials available")
            throw AWSError.noCredentialsFound
        }
        
        // Get all alerts from Firestore
        let alertsSnapshot = try await FirestoreManager.shared.db
            .collection("scheduledAlerts")
            .getDocuments()
        
        // Group alerts by region
        var alertsByRegion: [String: [(String, String)]] = [:] // [region: [(documentId, instanceId)]]
        
        for doc in alertsSnapshot.documents {
            guard let region = doc.data()["region"] as? String,
                  let instanceId = doc.data()["instanceID"] as? String else {
                continue
            }
            alertsByRegion[region, default: []].append((doc.documentID, instanceId))
        }
        
        // Check instance states in each region
        for (region, alerts) in alertsByRegion {
            print("\n🔍 Checking region: \(region)")
            
            guard let regionType = AWSRegion(rawValue: region)?.awsRegionType else {
                print("❌ Invalid region: \(region)")
                continue
            }
            
            // Configure AWS for region check
            let configuration = AWSServiceConfiguration(
                region: regionType,
                credentialsProvider: AWSStaticCredentialsProvider(
                    accessKey: credentials.accessKeyId,
                    secretKey: credentials.secretAccessKey
                )
            )!
            
            AWSEC2.register(with: configuration, forKey: "Cleanup-\(region)")
            let ec2Client = AWSEC2(forKey: "Cleanup-\(region)")
            
            // Get unique instance IDs for this region
            let instanceIds = Array(Set(alerts.map { $0.1 }))
            
            // Check instance states
            let request = AWSEC2DescribeInstancesRequest()!
            request.instanceIds = instanceIds
            
            let result = try await ec2Client.describeInstances(request)
            
            if let instances = result.reservations?.flatMap({ $0.instances ?? [] }) {
                let runningInstanceIds = Set(instances.filter { $0.state?.name == .running }.compactMap { $0.instanceId })
                
                // Clear alerts for non-running instances
                let batch = FirestoreManager.shared.db.batch()
                
                for (docId, instanceId) in alerts {
                    if !runningInstanceIds.contains(instanceId) {
                        print("🗑️ Clearing alerts for stopped instance: \(instanceId)")
                        let docRef = FirestoreManager.shared.db.collection("scheduledAlerts").document(docId)
                        batch.deleteDocument(docRef)
                    }
                }
                
                try await batch.commit()
            }
        }
        
        print("✅ Alert cleanup completed")
    }
}

// MARK: - Notification History
extension InstanceMonitoringService {
    func getNotificationHistory() -> [NotificationHistoryItem] {
        return notificationHistory
    }
    
    func clearNotificationHistory() {
        notificationHistory.removeAll()
        defaults?.removeObject(forKey: "NotificationHistory")
    }
} 