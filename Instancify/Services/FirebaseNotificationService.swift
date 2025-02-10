import Foundation
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import UIKit
import BackgroundTasks
import Security
import CommonCrypto
import AWSEC2

// Import EC2Instance to get access to InstanceState
@testable import Instancify

// MARK: - JWT Implementation
private enum JWTError: LocalizedError {
    case invalidKey(String)
    case signatureFailure(String)
    case encodingFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidKey(let message): return "Invalid key: \(message)"
        case .signatureFailure(let message): return "Signature failure: \(message)"
        case .encodingFailure(let message): return "Encoding failure: \(message)"
        }
    }
}

// MARK: - Debug Helpers

extension FirebaseNotificationService {
    private func debugNotification(_ userInfo: [AnyHashable: Any], function: String = #function) {
        // Only log in debug builds
        #if DEBUG
        if let type = userInfo["type"] as? String,
           let instanceId = userInfo["instanceId"] as? String {
            print("[FCM] Received notification: type=\(type), instanceId=\(instanceId)")
        }
        #endif
    }
}

// Define the RemoteMessage struct for FCM payload
struct RemoteMessage: Codable {
    struct FCMNotification: Codable {
        let title: String
        let body: String
    }
    
    let notification: FCMNotification
    let data: [String: String]?
}

// Rename to avoid conflict with InstanceMonitoringService
struct FCMInstanceAlert: Codable {
    let instanceId: String
    let region: String
    let name: String
    let launchTime: Date
    let runtimeThreshold: Int  // User-defined threshold in minutes
    let lastNotifiedRuntime: Int  // Last runtime when notification was sent
    let instanceState: String  // Current state of the instance
}

@MainActor
class FirebaseNotificationService: NSObject {
    static let shared = FirebaseNotificationService()
    private var fcmToken: String? {
        didSet {
            if let token = fcmToken {
                print("📱 FCM token updated: \(token)")
                UserDefaults.standard.set(token, forKey: "FCMToken")
            }
        }
    }
    private var isConfigured = false
    
    // Track subscribed topics per region
    private var subscribedTopics: [String: Set<String>] = [:]
    
    override private init() {
        super.init()
        // Try to restore token from UserDefaults
        fcmToken = UserDefaults.standard.string(forKey: "FCMToken")
        setupFirebase()
    }
    
    private func setupFirebase() {
        guard !isConfigured else { return }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // Set messaging delegate immediately
        Messaging.messaging().delegate = self
        isConfigured = true
    }
    
    private func refreshFCMToken() async {
        do {
            // Only try to get FCM token if we have APNS token
            if Messaging.messaging().apnsToken != nil {
                let token = try await Messaging.messaging().token()
                self.fcmToken = token
                print("✅ FCM token refreshed: \(token)")
            } else {
                print("⚠️ Waiting for APNS token before requesting FCM token")
            }
        } catch {
            print("❌ Failed to get FCM token: \(error)")
        }
    }
    
    func setupNotifications() async {
        // No need to request permissions here as it's now handled in AppDelegate
        print("📱 Firebase notifications setup complete")
    }
    
    func resubscribeToSavedRegions() async {
        if let savedRegions = UserDefaults.standard.dictionary(forKey: "subscribedRegions") as? [String: [String]] {
            for (region, topics) in savedRegions {
                // Clear existing alerts for this region before resubscribing
                clearAllAlertsForRegion(region)
                
                for topic in topics {
                    await subscribeToTopic(topic, region: region)
                }
            }
        }
    }
    
    func subscribeToRegionTopics(_ region: String) async {
        // Clear existing alerts for this region before subscribing
        clearAllAlertsForRegion(region)
        
        let topics = [
            "instances-\(region)",
            "alerts-\(region)",
            "costs-\(region)"
        ]
        
        for topic in topics {
            await subscribeToTopic(topic, region: region)
        }
        
        subscribedTopics[region] = Set(topics)
        saveSubscribedTopics()
    }
    
    private func subscribeToTopic(_ topic: String, region: String) async {
        do {
            try await Messaging.messaging().subscribe(toTopic: topic)
            if subscribedTopics[region] == nil {
                subscribedTopics[region] = []
            }
            subscribedTopics[region]?.insert(topic)
            saveSubscribedTopics()
        } catch {
            #if DEBUG
            print("[FCM] Failed to subscribe to topic \(topic): \(error)")
            #endif
        }
    }
    
    private func saveSubscribedTopics() {
        // Convert Set to Array for UserDefaults storage
        let topicsDict = subscribedTopics.mapValues { Array($0) }
        UserDefaults.standard.set(topicsDict, forKey: "subscribedRegions")
    }
    
    @MainActor
    func updateToken(_ token: String) {
        self.fcmToken = token
        print("✅ FCM token updated and stored")
    }
    
    func unsubscribeFromRegion(_ region: String) async {
        if let topics = subscribedTopics[region] {
            for topic in topics {
                do {
                    try await Messaging.messaging().unsubscribe(fromTopic: topic)
                } catch {
                    #if DEBUG
                    print("[FCM] Failed to unsubscribe from topic \(topic): \(error)")
                    #endif
                }
            }
            subscribedTopics.removeValue(forKey: region)
            saveSubscribedTopics()
        }
    }
    
    func sendTestNotification() async {
        do {
            try await sendTestPushNotification()
        } catch {
            #if DEBUG
            print("[FCM] Failed to send test notification: \(error)")
            #endif
        }
    }
    
    // MARK: - Push Notifications
    func sendPushNotification(title: String, body: String, data: [String: String]? = nil) async throws {
        guard let token = fcmToken else {
            print("❌ No FCM token available")
            throw NSError(domain: "FirebaseNotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No FCM token available"])
        }
        
        // Load service account
        guard let serviceAccountUrl = Bundle.main.url(forResource: "service-account", withExtension: "json"),
              let serviceAccountData = try? Data(contentsOf: serviceAccountUrl),
              let serviceAccount = try? JSONDecoder().decode(FirebaseServiceAccount.self, from: serviceAccountData) else {
            print("❌ Failed to load service account configuration")
            throw NSError(domain: "FirebaseNotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load service account"])
        }
        
        // Generate JWT claims
        let now = Int(Date().timeIntervalSince1970)
        let claims: [String: Any] = [
            "iss": serviceAccount.clientEmail,
            "sub": serviceAccount.clientEmail,
            "aud": "https://oauth2.googleapis.com/token",
            "iat": now,
            "exp": now + 3600, // 1 hour expiration
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "project_id": "instancify"  // Add project ID to claims
        ]
        
        let header = [
            "alg": "RS256",
            "typ": "JWT"
        ]
        
        // Generate JWT
        let jwt = try JWTSigner.encode(header: header, claims: claims, key: serviceAccount.privateKey)
        
        // Get access token
        let tokenEndpoint = "https://oauth2.googleapis.com/token"
        var tokenRequest = URLRequest(url: URL(string: tokenEndpoint)!)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let tokenBody = [
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": jwt
        ]
        
        tokenRequest.httpBody = tokenBody.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        print("🔑 Requesting access token...")
        print("📝 Token request body: \(String(data: tokenRequest.httpBody!, encoding: .utf8) ?? "")")
        
        let (tokenData, tokenResponse) = try await URLSession.shared.data(for: tokenRequest)
        
        guard let httpTokenResponse = tokenResponse as? HTTPURLResponse else {
            print("❌ Invalid token response type")
            throw NSError(domain: "FirebaseNotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid token response"])
        }
        
        // Print response headers for debugging
        print("📝 Token Response Headers:")
        httpTokenResponse.allHeaderFields.forEach { key, value in
            print("  • \(key): \(value)")
        }
        
        // Try to parse response data
        if let responseStr = String(data: tokenData, encoding: .utf8) {
            print("📄 Token Response Body: \(responseStr)")
        }
        
        if httpTokenResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any] {
                print("❌ Token Error Response: \(errorJson)")
                
                // Extract error details if available
                let errorDescription = (errorJson["error_description"] as? String) ?? (errorJson["error"] as? String) ?? "Unknown error"
                throw NSError(domain: "FirebaseNotificationService", 
                            code: httpTokenResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to get access token: \(errorDescription)"])
            }
            throw NSError(domain: "FirebaseNotificationService",
                        code: httpTokenResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to get access token with status \(httpTokenResponse.statusCode)"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            print("❌ Failed to parse access token from response")
            if let responseStr = String(data: tokenData, encoding: .utf8) {
                print("  • Raw response: \(responseStr)")
            }
            throw NSError(domain: "FirebaseNotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse access token"])
        }
        
        print("✅ Successfully obtained access token")
        
        // Create FCM v1 message
        var messageDict: [String: Any] = [
            "message": [
                "token": token,
                "notification": [
                    "title": title,
                    "body": body
                ],
                "android": [
                    "priority": "high"
                ],
                "apns": [
                    "payload": [
                        "aps": [
                            "sound": "default",
                            "badge": 1,
                            "content-available": 1
                        ]
                    ]
                ]
            ]
        ]
        
        // Add custom data if provided
        if let data = data {
            if var message = messageDict["message"] as? [String: Any] {
                message["data"] = data
                messageDict["message"] = message
            }
        }
        
        // Send FCM v1 request
        let projectId = "instancify" // Use hardcoded project ID
        let fcmEndpoint = "https://fcm.googleapis.com/v1/projects/\(projectId)/messages:send"
        
        print("📤 Sending FCM request to: \(fcmEndpoint)")
        
        var request = URLRequest(url: URL(string: fcmEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: messageDict)
        
        print("📝 FCM request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "")")
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "FirebaseNotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                print("✅ FCM Response: \(json)")
            }
        } else {
            if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                print("❌ FCM Error: \(errorJson)")
            }
            throw NSError(domain: "FirebaseNotificationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "FCM request failed"])
        }
    }
    
    // MARK: - Test Functions
    func sendTestPushNotification() async throws {
        print("\n🔔 Sending test push notification...")
        try await sendPushNotification(
            title: "Test Push Notification",
            body: "This is a test push notification from Instancify",
            data: ["type": "test"]
        )
    }

    private struct JWTSigner {
        static func encode(header: [String: Any], claims: [String: Any], key: String) throws -> String {
            print("\n🔐 Generating JWT...")
            
            // Ensure consistent header ordering by creating a new dictionary
            let orderedHeader = [
                "alg": "RS256",
                "typ": "JWT"
            ]
            
            print("📝 Header: \(orderedHeader)")
            print("📝 Claims: \(claims)")
            
            // Convert header and claims to base64
            let headerData = try JSONSerialization.data(withJSONObject: orderedHeader, options: [.sortedKeys])
            let claimsData = try JSONSerialization.data(withJSONObject: claims, options: [.sortedKeys])
            
            let headerBase64 = base64URLEncode(headerData)
            let claimsBase64 = base64URLEncode(claimsData)
            
            print("✅ Base64 encoded header: \(headerBase64)")
            print("✅ Base64 encoded claims: \(claimsBase64)")
            
            // Create signing input
            let signingInput = "\(headerBase64).\(claimsBase64)"
            print("✅ Signing input created: \(signingInput)")
            
            // Convert PEM key to SecKey
            let privateKey = try convertPEMToDER(pemKey: key)
            print("✅ Successfully created SecKey from private key data")
            
            // Sign the input
            guard let signature = sign(input: signingInput, with: privateKey) else {
                print("❌ Failed to create signature")
                throw JWTError.signatureFailure("Failed to create signature")
            }
            
            let signatureBase64 = base64URLEncode(signature)
            print("✅ Successfully created signature")
            print("📝 Base64 encoded signature: \(signatureBase64)")
            
            // Combine all parts
            let jwt = "\(signingInput).\(signatureBase64)"
            print("✅ Generated JWT: \(jwt)")
            
            return jwt
        }
        
        private static func sign(input: String, with key: SecKey) -> Data? {
            guard let inputData = input.data(using: .utf8) else {
                print("❌ Failed to encode input string as UTF-8")
                return nil
            }
            
            var error: Unmanaged<CFError>?
            guard let signature = SecKeyCreateSignature(key,
                                                      .rsaSignatureMessagePKCS1v15SHA256,
                                                      inputData as CFData,
                                                      &error) as Data? else {
                if let error = error?.takeRetainedValue() {
                    print("❌ Failed to create signature: \(error.localizedDescription)")
                }
                return nil
            }
            
            print("✅ Successfully created signature")
            return signature
        }
        
        private static func convertPEMToDER(pemKey: String) throws -> SecKey {
            print("\n🔑 Converting PEM to DER format...")
            
            // First, normalize newlines and handle escaped newlines from JSON
            var normalizedKey = pemKey
                .replacingOccurrences(of: "\\n", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Ensure the key has proper PEM format
            if !normalizedKey.contains("-----BEGIN PRIVATE KEY-----") {
                print("⚠️ Adding PEM headers as they were not found")
                normalizedKey = "-----BEGIN PRIVATE KEY-----\n\(normalizedKey)\n-----END PRIVATE KEY-----"
            }
            
            // Extract base64 content
            let privateKeyPattern = "-----BEGIN PRIVATE KEY-----\n(.+)\n-----END PRIVATE KEY-----"
            guard let regex = try? NSRegularExpression(pattern: privateKeyPattern, options: .dotMatchesLineSeparators),
                  let match = regex.firstMatch(in: normalizedKey, options: [], range: NSRange(normalizedKey.startIndex..., in: normalizedKey)),
                  let keyRange = Range(match.range(at: 1), in: normalizedKey) else {
                print("❌ Failed to extract base64 content using regex")
                throw JWTError.invalidKey("Failed to extract base64 content")
            }
            
            let cleanKey = String(normalizedKey[keyRange])
                .components(separatedBy: .whitespacesAndNewlines)
                .joined()
            
            // Decode base64
            guard let keyData = Data(base64Encoded: cleanKey, options: .ignoreUnknownCharacters) else {
                print("❌ Failed to decode base64 key data")
                throw JWTError.invalidKey("Failed to decode base64 key data")
            }
            
            print("✅ Successfully decoded base64 key data (\(keyData.count) bytes)")
            
            // Print first few bytes for debugging
            let previewBytes = Array(keyData.prefix(16))
            print("📝 First 16 bytes of key: \(previewBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
            
            // Extract RSA key from PKCS#8 structure
            // Skip the PKCS#8 header (26 bytes) to get to the RSA key data
            let rsaKeyData = keyData.dropFirst(26)
            print("📝 Extracted RSA key data (\(rsaKeyData.count) bytes)")
            print("📝 First 16 bytes of RSA key: \(Array(rsaKeyData.prefix(16)).map { String(format: "%02x", $0) }.joined(separator: " "))")
            
            // Create key attributes
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                kSecAttrKeySizeInBits as String: 2048,
                kSecAttrIsPermanent as String: false
            ]
            
            // Try to create the key
            var error: Unmanaged<CFError>?
            guard let key = SecKeyCreateWithData(rsaKeyData as CFData,
                                               attributes as CFDictionary,
                                               &error) else {
                if let cfError = error?.takeRetainedValue() {
                    print("❌ Failed to create key: \(cfError)")
                    if let details = CFErrorCopyUserInfo(cfError) as? [String: Any] {
                        print("Error details: \(details)")
                    }
                }
                throw JWTError.invalidKey("Failed to create key from RSA key data")
            }
            
            // Verify the key can be used for signing
            let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
            guard SecKeyIsAlgorithmSupported(key, .sign, algorithm) else {
                print("❌ Key does not support RSA-SHA256 signing")
                throw JWTError.invalidKey("Key does not support required signing algorithm")
            }
            
            print("✅ Successfully created RSA private key")
            return key
        }
        
        private static func base64URLEncode(_ data: Data) -> String {
            let base64 = data.base64EncodedString()
            return base64
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "") // Remove padding
        }
    }
    
    // MARK: - Instance State Notifications
    func sendInstanceStateNotification(instanceId: String, instanceName: String?, state: InstanceState) async throws {
        let name = instanceName ?? instanceId
        var title = "Instance Status"
        var body = ""
        var type = ""
        
        switch state {
        case .pending:
            body = "Instance '\(name)' is starting up"
            type = "instance_starting"
        case .running:
            body = "Instance '\(name)' is now running"
            type = "instance_running"
        case .stopping:
            body = "Instance '\(name)' is stopping"
            type = "instance_stopping"
        case .stopped:
            body = "Instance '\(name)' has stopped"
            type = "instance_stopped"
        case .shuttingDown:
            body = "Instance '\(name)' is shutting down"
            type = "instance_shutting_down"
        case .terminated:
            body = "Instance '\(name)' has been terminated"
            type = "instance_terminated"
        case .unknown:
            body = "Instance '\(name)' is in an unknown state"
            type = "instance_unknown"
        }
        
        let timestamp = Date().timeIntervalSince1970
        let data: [String: String] = [
            "type": type,
            "instanceId": instanceId,
            "timestamp": String(timestamp),
            "state": state.rawValue
        ]
        
        try await sendPushNotification(
            title: title,
            body: body,
            data: data
        )
        print("✅ [\(instanceId)] Push notification sent: \(title)")
    }
    
    // MARK: - Cost Alert Notifications
    func sendCostAlert(instanceId: String, instanceName: String?, cost: Double, currency: String = "USD") async throws {
        let name = instanceName ?? instanceId
        let formattedCost = String(format: "%.2f", cost)
        let title = "Cost Alert"
        let body = "Instance '\(name)' has accumulated cost of \(currency) \(formattedCost)"
        
        let timestamp = Date().timeIntervalSince1970
        let data: [String: String] = [
            "type": "cost_alert",
            "instanceId": instanceId,
            "timestamp": String(timestamp),
            "cost": formattedCost,
            "currency": currency
        ]
        
        try await sendPushNotification(
            title: title,
            body: body,
            data: data
        )
        print("✅ [\(instanceId)] Cost alert sent: \(formattedCost) \(currency)")
    }
    
    // MARK: - Runtime Alert Notifications
    func sendRuntimeAlert(instanceId: String, instanceName: String?, runtime: Int, region: String) async throws {
        let name = instanceName ?? instanceId
        let title = "Runtime Alert"
        let body = "Instance '\(name)' has been running for \(runtime) minutes"
        
        let timestamp = Date().timeIntervalSince1970
        let data: [String: String] = [
            "type": "runtime_alert",
            "instanceId": instanceId,
            "instanceName": name,
            "timestamp": String(timestamp),
            "runtime": String(runtime),
            "region": region
        ]
        
        try await sendPushNotification(
            title: title,
            body: body,
            data: data
        )
        print("✅ [\(instanceId)] Runtime alert sent: \(runtime) minutes in region \(region)")
    }
    
    // MARK: - Error Notifications
    func sendErrorNotification(instanceId: String, instanceName: String?, error: String) async throws {
        let name = instanceName ?? instanceId
        let title = "Instance Error"
        let body = "Error with instance '\(name)': \(error)"
        
        let timestamp = Date().timeIntervalSince1970
        let data: [String: String] = [
            "type": "instance_error",
            "instanceId": instanceId,
            "timestamp": String(timestamp),
            "error": error
        ]
        
        try await sendPushNotification(
            title: title,
            body: body,
            data: data
        )
        print("✅ [\(instanceId)] Error notification sent: \(error)")
    }
    
    func handleReceivedNotification(_ userInfo: [AnyHashable: Any]) {
        debugNotification(userInfo)
        
        guard let type = userInfo["type"] as? String,
              let instanceId = userInfo["instanceId"] as? String else {
            #if DEBUG
            print("[FCM] Missing required notification data")
            #endif
            return
        }
        
        switch type {
        case "runtime_alert":
            handleRuntimeAlert(instanceId: instanceId, userInfo: userInfo)
            
        case "auto_stop":
            handleAutoStopAlert(instanceId: instanceId, userInfo: userInfo)
            
        case "instance_error":
            handleErrorNotification(instanceId: instanceId, userInfo: userInfo)
            
        default:
            #if DEBUG
            print("[FCM] Skipping notification type: \(type)")
            #endif
        }
    }
    
    private func handleAutoStopAlert(instanceId: String, userInfo: [AnyHashable: Any]) {
        guard let scheduledTime = userInfo["scheduledTime"] as? String,
              let instanceName = userInfo["instanceName"] as? String else { return }
        
        NotificationCenter.default.post(
            name: .instanceAutoStopAlert,
            object: nil,
            userInfo: [
                "instanceId": instanceId,
                "instanceName": instanceName,
                "scheduledTime": scheduledTime
            ]
        )
    }
    
    private func handleRuntimeAlert(instanceId: String, userInfo: [AnyHashable: Any]) {
        guard let runtime = userInfo["runtime"] as? String,
              let instanceName = userInfo["instanceName"] as? String,
              let region = userInfo["region"] as? String else { return }
        
        NotificationCenter.default.post(
            name: .instanceRuntimeAlert,
            object: nil,
            userInfo: [
                "instanceId": instanceId,
                "instanceName": instanceName,
                "runtime": runtime,
                "region": region
            ]
        )
    }
    
    private func handleErrorNotification(instanceId: String, userInfo: [AnyHashable: Any]) {
        guard let error = userInfo["error"] as? String,
              let instanceName = userInfo["instanceName"] as? String else { return }
        
        NotificationCenter.default.post(
            name: .instanceError,
            object: nil,
            userInfo: [
                "instanceId": instanceId,
                "instanceName": instanceName,
                "error": error
            ]
        )
    }
}

// MARK: - MessagingDelegate
extension FirebaseNotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("\n📱 Firebase registration token: \(fcmToken ?? "nil")")
        self.fcmToken = fcmToken
        
        // Resubscribe to saved regions when token is refreshed
        if fcmToken != nil {
            Task {
                await resubscribeToSavedRegions()
            }
        }
    }
}

// MARK: - Instance Runtime Monitoring
extension FirebaseNotificationService {
    func handleInstanceRuntimeAlert(instanceId: String, region: String, name: String, launchTime: Date, runtimeThreshold: Int, instanceState: String) async {
        // Skip if instance is not running
        guard instanceState == InstanceState.running.rawValue else {
            #if DEBUG
            print("[FCM] Skipping runtime alert for \(instanceId) - instance is not running (state: \(instanceState))")
            #endif
            return
        }
        
        let currentTime = Date()
        let runtime = Int(currentTime.timeIntervalSince(launchTime) / 60)
        
        // Use region-specific key for alerts
        let defaults = UserDefaults(suiteName: "group.tech.md.Instancify")
        let key = "instance_alerts_\(region)_\(instanceId)"
        
        // Load or create alert data
        var alert: FCMInstanceAlert
        if let data = defaults?.data(forKey: key),
           let savedAlert = try? JSONDecoder().decode(FCMInstanceAlert.self, from: data) {
            // Check if instance state has changed
            if savedAlert.instanceState != instanceState {
                // Instance state changed, reset notification state
                alert = FCMInstanceAlert(
                    instanceId: instanceId,
                    region: region,
                    name: name,
                    launchTime: launchTime,
                    runtimeThreshold: runtimeThreshold,
                    lastNotifiedRuntime: 0,
                    instanceState: instanceState
                )
            } else {
                alert = savedAlert
            }
        } else {
            alert = FCMInstanceAlert(
                instanceId: instanceId,
                region: region,
                name: name,
                launchTime: launchTime,
                runtimeThreshold: runtimeThreshold,
                lastNotifiedRuntime: 0,
                instanceState: instanceState
            )
        }
        
        // Only send alert if:
        // 1. Instance is running
        // 2. Current runtime is >= threshold
        // 3. We haven't sent an alert for this threshold yet
        // 4. Last notification was sent more than threshold minutes ago
        if runtime >= runtimeThreshold && 
           alert.lastNotifiedRuntime < runtime &&
           (runtime - alert.lastNotifiedRuntime) >= runtimeThreshold {
            do {
                try await sendRuntimeAlert(
                    instanceId: instanceId,
                    instanceName: name,
                    runtime: runtime,
                    region: region
                )
                
                // Update alert with new notification time
                alert = FCMInstanceAlert(
                    instanceId: instanceId,
                    region: region,
                    name: name,
                    launchTime: launchTime,
                    runtimeThreshold: runtimeThreshold,
                    lastNotifiedRuntime: runtime,
                    instanceState: instanceState
                )
                
                if let encoded = try? JSONEncoder().encode(alert) {
                    defaults?.set(encoded, forKey: key)
                    defaults?.synchronize()
                }
            } catch {
                #if DEBUG
                print("[FCM] Failed to send runtime alert for instance \(instanceId) in region \(region): \(error)")
                #endif
            }
        }
    }
    
    func clearAllAlertsForRegion(_ region: String) {
        let defaults = UserDefaults(suiteName: "group.tech.md.Instancify")
        if let allKeys = defaults?.dictionaryRepresentation().keys {
            let regionKeys = allKeys.filter { $0.contains("instance_alerts_\(region)_") }
            for key in regionKeys {
                defaults?.removeObject(forKey: key)
            }
            defaults?.synchronize()
        }
        #if DEBUG
        print("✅ Cleared all runtime alerts for region \(region)")
        #endif
    }
    
    func clearInstanceAlerts(instanceId: String, region: String? = nil) {
        let defaults = UserDefaults(suiteName: "group.tech.md.Instancify")
        
        if let region = region {
            // Clear alerts for specific region
            let key = "instance_alerts_\(region)_\(instanceId)"
            defaults?.removeObject(forKey: key)
            #if DEBUG
            print("✅ Cleared runtime alerts for instance \(instanceId) in region \(region)")
            #endif
        } else {
            // Clear alerts for all regions
            if let allKeys = defaults?.dictionaryRepresentation().keys {
                let instanceKeys = allKeys.filter { $0.contains("instance_alerts_") && $0.contains(instanceId) }
                for key in instanceKeys {
                    defaults?.removeObject(forKey: key)
                }
            }
            #if DEBUG
            print("✅ Cleared all runtime alerts for instance \(instanceId)")
            #endif
        }
        defaults?.synchronize()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let instanceAutoStopAlert = Notification.Name("instanceAutoStopAlert")
    static let instanceRuntimeAlert = Notification.Name("instanceRuntimeAlert")
    static let instanceError = Notification.Name("instanceError")
    static let instanceStateChanged = Notification.Name("instanceStateChanged")
}

// MARK: - Auto-Stop Notifications
extension FirebaseNotificationService {
    func sendAutoStopAlert(instanceId: String, instanceName: String?, scheduledTime: Date) async throws {
        let name = instanceName ?? instanceId
        let title = "Auto-Stop Scheduled"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        let formattedTime = dateFormatter.string(from: scheduledTime)
        let body = "Instance '\(name)' is scheduled to stop at \(formattedTime)"
        
        let timestamp = Date().timeIntervalSince1970
        let data: [String: String] = [
            "type": "auto_stop",
            "instanceId": instanceId,
            "instanceName": name,
            "timestamp": String(timestamp),
            "scheduledTime": String(scheduledTime.timeIntervalSince1970)
        ]
        
        try await sendPushNotification(
            title: title,
            body: body,
            data: data
        )
        #if DEBUG
        print("[FCM] Auto-stop alert sent for instance \(name)")
        #endif
    }
}
