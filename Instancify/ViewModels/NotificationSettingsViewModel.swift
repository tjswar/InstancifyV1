import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging

struct RegionRuntimeAlert: Codable, Identifiable {
    let id: String
    var enabled: Bool
    var hours: Int
    var minutes: Int
    var regions: Set<String>
}

@MainActor
class NotificationSettingsViewModel: ObservableObject {
    private static let _shared = NotificationSettingsViewModel()
    
    static var shared: NotificationSettingsViewModel {
        return _shared
    }
    
    private let defaults: UserDefaults?
    private let runtimeAlertsKey = "RuntimeAlerts"
    private let runtimeAlertsEnabledKey = "RuntimeAlertsEnabled"
    private let runtimeAlertsEnabledByRegionKey = "RuntimeAlertsEnabledByRegion"
    private let warningIntervalsKey = "WarningIntervals"
    private let warningsEnabledKey = "WarningsEnabled"
    private let countdownEnabledKey = "CountdownEnabled"
    private let notificationService = FirebaseNotificationService.shared
    private let db = Firestore.firestore()
    private var userId: String?
    private var listenerRegistration: ListenerRegistration?
    
    @Published var runtimeAlerts: [RegionRuntimeAlert] = [] {
        didSet {
            saveAlerts()
            NotificationCenter.default.post(name: NSNotification.Name("RuntimeAlertsChanged"), object: nil)
            // Trigger immediate instance check
            Task {
                do {
                    try await InstanceMonitoringService.shared.checkAllRegions()
                } catch {
                    print("Failed to check regions: \(error)")
                }
            }
        }
    }
    
    @Published private(set) var warningIntervals: [Int] = []
    @Published private var runtimeAlertsEnabledByRegion: [String: Bool] = [:] {
        didSet {
            defaults?.set(runtimeAlertsEnabledByRegion, forKey: runtimeAlertsEnabledByRegionKey)
            NotificationCenter.default.post(name: NSNotification.Name("RuntimeAlertsChanged"), object: nil)
        }
    }
    
    private var warningsEnabled = true {
        didSet {
            defaults?.set(warningsEnabled, forKey: warningsEnabledKey)
        }
    }
    
    private var countdownEnabled = true {
        didSet {
            defaults?.set(countdownEnabled, forKey: countdownEnabledKey)
        }
    }
    
    var autoStopWarningsEnabled: Bool {
        get { warningsEnabled }
        set { warningsEnabled = newValue }
    }
    
    var autoStopCountdownEnabled: Bool {
        get { countdownEnabled }
        set { countdownEnabled = newValue }
    }
    
    var selectedWarningIntervals: Set<Int> {
        get { Set(warningIntervals) }
        set { 
            warningIntervals = Array(newValue).sorted(by: >)
            saveWarningIntervals()
        }
    }
    
    let availableWarningIntervals: [(Int, String)] = [
        (7200, "2 hours"),
        (3600, "1 hour"),
        (1800, "30 minutes"),
        (900, "15 minutes"),
        (600, "10 minutes"),
        (300, "5 minutes"),
        (120, "2 minutes"),
        (60, "1 minute")
    ]
    
    // Add this computed property to maintain compatibility with existing code
    var runtimeAlertsEnabled: Bool {
        get {
            // Return true if any region has alerts enabled
            return !runtimeAlertsEnabledByRegion.isEmpty && runtimeAlertsEnabledByRegion.values.contains(true)
        }
        set {
            if !newValue {
                // If disabling, clear all regions
                Task {
                    do {
                        try await clearAllAlerts()
                        runtimeAlertsEnabledByRegion.removeAll()
                        runtimeAlerts.removeAll()
                        saveAlerts()
                    } catch {
                        print("❌ Failed to clear all alerts: \(error)")
                    }
                }
            }
        }
    }
    
    init() {
        print("\n🔔 Initializing NotificationSettingsViewModel")
        
        // Setup UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            let appGroupId = "group.\(bundleId)"
            defaults = UserDefaults(suiteName: appGroupId)
        } else {
            defaults = nil
        }
        
        // Load all settings
        loadAllSettings()
        
        print("✅ NotificationSettingsViewModel initialized")
        print("  • Total alerts: \(runtimeAlerts.count)")
        print("  • Warning intervals: \(warningIntervals.count)")
        
        // Initialize Firebase auth and listeners
        Task {
            do {
                // Ensure we're authenticated
                if Auth.auth().currentUser == nil {
                    let result = try await Auth.auth().signInAnonymously()
                    self.userId = result.user.uid
                    print("✅ Anonymous auth successful. User ID: \(result.user.uid)")
                } else {
                    self.userId = Auth.auth().currentUser?.uid
                    print("✅ Already authenticated. User ID: \(Auth.auth().currentUser?.uid ?? "unknown")")
                }
                
                // Now that we're authenticated, sync state and setup listeners
                try await syncRuntimeAlertsState()
                setupRuntimeAlertsListener()
                loadRuntimeAlertsState()
            } catch {
                print("❌ Failed to initialize Firebase auth and listeners: \(error)")
            }
        }
    }
    
    private func loadAllSettings() {
        // Load runtime alerts enabled state by region
        if let data = defaults?.dictionary(forKey: runtimeAlertsEnabledByRegionKey) as? [String: Bool] {
            runtimeAlertsEnabledByRegion = data
        }
        
        // Load warnings and countdown state
        warningsEnabled = defaults?.bool(forKey: warningsEnabledKey) ?? true
        countdownEnabled = defaults?.bool(forKey: countdownEnabledKey) ?? true
        
        // Load warning intervals
        if let data = defaults?.array(forKey: warningIntervalsKey) as? [Int] {
            warningIntervals = data
        } else {
            warningIntervals = [3600, 1800, 900, 300, 120, 60]
            saveWarningIntervals()
        }
        
        // Load runtime alerts
        if let data = defaults?.data(forKey: runtimeAlertsKey),
           let alerts = try? JSONDecoder().decode([RegionRuntimeAlert].self, from: data) {
            runtimeAlerts = alerts
            print("  • Loaded \(alerts.count) runtime alerts")
        } else {
            runtimeAlerts = []
            saveAlerts()
            print("  • No runtime alerts found, initialized empty array")
        }
    }
    
    private func saveWarningIntervals() {
        defaults?.set(warningIntervals, forKey: warningIntervalsKey)
    }
    
    private func saveAlerts() {
        if let encoded = try? JSONEncoder().encode(runtimeAlerts) {
            defaults?.set(encoded, forKey: runtimeAlertsKey)
            defaults?.synchronize()
            
            // Also save to Firestore for backup
            Task {
                do {
                    guard let userId = userId else { return }
                    let alertsRef = db.collection("userSettings").document(userId)
                    try await alertsRef.setData([
                        "runtimeAlerts": runtimeAlerts.map { alert in
                            [
                                "id": alert.id,
                                "enabled": alert.enabled,
                                "hours": alert.hours,
                                "minutes": alert.minutes,
                                "regions": Array(alert.regions)
                            ]
                        },
                        "updatedAt": FieldValue.serverTimestamp()
                    ], merge: true)
                } catch {
                    print("❌ Failed to backup alerts to Firestore: \(error)")
                }
            }
        }
    }
    
    func addNewAlert(hours: Int = 0, minutes: Int = 0, regions: Set<String>) {
        print("\n📝 Adding new runtime alert")
        print("  • Hours: \(hours)")
        print("  • Minutes: \(minutes)")
        print("  • Regions: \(regions)")
        
        guard let userId = userId else { return }
        
        let newThreshold = hours * 60 + minutes
        
        // Check for existing alerts with same threshold
        let existingRegionAlerts = runtimeAlerts.filter { alert in
            !alert.regions.isDisjoint(with: regions) && 
            (alert.hours * 60 + alert.minutes) == newThreshold
        }
        
        if !existingRegionAlerts.isEmpty {
            print("  ⚠️ Alert already exists for specified regions")
            return
        }
        
        let alertId = UUID().uuidString
        let newAlert = RegionRuntimeAlert(
            id: alertId,
            enabled: true,
            hours: hours,
            minutes: minutes,
            regions: regions
        )
        
        // Add to local state
        runtimeAlerts.append(newAlert)
        
        // Save alert definition to Firestore
        Task {
            do {
                let batch = db.batch()
                
                // Add alert definition for each region
                for region in regions {
                    let alertRef = db.collection("scheduledAlerts")
                        .document("\(userId)_\(region)_\(alertId)")
                    
                    batch.setData([
                        "id": alertId,
                        "userId": userId,
                        "region": region,
                        "hours": hours,
                        "minutes": minutes,
                        "threshold": newThreshold,
                        "enabled": true,
                        "type": "alert_definition",
                        "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: alertRef)
                }
                
                try await batch.commit()
                print("  ✅ Alert definitions saved")
                
                // Apply to running instances
                let ec2Service = EC2Service.shared
                let instances = try await ec2Service.fetchInstances()
                
                for instance in instances {
                    if instance.state == .running && regions.contains(instance.region) {
                        await handleInstanceStateChange(
                            instanceId: instance.id,
                            instanceName: instance.name ?? instance.id,
                            region: instance.region,
                            state: "running",
                            launchTime: instance.launchTime
                        )
                    }
                }
            } catch {
                print("  ❌ Failed to save alert definitions: \(error)")
            }
        }
    }
    
    func deleteAlert(at indexSet: IndexSet) {
        Task {
            let alertsToDelete = indexSet.compactMap { index -> RegionRuntimeAlert? in
                guard index < runtimeAlerts.count else { return nil }
                return runtimeAlerts[index]
            }
            
            for alert in alertsToDelete {
                do {
                    print("\n🗑️ Deleting alert: \(alert.id)")
                    
                    // First, mark all instance-specific alerts as deleted
                    let instanceAlertsQuery = db.collection("scheduledAlerts")
                        .whereField("id", isEqualTo: alert.id)
                        .whereField("type", isEqualTo: "instance_alert")
                    
                    let instanceAlertDocs = try await instanceAlertsQuery.getDocuments()
                    if !instanceAlertDocs.documents.isEmpty {
                        print("  • Marking \(instanceAlertDocs.documents.count) instance alerts as deleted")
                        let batch = db.batch()
                        instanceAlertDocs.documents.forEach { doc in
                            batch.deleteDocument(doc.reference)
                        }
                        try await batch.commit()
                    }
                    
                    // Then, delete all alert definitions
                    let alertDefinitionsQuery = db.collection("scheduledAlerts")
                        .whereField("id", isEqualTo: alert.id)
                        .whereField("type", isEqualTo: "alert_definition")
                    
                    let alertDefinitionDocs = try await alertDefinitionsQuery.getDocuments()
                    if !alertDefinitionDocs.documents.isEmpty {
                        print("  • Marking \(alertDefinitionDocs.documents.count) alert definitions as deleted")
                        let batch = db.batch()
                        alertDefinitionDocs.documents.forEach { doc in
                            batch.deleteDocument(doc.reference)
                        }
                        try await batch.commit()
                    }
                    
                    // Finally, delete any pending notifications
                    let pendingAlertsQuery = db.collection("scheduledAlerts")
                        .whereField("id", isEqualTo: alert.id)
                        .whereField("status", isEqualTo: "pending")
                    
                    let pendingAlertDocs = try await pendingAlertsQuery.getDocuments()
                    if !pendingAlertDocs.documents.isEmpty {
                        print("  • Deleting \(pendingAlertDocs.documents.count) pending notifications")
                        let batch = db.batch()
                        pendingAlertDocs.documents.forEach { doc in
                            batch.deleteDocument(doc.reference)
                        }
                        try await batch.commit()
                    }
                    
                    // Remove from local state
                    DispatchQueue.main.async {
                        if let index = self.runtimeAlerts.firstIndex(where: { $0.id == alert.id }) {
                            self.runtimeAlerts.remove(at: index)
                        }
                    }
                    
                    print("✅ Successfully deleted alert and all associated documents")
                } catch {
                    print("❌ Failed to delete alert: \(error)")
                }
            }
        }
    }
    
    private func clearFirestoreAlerts(for alert: RegionRuntimeAlert) async throws {
        guard let userId = userId else { return }
        
        let alertsRef = db.collection("scheduledAlerts")
        let query = alertsRef
            .whereField("userId", isEqualTo: userId)
            .whereField("id", isEqualTo: alert.id)
        
        let snapshot = try await query.getDocuments()
        
        if !snapshot.documents.isEmpty {
            let batch = db.batch()
            snapshot.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }
    }
    
    private func clearAllAlerts() async throws {
        guard let userId = userId else { return }
        
        let alertsRef = db.collection("scheduledAlerts")
        let query = alertsRef.whereField("userId", isEqualTo: userId)
        let snapshot = try await query.getDocuments()
        
        if !snapshot.documents.isEmpty {
            let batch = db.batch()
            snapshot.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }
    }
    
    func updateAlert(id: String, enabled: Bool? = nil, hours: Int? = nil, minutes: Int? = nil, regions: Set<String>? = nil) {
        guard let index = runtimeAlerts.firstIndex(where: { $0.id == id }) else { return }
        var alert = runtimeAlerts[index]
        
        if let enabled = enabled {
            alert.enabled = enabled
        }
        if let hours = hours {
            alert.hours = hours
        }
        if let minutes = minutes {
            alert.minutes = minutes
        }
        if let regions = regions {
            alert.regions = regions
        }
        
        runtimeAlerts[index] = alert
        saveAlerts()
        NotificationCenter.default.post(name: NSNotification.Name("RuntimeAlertsChanged"), object: nil)
    }
    
    func toggleWarningInterval(_ interval: Int) {
        if selectedWarningIntervals.contains(interval) {
            selectedWarningIntervals.remove(interval)
        } else {
            selectedWarningIntervals.insert(interval)
        }
    }
    
    // Modify getAlertsForRegion to not depend on global runtimeAlertsEnabled
    func getAlertsForRegion(_ region: String) -> [RegionRuntimeAlert] {
        print("\n📝 Getting runtime alerts for region: \(region)")
        
        // Only check this region's enabled state
        guard runtimeAlertsEnabledByRegion[region] == true else {
            print("  ❌ Runtime alerts are disabled for this region")
            return []
        }
        
        // Get only region-specific alerts
        let alerts = runtimeAlerts.filter { alert in
            alert.enabled && alert.regions.contains(region)
        }
        
        // Sort by threshold
        let sortedAlerts = alerts.sorted { a1, a2 in
            let t1 = a1.hours * 60 + a1.minutes
            let t2 = a2.hours * 60 + a2.minutes
            return t1 < t2
        }
        
        return sortedAlerts
    }
    
    // Keep isRuntimeAlertsEnabled simple
    func isRuntimeAlertsEnabled(for region: String) -> Bool {
        return runtimeAlertsEnabledByRegion[region] == true
    }
    
    // Keep setRuntimeAlerts focused on single region with proper Firebase handling
    func setRuntimeAlerts(enabled: Bool, region: String) async throws {
        print("\n🔔 Setting runtime alerts for region \(region) to \(enabled)")
        
        guard let userId = userId else { return }
        
        // Update Firestore settings
        let settingsRef = db.collection("regionAlertStatus").document("\(userId)_\(region)")
        try await settingsRef.setData([
            "userId": userId,
            "region": region,
            "enabled": enabled,
            "type": "settings",
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        // If disabling, remove alerts for this specific region
        if !enabled {
            // Get all alert IDs for this region
            let alertsQuery = db.collection("scheduledAlerts")
                .whereField("userId", isEqualTo: userId)
                .whereField("region", isEqualTo: region)
                .whereField("type", isNotEqualTo: "settings")
            
            let snapshot = try await alertsQuery.getDocuments()
            let batch = db.batch()
            
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            
            try await batch.commit()
            
            // Only remove alerts for this region from local state
            runtimeAlerts.removeAll { alert in
                alert.regions.contains(region) && alert.regions.count == 1
            }
            
            // For alerts that cover multiple regions, just remove this region
            runtimeAlerts = runtimeAlerts.map { alert in
                if alert.regions.contains(region) && alert.regions.count > 1 {
                    var updatedAlert = alert
                    updatedAlert.regions.remove(region)
                    return updatedAlert
                }
                return alert
            }
            
            // Save the updated state to UserDefaults
            saveAlerts()
            
            // Save disabled state
            if let defaults = self.defaults {
                defaults.set(false, forKey: "runtimeAlerts_enabled_\(region)")
                defaults.synchronize()
            }
            
            // Update local state for this region
            DispatchQueue.main.async {
                self.runtimeAlertsEnabledByRegion[region] = false
            }
            
            print("✅ Cleared all alerts and disabled monitoring for region \(region)")
        } else {
            // If enabling, first check if there are any running instances
            let ec2Service = EC2Service.shared
            let instances = try await ec2Service.fetchInstances()
            let runningInstances = instances.filter { $0.state == .running && $0.region == region }
            
            if runningInstances.isEmpty {
                print("⚠️ No running instances in region \(region), keeping alerts disabled")
                
                // Update UI to show alerts are disabled
                DispatchQueue.main.async {
                    self.runtimeAlertsEnabledByRegion[region] = false
                }
                
                if let defaults = self.defaults {
                    defaults.set(false, forKey: "runtimeAlerts_enabled_\(region)")
                    defaults.synchronize()
                }
                
                throw NSError(domain: "RuntimeAlerts", 
                             code: 1, 
                             userInfo: [NSLocalizedDescriptionKey: "Cannot enable runtime alerts: No running instances in this region"])
            }
            
            // Reset the explicit disable flag when enabling
            UserDefaults.standard.removeObject(forKey: "explicit_disable_\(region)")
            
            print("  📝 Applying alerts to \(runningInstances.count) running instances in region \(region)")
            for instance in runningInstances {
                print("  • Processing instance: \(instance.name ?? instance.id)")
                await handleInstanceStateChange(
                    instanceId: instance.id,
                    instanceName: instance.name ?? instance.id,
                    region: region,
                    state: "running",
                    launchTime: instance.launchTime
                )
            }
            
            // Save enabled state to UserDefaults for recovery
            if let defaults = self.defaults {
                defaults.set(true, forKey: "runtimeAlerts_enabled_\(region)")
                defaults.synchronize()
            }
            
            // Update local state for this region
            DispatchQueue.main.async {
                self.runtimeAlertsEnabledByRegion[region] = true
            }
        }
        
        // Trigger a refresh to ensure all instances get alerts
        NotificationCenter.default.post(name: NSNotification.Name("RuntimeAlertsChanged"), object: nil)
    }
    
    private func setupRuntimeAlertsListener() {
        guard let userId = userId else { return }
        
        // Listen to alerts only, handle settings separately
        listenerRegistration = db.collection("scheduledAlerts")
            .whereField("userId", isEqualTo: userId)
            .whereField("type", isEqualTo: "alert")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let documents = snapshot?.documents else {
                    print("Error fetching runtime alerts: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Group documents by alert ID to prevent duplicates
                var alertMap: [String: RegionRuntimeAlert] = [:]
                
                for document in documents {
                    guard let data = document.data() as? [String: Any],
                          let id = data["id"] as? String,
                          let hours = data["hours"] as? Int,
                          let minutes = data["minutes"] as? Int,
                          let enabled = data["enabled"] as? Bool,
                          let regions = data["regions"] as? [String] else {
                        print("⚠️ Invalid document data: \(document.documentID)")
                        continue
                    }
                    
                    // Only add if we haven't seen this alert ID before
                    if alertMap[id] == nil {
                        alertMap[id] = RegionRuntimeAlert(
                            id: id,
                            enabled: enabled,
                            hours: hours,
                            minutes: minutes,
                            regions: Set(regions)
                        )
                    }
                }
                
                // Update runtime alerts with unique alerts only
                DispatchQueue.main.async {
                    self.runtimeAlerts = Array(alertMap.values)
                    print("✅ Loaded \(self.runtimeAlerts.count) unique alerts")
                }
            }
    }
    
    private func loadRuntimeAlertsState() {
        guard let userId = userId else { return }
        
        // First try to load from UserDefaults
        if let data = defaults?.data(forKey: runtimeAlertsKey),
           let alerts = try? JSONDecoder().decode([RegionRuntimeAlert].self, from: data) {
            DispatchQueue.main.async {
                self.runtimeAlerts = alerts
            }
        }
        
        // Then try to load enabled states from UserDefaults
        if let defaults = self.defaults {
            let keys = defaults.dictionaryRepresentation().keys.filter { $0.starts(with: "runtimeAlerts_enabled_") }
            var enabledRegions: [String: Bool] = [:]
            
            for key in keys {
                let region = String(key.dropFirst("runtimeAlerts_enabled_".count))
                enabledRegions[region] = defaults.bool(forKey: key)
            }
            
            if !enabledRegions.isEmpty {
                DispatchQueue.main.async {
                    self.runtimeAlertsEnabledByRegion = enabledRegions
                }
            }
        }
        
        // Finally, try to sync with Firestore
        db.collection("userSettings").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let alertsData = data["runtimeAlerts"] as? [[String: Any]] else {
                return
            }
            
            let alerts = alertsData.compactMap { dict -> RegionRuntimeAlert? in
                guard let id = dict["id"] as? String,
                      let enabled = dict["enabled"] as? Bool,
                      let hours = dict["hours"] as? Int,
                      let minutes = dict["minutes"] as? Int,
                      let regions = dict["regions"] as? [String] else {
                    return nil
                }
                return RegionRuntimeAlert(
                    id: id,
                    enabled: enabled,
                    hours: hours,
                    minutes: minutes,
                    regions: Set(regions)
                )
            }
            
            if !alerts.isEmpty {
                DispatchQueue.main.async {
                    self.runtimeAlerts = alerts
                    self.saveAlerts() // Save back to UserDefaults
                }
            }
        }
    }
    
    private func syncRuntimeAlertsState() async throws {
        print("\n🔄 Syncing runtime alerts state from Firestore")
        let snapshot = try await db.collection("regionAlertStatus").getDocuments()
        var enabledRegions: [String: Bool] = [:]
        
        for doc in snapshot.documents {
            if let enabled = doc.data()["enabled"] as? Bool, enabled {
                enabledRegions[doc.documentID] = true
            }
        }
        
        // Update local state
        runtimeAlertsEnabledByRegion = enabledRegions
        print("✅ Runtime alerts state synced from Firestore")
        print("  • Enabled regions: \(enabledRegions.keys.joined(separator: ", "))")
    }
    
    // Add method to handle instance state changes
    func handleInstanceStateChange(instanceId: String, instanceName: String, region: String, state: String, launchTime: Date?) async {
        print("\n🔄 Handling instance state change")
        print("  • Instance: \(instanceName) (\(instanceId))")
        print("  • Region: \(region)")
        print("  • State: \(state)")
        print("  • Launch Time: \(launchTime?.description ?? "N/A")")
        
        // Only proceed if state is "running"
        guard state == "running" else {
            print("  ℹ️ Not scheduling alerts - instance is not running")
            return
        }
        
        // Get alerts for this region
        let alerts = getAlertsForRegion(region)
        guard !alerts.isEmpty else {
            print("  ℹ️ No alerts configured for region \(region)")
            return
        }

        print("  📋 Found \(alerts.count) alerts to schedule")
        
        do {
            // Get FCM token first
            let token = try await Messaging.messaging().token()
            print("  ✅ Got FCM token: \(String(token.prefix(10)))...")
            
            // First, check for existing alerts for this instance
            let existingAlertsQuery = db.collection("scheduledAlerts")
                .whereField("instanceId", isEqualTo: instanceId)
                .whereField("status", isEqualTo: "pending")
                .whereField("deleted", isEqualTo: false)
            
            let existingAlerts = try await existingAlertsQuery.getDocuments()
            
            // Delete any existing alerts for this instance
            if !existingAlerts.isEmpty {
                print("  🧹 Cleaning up \(existingAlerts.count) existing alerts")
                let cleanupBatch = db.batch()
                existingAlerts.documents.forEach { doc in
                    cleanupBatch.deleteDocument(doc.reference)
                }
                try await cleanupBatch.commit()
            }
            
            // Create a new batch for scheduling alerts
            let batch = db.batch()
            var scheduledCount = 0
            var scheduledAlertTimes: [(hours: Int, minutes: Int)] = []
            
            // Keep track of scheduled thresholds to prevent duplicates
            var scheduledThresholds = Set<Int>()
            
            for alert in alerts {
                let threshold = alert.hours * 60 + alert.minutes
                
                // Skip if we've already scheduled an alert for this threshold
                guard !scheduledThresholds.contains(threshold) else {
                    print("  ⚠️ Skipping duplicate alert for threshold \(threshold) minutes")
                    continue
                }
                
                // Calculate trigger date based on launch time
                guard let triggerDate = launchTime?.addingTimeInterval(TimeInterval(threshold * 60)) else {
                    print("  ❌ Invalid launch time for alert with threshold \(threshold) minutes")
                    continue
                }
                
                // Only schedule if trigger date is in the future
                guard triggerDate > Date() else {
                    print("  ⏭️ Skipping alert - trigger time already passed")
                    continue
                }
                
                // Create unique alert ID using a more deterministic format
                let alertId = "\(region)_\(instanceId)_\(threshold)"
                
                let alertData: [String: Any] = [
                    "instanceId": instanceId,
                    "instanceName": instanceName,
                    "region": region,
                    "threshold": threshold,
                    "fcmToken": token,
                    "scheduledTime": Timestamp(date: triggerDate),
                    "launchTime": Timestamp(date: launchTime ?? Date()),
                    "status": "pending",
                    "notificationSent": false,
                    "deleted": false,
                    "instanceState": "running",
                    "created": FieldValue.serverTimestamp()
                ]
                
                // Add to batch
                let alertRef = db.collection("scheduledAlerts").document(alertId)
                batch.setData(alertData, forDocument: alertRef, merge: true)
                scheduledCount += 1
                scheduledThresholds.insert(threshold)
                scheduledAlertTimes.append((hours: alert.hours, minutes: alert.minutes))
                
                print("  ✅ Scheduled alert:")
                print("    • ID: \(alertId)")
                print("    • Threshold: \(threshold) minutes")
                print("    • Trigger time: \(triggerDate)")
            }
            
            // Commit the batch
            try await batch.commit()
            print("\n✅ Successfully scheduled \(scheduledCount) alerts")
            
            // Show success popup if alerts were scheduled
            if !scheduledAlertTimes.isEmpty {
                // Sort alerts by duration
                let sortedAlerts = scheduledAlertTimes.sorted { a, b in
                    let aDuration = a.hours * 60 + a.minutes
                    let bDuration = b.hours * 60 + b.minutes
                    return aDuration < bDuration
                }
                
                // Format alert times for display
                let alertTimesString = sortedAlerts.map { alert in
                    if alert.hours > 0 && alert.minutes > 0 {
                        return "\(alert.hours)h \(alert.minutes)m"
                    } else if alert.hours > 0 {
                        return "\(alert.hours)h"
                    } else {
                        return "\(alert.minutes)m"
                    }
                }.joined(separator: ", ")
                
                // Post notification for UI to show popup
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowAlertScheduledPopup"),
                    object: nil,
                    userInfo: [
                        "instanceName": instanceName,
                        "alertTimes": alertTimesString
                    ]
                )
            }
            
        } catch {
            print("❌ Failed to schedule alerts: \(error)")
        }
    }
    
    // Add a new method to handle instance state changes that affect runtime alerts
    func handleInstancesStateChange(in region: String) async {
        print("\n🔍 Checking instance states in region \(region)")
        
        do {
            let ec2Service = EC2Service.shared
            let instances = try await ec2Service.fetchInstances()
            let regionInstances = instances.filter { $0.region == region }
            let runningInstances = regionInstances.filter { $0.state == .running }
            
            print("  • Total instances in region: \(regionInstances.count)")
            print("  • Running instances: \(runningInstances.count)")
            
            // If no running instances and alerts are enabled, disable them
            if runningInstances.isEmpty && isRuntimeAlertsEnabled(for: region) {
                print("⚠️ No running instances, disabling runtime alerts for region \(region)")
                try await setRuntimeAlerts(enabled: false, region: region)
                
                // Post notification for UI update
                NotificationCenter.default.post(
                    name: NSNotification.Name("RuntimeAlertsDisabled"),
                    object: region
                )
            }
        } catch {
            print("❌ Failed to check instance states: \(error)")
        }
    }
    
    deinit {
        listenerRegistration?.remove()
    }
} 