import Foundation
import KeychainAccess

class KeychainManager {
    static let shared = KeychainManager()
    private let keychain = Keychain(service: "tech.medilook.Instancify")
    
    private init() {}
    
    func storeCredentials(accessKeyId: String, secretAccessKey: String, region: String) throws {
        let credentials = AWSCredentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey
        )
        
        let data = try JSONEncoder().encode(credentials)
        try keychain.set(data, key: "aws_credentials")
        try keychain.set(region, key: "aws_region")
    }
    
    func retrieveCredentials() throws -> AWSCredentials {
        guard let data = try keychain.getData("aws_credentials"),
              let credentials = try? JSONDecoder().decode(AWSCredentials.self, from: data) else {
            throw AWSError.noCredentialsFound
        }
        return credentials
    }
    
    func clearCredentials() throws {
        try keychain.remove("aws_credentials")
        try keychain.remove("aws_region")
    }
    
    func getRegion() throws -> String {
        guard let region = try keychain.getString("aws_region") else {
            throw KeychainError.unableToRetrieve
        }
        return region
    }
}

enum KeychainError: Error {
    case unableToStore
    case unableToRetrieve
    case unableToDelete
} 