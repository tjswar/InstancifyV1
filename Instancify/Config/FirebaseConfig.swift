import Foundation
import FirebaseCore
import FirebaseMessaging
import CryptoKit
import Security
import Crypto
import _CryptoExtras

struct FirebaseConfig {
    static let projectId = "instancify"
    static let senderId = "133901911087"
    static let serverKey = "AIzaSyBclJrBfo5XMrBYYFbh-rCvIsC2rvyUhzk"
    static let fcmEndpoint = "https://fcm.googleapis.com/fcm/send"
    
    static func generateJWT(using serviceAccount: FirebaseServiceAccount) throws -> String {
        print("\n🔐 Starting JWT generation...")
        print("📧 Using client email: \(serviceAccount.clientEmail)")
        
        let now = Date()
        let header = [
            "alg": "RS256",
            "typ": "JWT"
        ]
        
        let claims = [
            "iss": serviceAccount.clientEmail,
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud": "https://oauth2.googleapis.com/token",
            "exp": Int(now.timeIntervalSince1970) + 3600,
            "iat": Int(now.timeIntervalSince1970)
        ] as [String: Any]
        
        print("📝 JWT Header: \(header)")
        print("📝 JWT Claims: \(claims)")
        
        // Convert header and claims to base64
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let claimsData = try JSONSerialization.data(withJSONObject: claims)
        
        let headerBase64 = base64URLEncode(headerData)
        let claimsBase64 = base64URLEncode(claimsData)
        
        print("📝 Base64 Header: \(headerBase64)")
        print("📝 Base64 Claims: \(claimsBase64)")
        
        // Create signing input
        let signingInput = "\(headerBase64).\(claimsBase64)"
        print("📝 Signing input prepared")
        
        // Convert PEM key to SecKey
        let privateKey = try convertPEMToDER(pemKey: serviceAccount.privateKey)
        print("🔑 Private key converted successfully")
        
        // Sign the input
        guard let signature = sign(input: signingInput, with: privateKey) else {
            print("❌ Failed to create signature")
            throw JWTError.signatureFailure
        }
        
        print("✅ Input signed successfully")
        let signatureBase64 = base64URLEncode(signature)
        
        // Combine all parts
        let jwt = "\(signingInput).\(signatureBase64)"
        print("✅ JWT generated successfully")
        
        return jwt
    }
    
    static func getAccessToken(jwt: String) async throws -> String {
        print("\n🔑 Getting access token...")
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"
        request.httpBody = body.data(using: .utf8)
        
        print("📤 Sending token request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw JWTError.invalidResponse
        }
        
        print("📥 Response status code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("❌ Error response: \(errorJson)")
            }
            throw JWTError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            print("❌ Failed to parse access token from response")
            throw JWTError.invalidResponse
        }
        
        print("✅ Successfully obtained access token")
        return accessToken
    }
    
    private static func sign(input: String, with key: SecKey) -> Data? {
        guard let inputData = input.data(using: .utf8) else { return nil }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key,
                                                  .rsaSignatureMessagePKCS1v15SHA256,
                                                  inputData as CFData,
                                                  &error) as Data? else {
            return nil
        }
        
        return signature
    }
    
    private static func convertPEMToDER(pemKey: String) throws -> SecKey {
        print("🔑 Processing private key...")
        
        // Normalize newlines and handle escaped newlines from JSON
        var normalizedKey = pemKey
            .replacingOccurrences(of: "\\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure the key has proper PEM format
        if !normalizedKey.contains("-----BEGIN PRIVATE KEY-----") {
            print("⚠️ Adding PEM headers...")
            normalizedKey = "-----BEGIN PRIVATE KEY-----\n\(normalizedKey)\n-----END PRIVATE KEY-----"
        }
        
        print("📝 Key length after normalization: \(normalizedKey.count)")
        
        // Extract base64 content
        let privateKeyPattern = "-----BEGIN PRIVATE KEY-----\n(.+)\n-----END PRIVATE KEY-----"
        guard let regex = try? NSRegularExpression(pattern: privateKeyPattern, options: .dotMatchesLineSeparators),
              let match = regex.firstMatch(in: normalizedKey, options: [], range: NSRange(normalizedKey.startIndex..., in: normalizedKey)),
              let keyRange = Range(match.range(at: 1), in: normalizedKey) else {
            print("❌ Failed to extract key content")
            throw JWTError.invalidKey
        }
        
        let cleanKey = String(normalizedKey[keyRange])
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        
        print("📝 Clean key length: \(cleanKey.count)")
        
        // Decode base64
        guard let keyData = Data(base64Encoded: cleanKey) else {
            print("❌ Failed to decode base64 key data")
            throw JWTError.invalidKey
        }
        
        print("📝 Key data length: \(keyData.count)")
        
        // Extract RSA private key from PKCS#8 structure
        // Skip the first 26 bytes which contain the PKCS#8 wrapper
        let rsaKeyData = keyData.dropFirst(26)
        print("📝 RSA key data length: \(rsaKeyData.count)")
        
        // Create key attributes for RSA key
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048,
            kSecAttrIsPermanent as String: false
        ]
        
        // Create the key
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(rsaKeyData as CFData,
                                           attributes as CFDictionary,
                                           &error) else {
            if let error = error?.takeRetainedValue() as? Error {
                print("❌ Failed to create key: \(error)")
            }
            throw JWTError.invalidKey
        }
        
        print("✅ Successfully created SecKey")
        
        // Verify the key can be used for signing
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        guard SecKeyIsAlgorithmSupported(key, .sign, algorithm) else {
            print("❌ Key does not support required signing algorithm")
            throw JWTError.invalidKey
        }
        
        print("✅ Key supports required signing algorithm")
        return key
    }
    
    private static func base64URLEncode(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum JWTError: Error {
    case invalidKey
    case signatureFailure
    case invalidResponse
}

struct FirebaseServiceAccount: Codable {
    let type: String
    let projectId: String
    let privateKeyId: String
    let privateKey: String
    let clientEmail: String
    let clientId: String
    let authUri: String
    let tokenUri: String
    let authProviderX509CertUrl: String
    let clientX509CertUrl: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case projectId = "project_id"
        case privateKeyId = "private_key_id"
        case privateKey = "private_key"
        case clientEmail = "client_email"
        case clientId = "client_id"
        case authUri = "auth_uri"
        case tokenUri = "token_uri"
        case authProviderX509CertUrl = "auth_provider_x509_cert_url"
        case clientX509CertUrl = "client_x509_cert_url"
    }
} 