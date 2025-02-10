import Foundation
import AWSCore
import AWSEC2

class AWSManager {
    static let shared = AWSManager()
    private let serviceKey = "DefaultKey"
    private var currentConnection: AWSConnection?
    
    var currentConnectionDetails: AWSConnection? {
        currentConnection
    }
    
    private init() {}
    
    func configure(accessKey: String, secretKey: String, region: AWSRegionType) async throws {
        // Create the credentials provider
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        
        // Create the service configuration
        let configuration = AWSServiceConfiguration(
            region: region,
            credentialsProvider: credentialsProvider
        )
        
        // Set default configuration
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Register services with explicit configurations
        AWSEC2.register(with: configuration!, forKey: serviceKey)
        
        // Store connection details
        currentConnection = AWSConnection(
            name: "AWS Connection",
            accessKeyId: accessKey,
            secretKey: secretKey,
            region: region.stringValue
        )
        
        // Test the connection with a simple EC2 request
        let ec2 = AWSEC2(forKey: serviceKey)
        let request = AWSEC2DescribeInstancesRequest()!
        
        // Test the connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ec2.describeInstances(request) { response, error in
                if let error = error {
                    print("AWS Configuration Test Error: \(error)")
                    continuation.resume(throwing: AWSError.serviceError(error.localizedDescription))
                } else {
                    print("AWS Configuration Test Successful")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func fetchResources() async throws -> [AWSResource] {
        guard let _ = currentConnection else {
            throw AWSError.notConfigured
        }
        
        print("Starting to fetch resources...")
        
        do {
            let ec2Resources = try await fetchEC2Resources()
            
            print("Successfully fetched resources:")
            print("- EC2 instances: \(ec2Resources.count)")
            
            let allResources = ec2Resources
            return allResources
        } catch {
            print("Error fetching resources: \(error)")
            throw error
        }
    }
    
    func fetchEC2Resources() async throws -> [AWSResource] {
        guard let _ = currentConnection else {
            throw AWSError.notConfigured
        }
        
        let ec2 = AWSEC2(forKey: serviceKey)
        let request = AWSEC2DescribeInstancesRequest()!
        
        return try await withCheckedThrowingContinuation { continuation in
            ec2.describeInstances(request) { response, error in
                if let error = error {
                    print("Error fetching EC2 instances: \(error)")
                    // Return empty array with error status
                    let errorInstance = EC2Instance.error()
                    let errorResource = AWSResource(from: errorInstance)
                    continuation.resume(returning: [errorResource])
                    return
                }
                
                guard let reservations = response?.reservations,
                      !reservations.isEmpty else {
                    print("No EC2 instances found")
                    let emptyInstance = EC2Instance.empty()
                    let emptyResource = AWSResource(from: emptyInstance)
                    continuation.resume(returning: [emptyResource])
                    return
                }
                
                print("Found \(reservations.count) reservations")
                
                var allResources: [AWSResource] = []
                
                for reservation in reservations {
                    guard let instances = reservation.instances else { continue }
                    
                    for instance in instances {
                        if let ec2Instance = EC2Instance(from: instance) {
                            let resource = AWSResource(from: ec2Instance)
                            allResources.append(resource)
                            
                            print("🔍 AWSManager: Found instance \(ec2Instance.id) - State: \(ec2Instance.state)")
                        }
                    }
                }
                
                print("Total EC2 instances found: \(allResources.count)")
                continuation.resume(returning: allResources)
            }
        }
    }
    
    func switchRegion(_ region: String) async throws {
        guard let connection = currentConnection else {
            throw AWSError.notConfigured
        }
        
        let awsRegion: AWSRegionType
        switch region {
        case "us-east-1": awsRegion = .USEast1
        case "us-east-2": awsRegion = .USEast2
        case "us-west-1": awsRegion = .USWest1
        case "us-west-2": awsRegion = .USWest2
        case "eu-west-1": awsRegion = .EUWest1
        case "eu-central-1": awsRegion = .EUCentral1
        case "ap-southeast-1": awsRegion = .APSoutheast1
        case "ap-southeast-2": awsRegion = .APSoutheast2
        case "ap-northeast-1": awsRegion = .APNortheast1
        default: throw AWSError.invalidRegion
        }
        
        try await configure(
            accessKey: connection.accessKeyId,
            secretKey: connection.secretKey,
            region: awsRegion
        )
    }
    
    func validateConnection(accessKey: String, secretKey: String, region: String) async throws -> Bool {
        let awsRegion: AWSRegionType
        switch region {
        case "us-east-1": awsRegion = .USEast1
        case "us-east-2": awsRegion = .USEast2
        case "us-west-1": awsRegion = .USWest1
        case "us-west-2": awsRegion = .USWest2
        case "eu-west-1": awsRegion = .EUWest1
        case "eu-central-1": awsRegion = .EUCentral1
        case "ap-southeast-1": awsRegion = .APSoutheast1
        case "ap-southeast-2": awsRegion = .APSoutheast2
        case "ap-northeast-1": awsRegion = .APNortheast1
        default: throw AWSError.invalidRegion
        }
        
        try await configure(accessKey: accessKey, secretKey: secretKey, region: awsRegion)
        
        // Try to list EC2 instances as a validation
        _ = try await fetchEC2Resources()
        return true
    }
    
    // Add missing instance management methods
    func startInstance(instanceId: String) async throws {
        guard let connection = currentConnection else {
            throw AWSError.notConfigured
        }
        
        print("Attempting to start instance: \(instanceId)")
        
        // Create a new configuration with current credentials
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: connection.accessKeyId,
            secretKey: connection.secretKey
        )
        
        let awsRegion = getAWSRegion(from: connection.region)
        let configuration = AWSServiceConfiguration(
            region: awsRegion,
            credentialsProvider: credentialsProvider
        )
        
        // Register EC2 with this configuration
        AWSEC2.register(with: configuration!, forKey: "StartInstance")
        let ec2 = AWSEC2(forKey: "StartInstance")
        
        let request = AWSEC2StartInstancesRequest()!
        request.instanceIds = [instanceId]
        
        return try await withCheckedThrowingContinuation { continuation in
            ec2.startInstances(request) { response, error in
                if let error = error {
                    print("Start instance error: \(error.localizedDescription)")
                    continuation.resume(throwing: AWSError.serviceError(error.localizedDescription))
                } else if let response = response {
                    print("Start instance response received")
                    print("Starting instances count: \(response.startingInstances?.count ?? 0)")
                    
                    // Check if we got a valid response with starting instances
                    if let startingInstances = response.startingInstances,
                       !startingInstances.isEmpty {
                        print("Instance(s) starting successfully")
                        continuation.resume()
                    } else {
                        print("No starting instances in response")
                        continuation.resume(throwing: AWSError.serviceError("Instance start request failed"))
                    }
                } else {
                    print("No response received from AWS")
                    continuation.resume(throwing: AWSError.serviceError("No response from AWS"))
                }
            }
        }
    }
    
    func stopInstance(instanceId: String) async throws {
        guard let connection = currentConnection else {
            throw AWSError.notConfigured
        }
        
        print("Attempting to stop instance: \(instanceId) with force stop")
        
        // Convert region string to AWSRegionType
        let awsRegion: AWSRegionType
        switch connection.region {
        case "us-east-1": awsRegion = .USEast1
        case "us-east-2": awsRegion = .USEast2
        case "us-west-1": awsRegion = .USWest1
        case "us-west-2": awsRegion = .USWest2
        case "eu-west-1": awsRegion = .EUWest1
        case "eu-central-1": awsRegion = .EUCentral1
        case "ap-southeast-1": awsRegion = .APSoutheast1
        case "ap-southeast-2": awsRegion = .APSoutheast2
        default: awsRegion = .USEast1 // Default to US East 1
        }
        
        // Create a new configuration with current credentials
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: connection.accessKeyId,
            secretKey: connection.secretKey
        )
        
        let configuration = AWSServiceConfiguration(
            region: awsRegion,
            credentialsProvider: credentialsProvider
        )
        
        // Register EC2 with this configuration
        AWSEC2.register(with: configuration!, forKey: "StopInstance")
        let ec2 = AWSEC2(forKey: "StopInstance")
        
        let request = AWSEC2StopInstancesRequest()!
        request.instanceIds = [instanceId]
        request.force = true // Force stop the instance
        
        return try await withCheckedThrowingContinuation { continuation in
            ec2.stopInstances(request) { response, error in
                if let error = error {
                    print("Stop instance error: \(error.localizedDescription)")
                    continuation.resume(throwing: AWSError.serviceError("Failed to stop instance: \(error.localizedDescription)"))
                } else if let response = response {
                    print("Stop instance response received")
                    print("Stopping instances count: \(response.stoppingInstances?.count ?? 0)")
                    
                    // Check if we got a valid response with stopping instances
                    if let stoppingInstances = response.stoppingInstances,
                       !stoppingInstances.isEmpty {
                        print("Instance(s) stopping successfully")
                        continuation.resume()
                    } else {
                        print("No stopping instances in response")
                        continuation.resume(throwing: AWSError.serviceError("Instance stop request failed"))
                    }
                } else {
                    print("No response received from AWS")
                    continuation.resume(throwing: AWSError.serviceError("No response from AWS"))
                }
            }
        }
    }
    
    func rebootInstance(instanceId: String) async throws {
        guard let connection = currentConnection else {
            throw AWSError.notConfigured
        }
        
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: connection.accessKeyId,
            secretKey: connection.secretKey
        )
        
        let awsRegion = getAWSRegion(from: connection.region)
        let configuration = AWSServiceConfiguration(
            region: awsRegion,
            credentialsProvider: credentialsProvider
        )
        
        AWSEC2.register(with: configuration!, forKey: "RebootInstance")
        let ec2 = AWSEC2(forKey: "RebootInstance")
        
        let request = AWSEC2RebootInstancesRequest()!
        request.instanceIds = [instanceId]
        
        return try await withCheckedThrowingContinuation { continuation in
            ec2.rebootInstances(request) { error in
                if let error = error {
                    print("Reboot error: \(error.localizedDescription)")
                    continuation.resume(throwing: AWSError.serviceError(error.localizedDescription))
                } else {
                    print("Reboot request sent successfully")
                    continuation.resume()
                }
            }
        }
    }
    
    func terminateInstance(instanceId: String) async throws {
        guard let connection = currentConnection else {
            throw AWSError.notConfigured
        }
        
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: connection.accessKeyId,
            secretKey: connection.secretKey
        )
        
        let awsRegion = getAWSRegion(from: connection.region)
        let configuration = AWSServiceConfiguration(
            region: awsRegion,
            credentialsProvider: credentialsProvider
        )
        
        AWSEC2.register(with: configuration!, forKey: "TerminateInstance")
        let ec2 = AWSEC2(forKey: "TerminateInstance")
        
        let request = AWSEC2TerminateInstancesRequest()!
        request.instanceIds = [instanceId]
        
        return try await withCheckedThrowingContinuation { continuation in
            ec2.terminateInstances(request) { response, error in
                if let error = error {
                    print("Terminate error: \(error.localizedDescription)")
                    continuation.resume(throwing: AWSError.serviceError(error.localizedDescription))
                } else {
                    print("Terminate request sent successfully")
                    continuation.resume()
                }
            }
        }
    }
    
    // Helper function to convert region string to AWSRegionType
    private func getAWSRegion(from region: String) -> AWSRegionType {
        switch region {
        case "us-east-1": return .USEast1
        case "us-east-2": return .USEast2
        case "us-west-1": return .USWest1
        case "us-west-2": return .USWest2
        case "eu-west-1": return .EUWest1
        case "eu-central-1": return .EUCentral1
        case "ap-southeast-1": return .APSoutheast1
        case "ap-southeast-2": return .APSoutheast2
        case "ap-northeast-1": return .APNortheast1
        default: return .USEast1
        }
    }
    
    // Add clear configuration method
    func clearConfiguration() {
        currentConnection = nil
        AWSServiceManager.default().defaultServiceConfiguration = nil
    }
    
    // Add fetch resources across regions method
    func fetchResourcesAcrossRegions() async throws -> [AWSResource] {
        guard let connection = currentConnection else {
            throw AWSError.notConfigured
        }
        
        var allResources: [AWSResource] = []
        for region in AWSRegion.allCases {
            try await switchRegion(region.rawValue)
            let resources = try await fetchResources()
            allResources.append(contentsOf: resources)
        }
        
        // Switch back to original region
        try await switchRegion(connection.region)
        return allResources
    }
}

extension AWSRegionType {
    static func fromString(_ region: String) -> AWSRegionType {
        switch region {
        case "us-east-1": return .USEast1
        case "us-east-2": return .USEast2
        case "us-west-1": return .USWest1
        case "us-west-2": return .USWest2
        case "eu-west-1": return .EUWest1
        case "eu-central-1": return .EUCentral1
        case "ap-southeast-1": return .APSoutheast1
        case "ap-southeast-2": return .APSoutheast2
        case "ap-northeast-1": return .APNortheast1
        default: return .USEast1
        }
    }
}
