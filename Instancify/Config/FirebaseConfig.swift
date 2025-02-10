import Foundation

struct FirebaseConfig {
    static let projectId = "instancify"
    static let senderId = "133901911087"
    static let serverKey = "AIzaSyBclJrBfo5XMrBYYFbh-rCvIsC2rvyUhzk"
    static let fcmEndpoint = "https://fcm.googleapis.com/fcm/send"
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
    
    private enum CodingKeys: String, CodingKey {
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

extension FirebaseNotificationService {
    func generateJWT(using serviceAccount: FirebaseServiceAccount) throws -> String {
        // Implementation for JWT generation
        // You can use a JWT library like JWTKit or implement your own
        // This is a placeholder - you'll need to implement the actual JWT generation
        fatalError("Implement JWT generation")
    }
    
    func getAccessToken(jwt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let tokenEndpoint = "https://oauth2.googleapis.com/token"
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": jwt
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                completion(.failure(NSError(domain: "com.instancify", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid token response"])))
                return
            }
            
            completion(.success(accessToken))
        }.resume()
    }
} 