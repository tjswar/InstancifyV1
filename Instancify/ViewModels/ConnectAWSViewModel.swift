import Foundation
import AWSCore

@MainActor
class ConnectAWSViewModel: ObservableObject {
    @Published var accessKeyId = ""
    @Published var secretKey = ""
    @Published var selectedRegion = AWSRegion.usEast1
    @Published var isLoading = false
    @Published var error: String?
    
    func connect() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let isValid = try await AWSManager.shared.validateConnection(
                accessKey: accessKeyId,
                secretKey: secretKey,
                region: selectedRegion.rawValue
            )
            
            if !isValid {
                throw AWSError.invalidCredentials
            }
        } catch {
            if let awsError = error as? AWSError {
                self.error = awsError.errorDescription
            } else {
                self.error = error.localizedDescription
            }
            throw error
        }
    }
    
    func validateAndConnect() async throws {
        guard !accessKeyId.isEmpty else {
            throw AWSError.invalidCredentials
        }
        
        guard !secretKey.isEmpty else {
            throw AWSError.invalidCredentials
        }
        
        try await connect()
    }
} 