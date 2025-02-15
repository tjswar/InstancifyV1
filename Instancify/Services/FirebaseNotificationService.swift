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
            print("✅ Already authenticated with Firebase")
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
            
            // Create a unique document ID that includes region and instance info
            let documentId = "\(region)_\(instanceId)_\(runtime)"
            
            // Get the alert configuration to check if it's global
            let settings = NotificationSettingsViewModel.shared
            let alerts = settings.getAlertsForRegion(region)
            let matchingAlert = alerts.first { alert in
                let threshold = alert.hours * 60 + alert.minutes
                return threshold == runtime
            }
            
            let isGlobal = matchingAlert?.regions.isEmpty ?? false
            let regions = matchingAlert?.regions ?? []
            
            print("\n💾 Creating Firestore document...")
            print("  • Document ID: \(documentId)")
            print("  • Is Global: \(isGlobal)")
            print("  • Regions: \(regions)")
            
            let alertData: [String: Any] = [
                "instanceId": instanceId,
                "instanceName": instanceName,
                "region": region,
                "launchTime": Timestamp(date: launchTime),
                "threshold": runtime,
                "fcmToken": token,
                "scheduledTime": Timestamp(date: triggerDate),
                "created": FieldValue.serverTimestamp(),
                "isGlobal": isGlobal,
                "regions": Array(regions)
            ]
            
            try await db.collection("scheduledAlerts")
                .document(documentId)
                .setData(alertData, merge: true)
            
            print("\n✅ Alert Successfully Scheduled")
            print("----------------------------------------")
            
            // Invalidate cache
            invalidateCache(for: region)
            print("🔄 Cache invalidated for region: \(region)")
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
                    "instanceId": alert.instanceId,
                    "instanceName": alert.instanceName,
                    "region": alert.region,
                    "launchTime": Timestamp(date: alert.launchTime),
                    "threshold": alert.threshold,
                    "fcmToken": token,
                    "scheduledTime": Timestamp(date: alert.scheduledTime),
                    "created": FieldValue.serverTimestamp(),
                    "isGlobal": alert.regions.isEmpty,
                    "regions": Array(alert.regions)
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
        
        let fcmToken = try await getFCMToken()
        
        let notificationData: [String: Any] = [
            "token": fcmToken,
            "notification": [
                "title": title,
                "body": body
            ],
            "data": data ?? [:],
            "apns": [
                "payload": [
                    "aps": [
                        "sound": "default",
                        "badge": 1
                    ]
                ]
            ]
        ]
        
        // Create a callable Cloud Function
        let functions = Functions.functions()
        let sendNotification = functions.httpsCallable("sendNotification")
        
        do {
            let result = try await sendNotification.call(notificationData)
            print("✅ Push notification sent via Cloud Function")
            print("  • Result: \(String(describing: result.data))")
            } catch {
            print("❌ Failed to send notification: \(error.localizedDescription)")
            throw error
        }
        print("----------------------------------------")
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
    
    private func initializeFirebase() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase initialized")
        }
        
        if Auth.auth().currentUser == nil {
            print("🔐 Starting anonymous auth...")
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
