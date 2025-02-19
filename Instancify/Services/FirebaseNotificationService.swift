import Foundation
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

enum NotificationError: Error {
    case noFCMToken
    case schedulingFailed
    case clearingFailed
    case authenticationFailed
    case fcmTokenNotFound
    case invalidData
    case networkError
}

@MainActor
class FirebaseNotificationService {
    static let shared = FirebaseNotificationService()
    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private var alertCache: [String: [RuntimeAlert]] = [:]
    private var lastCacheUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    private init() {
        initializeFirebase()
    }
    
    private func signInAnonymously() async throws {
        // Only sign in if not already authenticated
        if Auth.auth().currentUser == nil {
            print("\n🔐 Signing in anonymously to Firebase...")
            do {
                let result = try await Auth.auth().signInAnonymously()
                print("✅ Anonymous auth successful. User ID: \(result.user.uid)")
                
                // Get ID token for Cloud Functions authentication
                let idToken = try await result.user.getIDToken()
                print("✅ Got ID token for Cloud Functions authentication")
            } catch let error as NSError {
                print("❌ Anonymous auth failed with code: \(error.code)")
                print("❌ Error domain: \(error.domain)")
                print("❌ Error description: \(error.localizedDescription)")
                print("❌ Full error details: \(error)")
                
                // Check if Firebase is properly configured
                if error.domain == "FIRAuthErrorDomain" {
                    switch error.code {
                    case 17999: // Internal error
                        print("⚠️ Firebase configuration issue. Please check GoogleService-Info.plist")
                    case 17005: // Operation not allowed
                        print("⚠️ Anonymous authentication is not enabled in Firebase Console")
                    default:
                        print("⚠️ Unhandled Firebase auth error code: \(error.code)")
                    }
                }
                
                throw NotificationError.authenticationFailed
            }
        } else {
            // Refresh token if already authenticated
            if let user = Auth.auth().currentUser {
                _ = try await user.getIDToken(forcingRefresh: true)
                print("✅ Refreshed ID token for existing user")
            }
        }
    }
    
    func requestAuthorization() async throws -> Bool {
        // Ensure Firebase Authentication
        try await signInAnonymously()
        
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        guard settings.authorizationStatus != .authorized else {
            return true
        }
        
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        return granted
    }
    
    private func getFCMToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            Messaging.messaging().token { token, error in
                if let error = error {
                    print("❌ FCM Token Error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let token = token else {
                    continuation.resume(throwing: NotificationError.fcmTokenNotFound)
                    return
                }
                
                print("\n📱 FCM Token:")
                print("----------------------------------------")
                print(token)
                print("----------------------------------------\n")
                continuation.resume(returning: token)
            }
        }
    }
    
    func scheduleRuntimeAlert(
        instanceId: String,
        instanceName: String,
        runtime: Int,
        region: String,
        triggerDate: Date,
        launchTime: Date
    ) async throws {
        print("\n📝 Scheduling Runtime Alert")
        print("----------------------------------------")
        print("📊 Alert Details:")
        print("  • Instance: \(instanceName) (\(instanceId))")
        print("  • Region: \(region)")
        print("  • Runtime: \(runtime) minutes")
        print("  • Launch Time: \(launchTime)")
        print("  • Trigger Date: \(triggerDate)")
        
        do {
            // Ensure Firebase Authentication
            try await signInAnonymously()
            
            // Get FCM token
            print("\n🔑 Retrieving FCM token...")
            let token = try await Messaging.messaging().token()
            
            // Create a unique document ID
            let documentId = "\(region)_\(instanceId)_\(runtime)"
            
            print("\n💾 Creating Firestore document...")
            print("  • Document ID: \(documentId)")
            
            let alertData: [String: Any] = [
                "instanceID": instanceId,
                "instanceName": instanceName,
                "region": region,
                "launchTime": Timestamp(date: launchTime),
                "threshold": runtime,
                "fcmToken": token,
                "scheduledTime": Timestamp(date: triggerDate),
                "status": "pending",
                "notificationSent": false
            ]
            
            try await db.collection("scheduledAlerts")
                .document(documentId)
                .setData(alertData)
            
            print("\n✅ Alert Successfully Scheduled")
            print("----------------------------------------")
            
        } catch let error as NSError {
            print("\n❌ Failed to schedule runtime alert:")
            print("  • Error Domain: \(error.domain)")
            print("  • Error Code: \(error.code)")
            print("  • Description: \(error.localizedDescription)")
            print("----------------------------------------")
            throw error
        }
    }
    
    func batchScheduleRuntimeAlerts(_ alerts: [RuntimeAlert]) async throws {
        print("\n📝 Batch Scheduling Runtime Alerts")
        print("----------------------------------------")
        print("📊 Processing \(alerts.count) alerts")
        
        do {
            // Ensure Firebase Authentication
            try await signInAnonymously()
            
            // Get FCM token once for all alerts
            print("\n🔑 Retrieving FCM token...")
            let token = try await getFCMToken()
            
            print("\n💾 Creating batch operation...")
            let batch = db.batch()
            var affectedRegions = Set<String>()
            
            for (index, alert) in alerts.enumerated() {
                print("\n📄 Processing alert \(index + 1) of \(alerts.count)")
                
                // Create a unique document ID that includes region and instance info
                let documentId = "\(alert.region)_\(alert.instanceId)_\(alert.threshold)"
                
                let alertData: [String: Any] = [
                    "instanceID": alert.instanceId,
                    "instanceName": alert.instanceName,
                    "region": alert.region,
                    "launchTime": Timestamp(date: alert.launchTime),
                    "threshold": alert.threshold,
                    "fcmToken": token,
                    "scheduledTime": Timestamp(date: alert.scheduledTime),
                    "createdAt": FieldValue.serverTimestamp(),
                    "isGlobal": alert.regions.isEmpty,
                    "regions": Array(alert.regions),
                    "type": "runtime_alert",
                    "status": "pending",
                    "notificationSent": false,
                    "deleted": false,
                    "instanceState": "running"
                ]
                
                // Use setData with merge option to handle existing documents
                batch.setData(
                    alertData,
                    forDocument: db.collection("scheduledAlerts").document(documentId),
                    merge: true
                )
                
                print("  ✓ Alert \(index + 1) added to batch")
                affectedRegions.insert(alert.region)
            }
            
            print("\n📤 Committing batch to Firestore...")
            try await batch.commit()
            print("✅ Batch operation completed successfully")
            
            // Invalidate cache for affected regions
            for region in affectedRegions {
                invalidateCache(for: region)
            }
            print("🔄 Cache invalidated for regions: \(affectedRegions.joined(separator: ", "))")
            print("----------------------------------------")
            
        } catch let error as NSError {
            print("\n❌ Failed to schedule runtime alerts:")
            print("  • Error Domain: \(error.domain)")
            print("  • Error Code: \(error.code)")
            print("  • Description: \(error.localizedDescription)")
            print("----------------------------------------")
            throw error
        }
    }
    
    func clearInstanceAlerts(instanceId: String, region: String? = nil) async throws {
        print("\n🗑️ Clearing alerts for instance \(instanceId)")
        print("  • Region: \(region ?? "all")")
        
        let alertsRef = db.collection("scheduledAlerts")
        var query: Query = alertsRef.whereField("instanceId", isEqualTo: instanceId)
        
        if let region = region {
            query = query.whereField("region", isEqualTo: region)
        }
        
        let snapshot = try await query.getDocuments()
        
        if snapshot.documents.isEmpty {
            print("  • No alerts found to clear")
            return
        }
        
        print("  • Found \(snapshot.documents.count) alerts to clear")
        
        let batch = db.batch()
        snapshot.documents.forEach { doc in
            print("  • Deleting alert: \(doc.documentID)")
            batch.deleteDocument(doc.reference)
        }
        
        try await batch.commit()
        print("✅ Successfully cleared alerts")
        
        // Invalidate cache for affected region
        if let region = region {
            invalidateCache(for: region)
        } else {
            alertCache.removeAll()
        }
    }
    
    func getAlertsForRegion(_ region: String) async throws -> [RuntimeAlert] {
        // Check cache first
        if let cached = alertCache[region], 
           let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheValidityDuration {
            return cached
        }
        
        // Query for both region-specific and global alerts
        let snapshot = try await db.collection("scheduledAlerts")
            .whereField("region", isEqualTo: region)
            .getDocuments()
        
        let globalSnapshot = try await db.collection("scheduledAlerts")
            .whereField("isGlobal", isEqualTo: true)
            .getDocuments()
        
        // Combine and process alerts
        let allDocs = snapshot.documents + globalSnapshot.documents
        let alerts = allDocs.compactMap { doc -> RuntimeAlert? in
            guard let data = doc.data() as? [String: Any],
                  let instanceId = data["instanceId"] as? String,
                  let instanceName = data["instanceName"] as? String,
                  let threshold = data["threshold"] as? Int,
                  let launchTime = (data["launchTime"] as? Timestamp)?.dateValue(),
                  let scheduledTime = (data["scheduledTime"] as? Timestamp)?.dateValue() else {
                return nil
            }
            
            return RuntimeAlert(
                id: doc.documentID,
                instanceId: instanceId,
                instanceName: instanceName,
                region: region,
                threshold: threshold,
                launchTime: launchTime,
                scheduledTime: scheduledTime,
                enabled: true,
                regions: Set(data["regions"] as? [String] ?? [])
            )
        }
        
        // Update cache
        alertCache[region] = alerts
        lastCacheUpdate = Date()
        
        return alerts
    }
    
    private func invalidateCache(for region: String) {
        alertCache.removeValue(forKey: region)
    }
    
    func clearRuntimeAlerts(instanceId: String, region: String? = nil) async throws {
        try await clearInstanceAlerts(instanceId: instanceId, region: region)
    }
    
    func sendPushNotification(title: String, body: String, data: [String: String]? = nil) async throws {
        print("\n📱 Sending Push Notification")
        print("----------------------------------------")
        print("📊 Notification Details:")
        print("  • Title: \(title)")
        print("  • Body: \(body)")
        if let data = data {
            print("  • Data: \(data)")
        }
        
        // Add retry logic
        let maxRetries = 3
        var lastError: Error? = nil
        
        for attempt in 1...maxRetries {
            do {
                let fcmToken = try await getFCMToken()
                
                // Create a mutable copy of the data
                var notificationData = data ?? [:]
                
                // Add timestamp if not present
                if notificationData["timestamp"] == nil {
                    notificationData["timestamp"] = "\(Date().timeIntervalSince1970)"
                }
                
                // Add region if not present
                if notificationData["region"] == nil {
                    // Try to get region, but don't fail if we can't
                    if let region = try? await KeychainManager.shared.getRegion() {
                        notificationData["region"] = region
                    }
                }
                
                // For auto-stop alerts, ensure we have all required fields
                if notificationData["type"] == "auto_stop_warning" {
                    if notificationData["secondsRemaining"] == nil,
                       let timeString = notificationData["timestamp"],
                       let stopTimeString = notificationData["stopTime"],
                       let timestamp = Double(timeString),
                       let stopTime = Double(stopTimeString) {
                        let secondsRemaining = Int(stopTime - timestamp)
                        notificationData["secondsRemaining"] = "\(secondsRemaining)"
                    }
                }
                
                let message: [String: Any] = [
                    "token": fcmToken,
                    "title": title,
                    "body": body,
                    "data": notificationData
                ]
                
                // Create a callable Cloud Function
                let functions = Functions.functions()
                let sendNotification = functions.httpsCallable("sendNotificationFunction")
                
                let result = try await sendNotification.call(message)
                print("✅ Push notification sent via Cloud Function")
                print("  • Result: \(String(describing: result.data))")
                print("----------------------------------------")
                
                // Store in Firestore
                await storeNotificationInHistory(title: title, body: body, data: notificationData)
                
                return
                
            } catch let error {
                lastError = error
                print("⚠️ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // Wait before retrying (exponential backoff)
                    let delay = TimeInterval(pow(2.0, Double(attempt - 1)))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    print("🔄 Retrying... (Attempt \(attempt + 1) of \(maxRetries))")
                    continue
                }
            }
        }
        
        // If we get here, all retries failed
        if let error = lastError {
            print("❌ All notification attempts failed")
            // Store notification in Firestore for later delivery
            await storeFailedNotification(title: title, body: body, data: data)
            // Don't throw the error to prevent the "unableToRetrieve" message
            print("ℹ️ Notification will be delivered when connection is restored")
        }
    }
    
    private func storeNotificationInHistory(title: String, body: String, data: [String: String]) async {
        do {
            let db = Firestore.firestore()
            let notificationRef = db.collection("notificationHistory").document()
            
            var firestoreData: [String: Any] = [
                "timestamp": FieldValue.serverTimestamp(),
                "title": title,
                "body": body
            ]
            
            // Add all data fields
            for (key, value) in data {
                firestoreData[key] = value
            }
            
            try await notificationRef.setData(firestoreData)
            print("✅ Notification saved to history")
        } catch {
            print("⚠️ Error saving to notification history: \(error.localizedDescription)")
        }
    }
    
    private func storeFailedNotification(_ notification: [String: Any]) async {
        do {
            let docRef = db.collection("failedNotifications").document()
            try await docRef.setData([
                "notification": notification,
                "timestamp": FieldValue.serverTimestamp(),
                "attempts": 0,
                "status": "pending"
            ])
            print("✅ Failed notification stored for later delivery")
        } catch {
            print("⚠️ Could not store failed notification: \(error.localizedDescription)")
        }
    }
    
    private func storeFailedNotification(title: String, body: String, data: [String: String]?) async {
        let notification: [String: Any] = [
            "title": title,
            "body": body,
            "data": data ?? [:],
            "createdAt": FieldValue.serverTimestamp()
        ]
        await storeFailedNotification(notification)
    }
    
    func sendInstanceStateNotification(instanceId: String, instanceName: String, oldState: String, newState: String) async throws {
        let title = "Instance State Changed"
        let body = "\(instanceName) state changed from \(oldState) to \(newState)"
        
        let data: [String: String] = [
            "type": "state_change",
            "instanceId": instanceId,
            "instanceName": instanceName,
            "oldState": oldState,
            "newState": newState
        ]
        
        try await sendPushNotification(title: title, body: body, data: data)
    }
    
    func sendErrorNotification(instanceId: String, error: Error) async throws {
        let title = "Instance Error"
        let body = "An error occurred: \(error.localizedDescription)"
        
        let data: [String: String] = [
            "type": "error",
            "instanceId": instanceId,
            "errorDescription": error.localizedDescription
        ]
        
        try await sendPushNotification(title: title, body: body, data: data)
    }
    
    func handleInstanceStateChange(instanceId: String, instanceName: String, region: String, oldState: String, newState: String, launchTime: Date?) async throws {
        print("\n🔄 Calling handleInstanceStateChange function")
        print("  • Instance: \(instanceName) (\(instanceId))")
        print("  • Region: \(region)")
        print("  • State Change: \(oldState) -> \(newState)")
        print("  • Launch Time: \(launchTime?.description ?? "N/A")")

        // Ensure Firebase Authentication
        try await signInAnonymously()

        // Create a callable Cloud Function
        let handleStateChange = functions.httpsCallable("handleInstanceStateChange")

        var data: [String: Any] = [
            "instanceId": instanceId,
            "instanceName": instanceName,
            "region": region,
            "oldState": oldState,
            "newState": newState.lowercased()  // Ensure state is lowercase to match Firebase expectations
        ]
        
        if let launchTime = launchTime {
            data["launchTime"] = launchTime
        }

        print("📤 Sending data to Firebase:")
        print("  • Instance ID: \(instanceId)")
        print("  • Region: \(region)")
        print("  • New State: \(newState.lowercased())")

        let result = try await handleStateChange.call(data)
        print("✅ Instance state change handled by Firebase")
        print("  • Result: \(String(describing: result.data))")
        
        // Post notification to update UI
        NotificationCenter.default.post(
            name: NSNotification.Name("InstanceStateChanged"),
            object: ["instanceId": instanceId, "region": region, "state": newState]
        )
    }
    
    private func initializeFirebase() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase initialized")
        }
        
        if Auth.auth().currentUser == nil {
            print(" Starting anonymous auth...")
            Auth.auth().signInAnonymously { authResult, error in
                if let error = error {
                    print("❌ Auth failed: \(error)")
                } else {
                    print("✅ Authenticated as: \(authResult?.user.uid ?? "unknown")")
                }
            }
        }
    }
}
