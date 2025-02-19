import Foundation
import AWSEC2
import AWSCore
import AWSCloudWatch
import UserNotifications
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@MainActor
class EC2Service: ObservableObject {
    static let shared = EC2Service()
    private var ec2: AWSEC2
    private var currentCredentials: AWSCredentials?
    private var instanceNames: [String: String] = [:]
    private let logger = Functions.functions().httpsCallable("logger")
    private let runtimeAlertManager = FirebaseNotificationService.shared
    @Published private(set) var instances: [EC2Instance] = []
    @Published private(set) var currentRegion: String = AuthenticationManager.shared.selectedRegion.rawValue {
        willSet {
            if newValue != currentRegion {
                print("\n🌎 EC2Service: Region changing from \(currentRegion) to \(newValue)")
                // Clear state before region change
                instances = []
                instanceNames.removeAll()
                autoStopConfigs.removeAll()
                
                // Post notification for region change
                NotificationCenter.default.post(
                    name: NSNotification.Name("RegionChanged"),
                    object: newValue
                )
                
                // Update widget's current region
                WidgetService.shared.updateCurrentRegion(newValue)
            }
        }
    }
    
    private var costUpdateTimer: Timer?
    
    // Add a debouncer for updates
    private var updateWorkItem: DispatchWorkItem?
    
    // Add throttling for updates
    private var lastUpdateTime: Date = .distantPast
    private let minimumUpdateInterval: TimeInterval = 1.0 // Minimum time between updates
    
    private struct InstanceHistory: Codable {
        let instanceId: String
        let startTime: Date
        let endTime: Date
        let runtime: TimeInterval
        let cost: Double
        let instanceType: String
    }
    
    private struct RuntimeRecord: Codable {
        let date: Date
        let runtime: TimeInterval
        let cost: Double
        let fromState: String
        let toState: String
    }
    
    // Replace installDate with loginDate
    private var loginDate: Date?
    
    private var instanceActivities: [String: [InstanceActivity]] = [:]
    
    // Add this property to track auto-stop timers
    private var autoStopTimers: [String: Timer] = [:]
    
    // Add these properties at the top of the class
    private var countdownTimers: [String: Timer] = [:]
    private var countdownWorkItems: [String: DispatchWorkItem] = [:]
    
    // Add these properties at the top of the class
    private var defaults: UserDefaults?
    
    @Published private var autoStopConfigs: [String: AutoStopConfig] = [:] {
        didSet {
            print("\n📝 Auto-stop configs updated:")
            print("  • Number of configs: \(autoStopConfigs.count)")
            print("  • Configs: \(autoStopConfigs)")
        }
    }
    private var autoStopUpdateTimer: Timer?
    
    #if DEBUG
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    #endif
    
    // Add observer for region changes from AuthenticationManager
    private var regionObserver: NSObjectProtocol?
    
    private func setupFirstLaunchDate() {
        if UserDefaults.standard.object(forKey: "appFirstLaunchDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "appFirstLaunchDate")
        }
    }
    
    private init() {
        print("\n🔧 Initializing EC2Service...")
        
        // Initialize ec2 with default configuration first
        let defaultConfig = AWSServiceConfiguration(
            region: AuthenticationManager.shared.selectedRegion.awsRegionType,
            credentialsProvider: AWSAnonymousCredentialsProvider()
        )!
        AWSServiceManager.default().defaultServiceConfiguration = defaultConfig
        AWSEC2.register(with: defaultConfig, forKey: "DefaultKey")
        self.ec2 = AWSEC2(forKey: "DefaultKey")
        
        print("✅ Initialized with region from AuthManager: \(self.currentRegion)")
        
        // Add observer for region changes
        regionObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RegionChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newRegion = notification.object as? String {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.currentRegion != newRegion {
                        print("🌎 EC2Service: Received region change notification: \(newRegion)")
                        // Update configuration with new region
                        if let credentials = try? AuthenticationManager.shared.getAWSCredentials() {
                            self.updateConfiguration(with: credentials, region: newRegion)
                        }
                    }
                }
            }
        }
        
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("🔧 EC2Service: Running in preview mode")
            // Initialize with mock data for preview
            self.instances = [
                EC2Instance(
                    id: "i-1234567890abcdef0",
                    instanceType: "t2.micro",
                    state: .running,
                    name: "Preview Instance",
                    launchTime: Date(),
                    publicIP: "1.2.3.4",
                    privateIP: "10.0.0.1",
                    autoStopEnabled: false,
                    countdown: nil,
                    stateTransitionTime: nil,
                    hourlyRate: 0.0116,
                    runtime: 0,
                    currentCost: 0.0,
                    projectedDailyCost: 0.2784,
                    region: self.currentRegion
                )
            ]
            return
        }
        #endif
        
        // Initialize UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            let appGroupId = "group.\(bundleId)"
            defaults = UserDefaults(suiteName: "group.tech.md.Instancify") ?? UserDefaults.standard
            print("✅ Initialized UserDefaults with suite name: \(appGroupId)")
        } else {
            defaults = nil
            print("❌ Failed to get bundle identifier")
        }
        
        // Configure AWS with stored credentials asynchronously
        Task {
            do {
                let credentials = try KeychainManager.shared.retrieveCredentials()
                let region = AuthenticationManager.shared.selectedRegion.rawValue
                
                let credentialsProvider = AWSStaticCredentialsProvider(
                    accessKey: credentials.accessKeyId,
                    secretKey: credentials.secretAccessKey
                )
                
                let configuration = AWSServiceConfiguration(
                    region: AuthenticationManager.shared.selectedRegion.awsRegionType,
                    credentialsProvider: credentialsProvider
                )!
                
                // Set the default configuration
                AWSServiceManager.default().defaultServiceConfiguration = configuration
                
                // Then register EC2 service
                AWSEC2.register(with: configuration, forKey: "DefaultKey")
                self.ec2 = AWSEC2(forKey: "DefaultKey")
                
                print("✅ AWS configured with stored credentials for region: \(region)")
            } catch {
                print("❌ Failed to configure AWS: \(error)")
            }
        }
        
        // Setup timers and monitoring
        setupCostUpdateTimer()
        startAutoStopMonitoring()
        print("✅ EC2Service initialization complete")
    }
    
    func updateConfiguration(with credentials: AWSCredentials, region: String) {
        print("\n🌎 EC2Service: Updating configuration for region: \(region)")
        
        // Update the current region first
        currentRegion = region
        
        // Clear all existing AWS configurations
        AWSEC2.remove(forKey: "DefaultKey")
        
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: credentials.accessKeyId,
            secretKey: credentials.secretAccessKey
        )
        
        let configuration = AWSServiceConfiguration(
            region: mapRegionToAWSType(region),
            credentialsProvider: credentialsProvider
        )!
        
        // Set the default configuration
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Register EC2 service with new configuration
        AWSEC2.register(with: configuration, forKey: "DefaultKey")
        self.ec2 = AWSEC2(forKey: "DefaultKey")
        
        print("✅ EC2Service configuration updated for region: \(region)")
        
        // Clear all cached data
        instances = []
        instanceNames.removeAll()
        autoStopConfigs.removeAll()
        
        // Force a UI update
        objectWillChange.send()
    }
    
    func fetchInstances() async throws -> [EC2Instance] {
        print("\n🔍 Fetching instances for region: \(currentRegion)")
        
        // Validate that we're using the correct region configuration
        if let configRegion = (ec2.configuration.endpoint as AWSEndpoint?)?.regionName,
           configRegion != currentRegion {
            print("⚠️ Region mismatch detected. Reconfiguring AWS...")
            print("  • Current config region: \(configRegion)")
            print("  • Expected region: \(currentRegion)")
            
            // Get current credentials
            let credentials = try AuthenticationManager.shared.getAWSCredentials()
            
            // Create new configuration with correct region
            let credentialsProvider = AWSStaticCredentialsProvider(
                accessKey: credentials.accessKeyId,
                secretKey: credentials.secretAccessKey
            )
            
            let configuration = AWSServiceConfiguration(
                region: mapRegionToAWSType(currentRegion),
                credentialsProvider: credentialsProvider
            )!
            
            // Update EC2 configuration
            AWSServiceManager.default().defaultServiceConfiguration = configuration
            AWSEC2.register(with: configuration, forKey: "DefaultKey")
            self.ec2 = AWSEC2(forKey: "DefaultKey")
            print("✅ AWS reconfigured for region: \(currentRegion)")
        }
        
        let request = AWSEC2DescribeInstancesRequest()!
        
        do {
            let result = try await ec2.describeInstances(request)
            var instances: [EC2Instance] = []
            
            guard let reservations = result.reservations else {
                print("ℹ️ No instances found in region \(currentRegion)")
                // Clear widget data when no instances are found
                WidgetService.shared.clearWidgetData(for: currentRegion)
                return []
            }
            
            for reservation in reservations {
                guard let awsInstances = reservation.instances else { continue }
                
                for awsInstance in awsInstances {
                    if let instance = createInstance(from: awsInstance, region: currentRegion) {
                        instances.append(instance)
                    }
                }
            }
            
            // Sort instances by name
            instances.sort { ($0.name ?? $0.id) < ($1.name ?? $1.id) }
            
            // Update local instances array
            self.instances = instances
            
            // Batch update widget data
            WidgetService.shared.updateWidgetDataBatch(instances, for: currentRegion)
            
            print("✅ Found \(instances.count) instances in region \(currentRegion)")
            return instances
            
        } catch {
            print("❌ Failed to fetch instances: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func createInstance(from awsInstance: AWSEC2Instance, region: String) -> EC2Instance? {
        guard let instanceId = awsInstance.instanceId else { return nil }
        
        let name = awsInstance.tags?.first(where: { $0.key == "Name" })?.value
        let instanceType = String(describing: awsInstance.instanceType)
            .replacingOccurrences(of: "AWSEC2InstanceType(rawValue: ", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        let hourlyRate = self.getInstanceHourlyRate(type: instanceType)
        
        let stateCode = awsInstance.state?.code?.intValue
        let stateString = self.getStateString(from: stateCode)
        let state = InstanceState(rawValue: stateString) ?? .unknown
        
        // Get auto-stop settings
        let autoStopSettings = AutoStopSettingsService.shared.getSettings(for: instanceId)
        let isAutoStopEnabled = autoStopSettings?.isEnabled ?? false
        let stopTime = autoStopSettings?.stopTime
        
        // Calculate runtime
        let runtime: Int
        if state == .running, let launchTime = awsInstance.launchTime {
            runtime = Int(Date().timeIntervalSince(launchTime))
        } else {
            runtime = 0
        }
        
        // Create instance with runtime and region
        let instance = EC2Instance(
            id: instanceId,
            instanceType: instanceType,
            state: state,
            name: name ?? instanceId,
            launchTime: awsInstance.launchTime,
            publicIP: awsInstance.publicIpAddress,
            privateIP: awsInstance.privateIpAddress,
            autoStopEnabled: isAutoStopEnabled,
            countdown: stopTime != nil ? DateFormatter.localizedString(from: stopTime!, dateStyle: .none, timeStyle: .short) : (isAutoStopEnabled ? "Set time" : nil),
            stateTransitionTime: nil,
            hourlyRate: hourlyRate,
            runtime: runtime,
            currentCost: 0,
            projectedDailyCost: 0,
            region: region
        )
        
        self.instanceNames[instanceId] = name ?? instanceId
        return instance
    }
    
    private func getStateString(from stateCode: Int?) -> String {
        guard let code = stateCode else { return "unknown" }
        switch code {
        case 0: return "pending"
        case 16: return "running"
        case 32: return "shutting-down"
        case 48: return "terminated"
        case 64: return "stopping"
        case 80: return "stopped"
        default: return "unknown"
        }
    }
    
    private func getRuntimeKey(for date: Date, instanceId: String) -> String {
        let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        return "runtime-\(instanceId)-\(dateString)"
    }
    
    private func getInstanceHourlyRate(type: String) -> Double {
        switch type {
        case "417", "t2.micro": return 0.0116
        case "418", "t2.small": return 0.023
        case "419", "t2.medium": return 0.0464
        case "420", "t2.large": return 0.0928
        case "421", "t3.micro": return 0.0104
        case "422", "t3.small": return 0.0208
        case "423", "t3.medium": return 0.0416
        default:
            print("⚠️ Unknown instance type: \(type), using default pricing")
            return 0.0116 // Default to t2.micro pricing
        }
    }
    
    func startInstances(_ instanceIds: [String]) async throws {
        let request = AWSEC2StartInstancesRequest()!
        request.instanceIds = instanceIds
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ec2.startInstances(request) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func stopInstances(_ instanceIds: [String]) async throws {
        let request = AWSEC2StopInstancesRequest()!
        request.instanceIds = instanceIds
        
        return try await withCheckedThrowingContinuation { [self] continuation in
            ec2.stopInstances(request) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func startInstance(_ instanceId: String, region: String? = nil) async throws {
        // Ensure we have valid credentials
        let authManager = AuthenticationManager.shared
        let credentials = try authManager.getAWSCredentials()
        
        // Configure AWS services with credentials
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: credentials.accessKeyId,
            secretKey: credentials.secretAccessKey
        )
        
        let configuration = AWSServiceConfiguration(
            region: authManager.selectedRegion.awsRegionType,
            credentialsProvider: credentialsProvider
        )!
        
        // Set the default configuration
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Register EC2 with this configuration
        AWSEC2.register(with: configuration, forKey: "StartInstance")
        let ec2Client = AWSEC2(forKey: "StartInstance")
        
        let request = AWSEC2StartInstancesRequest()!
        request.instanceIds = [instanceId]
        
        do {
            _ = try await ec2Client.startInstances(request)
            print("✅ Started instance \(instanceId)")
            
            // Get updated instance state
            if let instance = try await self.getInstanceDetails(instanceId) {
                try await FirebaseNotificationService.shared.sendInstanceStateNotification(
                    instanceId: instance.id,
                    instanceName: instance.name ?? instance.id,
                    oldState: instance.state.rawValue,
                    newState: "running"
                )
            }
        } catch {
            print("❌ Failed to start instance \(instanceId): \(error)")
            throw error
        }
    }
    
    func stopInstance(_ instanceId: String, isAutoStop: Bool = false) async throws {
        print("\n🛑 Stopping instance \(instanceId)")
        
        // Clear runtime alerts before attempting to stop the instance
        await clearRuntimeAlerts(for: instanceId)
        
        let request = AWSEC2StopInstancesRequest()!
        request.instanceIds = [instanceId]
        
        do {
            _ = try await ec2.stopInstances(request)
            
            // Get instance details for notification
            if let instance = try await getInstanceDetails(instanceId, region: currentRegion) {
                // Clear runtime alerts again after the instance is stopped to ensure they're gone
                await clearRuntimeAlerts(for: instanceId)
                
                // Then send the state change notification
                try await FirebaseNotificationService.shared.sendInstanceStateNotification(
                    instanceId: instance.id,
                    instanceName: instance.name ?? instance.id,
                    oldState: instance.state.rawValue,
                    newState: "stopped"
                )
                
                // Log the stop operation
                try? await logger.call([
                    "message": "✅ Successfully stopped instance \(instanceId) and cleared all runtime alerts",
                    "level": "info"
                ])
                
                // Notify that runtime alerts have been cleared
                NotificationCenter.default.post(
                    name: NSNotification.Name("RuntimeAlertsCleared"),
                    object: instanceId
                )
            }
        } catch {
            // Log the error
            try? await logger.call([
                "message": "❌ Failed to stop instance \(instanceId): \(error)",
                "level": "error"
            ])
            throw EC2ServiceError.instanceOperationFailed
        }
    }
    
    func terminateInstance(_ instanceId: String, region: String? = nil) async throws {
        let targetRegion = region ?? currentRegion
        let request = AWSEC2TerminateInstancesRequest()!
        request.instanceIds = [instanceId]
        
        do {
            _ = try await AWSEC2.default().terminateInstances(request)
            print("✅ Terminated instance \(instanceId)")
            
            // Get updated instance state
            if let instance = try await getInstanceDetails(instanceId, region: targetRegion) {
                try await FirebaseNotificationService.shared.sendInstanceStateNotification(
                    instanceId: instance.id,
                    instanceName: instance.name ?? instance.id,
                    oldState: instance.state.rawValue,
                    newState: "terminated"
                )
            }
        } catch {
            print("❌ Failed to terminate instance \(instanceId): \(error)")
            throw error
        }
    }
    
    func rebootInstance(_ instanceId: String, region: String? = nil) async throws {
        let targetRegion = region ?? currentRegion
        let request = AWSEC2RebootInstancesRequest()!
        request.instanceIds = [instanceId]
        
        do {
            _ = try await AWSEC2.default().rebootInstances(request)
            print("✅ Rebooted instance \(instanceId)")
            
            // Get updated instance state
            if let instance = try await getInstanceDetails(instanceId, region: targetRegion) {
                try await FirebaseNotificationService.shared.sendInstanceStateNotification(
                    instanceId: instanceId,
                    instanceName: instance.name ?? instance.id,
                    oldState: instance.state.rawValue,
                    newState: "running"
                )
            }
        } catch {
            print("❌ Failed to reboot instance \(instanceId): \(error)")
            throw error
        }
    }
    
    func validateCredentials() async throws {
        let request = AWSEC2DescribeRegionsRequest()!
        
        return try await withCheckedThrowingContinuation { [self] continuation in
            ec2.describeRegions(request) { response, error in
                if let error = error {
                    print("❌ Credential validation failed: \(error.localizedDescription)")
                    continuation.resume(throwing: AuthenticationError.invalidCredentials)
                } else {
                    print("✅ Credentials validated successfully")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    @MainActor
    func getActivities(for instanceId: String) -> [InstanceActivity] {
        guard let data = UserDefaults.standard.data(forKey: "activities-\(instanceId)"),
              let activities = try? JSONDecoder().decode([InstanceActivity].self, from: data) else {
            return []
        }
        
        // Return activities sorted by timestamp, most recent first
        return activities.sorted { $0.timestamp > $1.timestamp }
    }
    
    func updateInstanceRuntime(_ instanceId: String) {
        guard let instance = instances.first(where: { $0.id == instanceId }),
              let launchTime = instance.launchTime else { return }
        
        let now = Date()
        let runtime = now.timeIntervalSince(launchTime)
        let key = getRuntimeKey(for: now, instanceId: instanceId)
        
        // Store the runtime for this session
        UserDefaults.standard.set(runtime, forKey: key)
    }
    
    private func setupCostUpdateTimer() {
        costUpdateTimer?.invalidate()
        
        // Create a timer that fires every second
        DispatchQueue.main.async { [weak self] in
            self?.costUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateInstanceRuntimes()
                    self?.updateInstanceCosts()
                }
            }
        }
    }
    
    private func debouncedUpdateCosts() async {
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= minimumUpdateInterval else { return }
        
        updateWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                try? await self?.updateCosts()
                self?.lastUpdateTime = Date()
            }
        }
        
        updateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    private func updateCosts() async throws {
        // Batch updates to reduce UI updates
        let updatedInstances = instances
        
        for index in updatedInstances.indices where updatedInstances[index].state == .running {
            if let launchTime = updatedInstances[index].launchTime {
                let now = Date()
                let runtime = now.timeIntervalSince(launchTime)
                updatedInstances[index].runtime = Int(runtime / 3600)
            }
        }
        
        // Single UI update
        instances = updatedInstances
    }
    
    func cleanup() {
        DispatchQueue.main.async { [weak self] in
            self?.costUpdateTimer?.invalidate()
            self?.costUpdateTimer = nil
        }
    }
    
    func handleEnterBackground() {
        print("\n📱 App entering background")
        // Don't invalidate auto-stop timers in background
        // Only invalidate UI update timers
        for (_, timer) in countdownTimers {
            timer.invalidate()
        }
        countdownTimers.removeAll()
        
        autoStopUpdateTimer?.invalidate()
        autoStopUpdateTimer = nil
        
        // Ensure all auto-stop configurations are properly scheduled
        Task {
            await checkAutoStopConfigurations()
        }
        
        print("✅ Background state handled")
    }
    
    func handleEnterForeground() {
        print("\n📱 App entering foreground")
        Task { @MainActor [weak self] in
            do {
                // Refresh instances first
                try await self?.refreshInstances()
                
                // Check if any instances should have been stopped while in background
                await self?.checkAutoStopConfigurations()
                
                // Restore timers and monitoring
            await self?.restoreAutoStopTimers()
            self?.startAutoStopMonitoring()
                
                print("✅ Foreground state restored")
            } catch {
                print("❌ Error restoring foreground state: \(error)")
            }
        }
    }
    
    func refreshInstances() async throws {
        do {
            _ = try await fetchInstances()
            for index in instances.indices {
                if instances[index].state == .running {
                    let activities = getActivities(for: instances[index].id)
                    if let latestActivity = activities.first {
                        // Create a new instance with updated runtime
                        let updatedInstance = EC2Instance(
                            id: instances[index].id,
                            instanceType: instances[index].instanceType,
                            state: instances[index].state,
                            name: instances[index].name,
                            launchTime: instances[index].launchTime,
                            publicIP: instances[index].publicIP,
                            privateIP: instances[index].privateIP,
                            autoStopEnabled: instances[index].autoStopEnabled,
                            countdown: instances[index].countdown,
                            stateTransitionTime: instances[index].stateTransitionTime,
                            hourlyRate: instances[index].hourlyRate,
                            runtime: Int(latestActivity.runtime),
                            currentCost: latestActivity.cost ?? 0.0,
                            projectedDailyCost: instances[index].projectedDailyCost,
                            region: instances[index].region
                        )
                        instances[index] = updatedInstance
                    }
                }
            }
        } catch {
            print("❌ Failed to refresh instances: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func saveInstanceHistory(_ instance: EC2Instance, endTime: Date) {
        guard let launchTime = instance.launchTime,
              let loginDate = loginDate else { return }
        
        let runtime = endTime.timeIntervalSince(launchTime)
        let cost = (runtime / 3600.0) * instance.hourlyRate
        
        let history = InstanceHistory(
            instanceId: instance.id,
            startTime: launchTime,
            endTime: endTime,
            runtime: runtime,
            cost: cost,
            instanceType: instance.instanceType
        )
        
        var histories = getStoredHistories(for: instance.id)
        
        // Only keep history after login date
        histories = histories.filter { $0.startTime >= loginDate }
        histories.append(history)
        
        if let encoded = try? JSONEncoder().encode(histories) {
            UserDefaults.standard.set(encoded, forKey: "history-\(instance.id)")
        }
    }
    
    private func getStoredHistories(for instanceId: String) -> [InstanceHistory] {
        guard let data = UserDefaults.standard.data(forKey: "history-\(instanceId)"),
              let histories = try? JSONDecoder().decode([InstanceHistory].self, from: data) else {
            return []
        }
        return histories
    }
    
    private func saveRuntimeRecord(for instance: EC2Instance, fromState: String, toState: String) {
        print("\n💾 Saving runtime record for instance \(instance.id)")
        print("  • From: \(fromState)")
        print("  • To: \(toState)")
        
        let now = Date()
        var runtime: TimeInterval = 0
        var activityCost: Double = 0
        
        // Calculate runtime and cost for the activity
        if let launchTime = instance.launchTime {
            runtime = now.timeIntervalSince(launchTime)
            activityCost = (runtime / 3600.0) * instance.hourlyRate
        }
        
        // Create activity with new parameters
        InstanceActivity.addActivity(
            instanceId: instance.id,
            type: .stateChange(from: fromState, to: toState),
            details: "Instance state changed from \(fromState) to \(toState)",
            runtime: runtime,
            cost: activityCost
        )
        
        // Update instance runtime and costs
        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            let updatedInstance = EC2Instance(
                id: instance.id,
                instanceType: instance.instanceType,
                state: instance.state,
                name: instance.name,
                launchTime: instance.launchTime,
                publicIP: instance.publicIP,
                privateIP: instance.privateIP,
                autoStopEnabled: instance.autoStopEnabled,
                countdown: instance.countdown,
                stateTransitionTime: instance.stateTransitionTime,
                hourlyRate: instance.hourlyRate,
                runtime: Int(runtime),
                currentCost: activityCost,
                projectedDailyCost: instance.projectedDailyCost,
                region: instance.region
            )
            
            instances[index] = updatedInstance
            print("  ✅ Instance updated with new runtime and cost")
        }
    }
    
    // Add this method to track state changes with runtime
    private func trackStateChange(instance: EC2Instance, from oldState: String, to newState: String) {
        if oldState != newState {
            saveRuntimeRecord(for: instance, fromState: oldState, toState: newState)
            
            // Log activity with runtime and cost calculation
            let runtime = calculateRuntime(for: instance).runtime
            let cost = (runtime / 3600.0) * instance.hourlyRate
            
            InstanceActivity.addActivity(
                instanceId: instance.id,
                type: .stateChange(from: oldState, to: newState),
                details: "Instance state changed from \(oldState) to \(newState)",
                runtime: runtime,
                cost: cost
            )
        }
    }
    
    private func calculateRuntime(for instance: EC2Instance) -> (runtime: Double, displayString: String) {
        let now = Date()
        var runtime: Double = 0
        
        if instance.state == .running, let launchTime = instance.launchTime {
            runtime = now.timeIntervalSince(launchTime)
        } else if let stateTransitionTime = instance.stateTransitionTime {
            runtime = now.timeIntervalSince(stateTransitionTime)
        }
        
        let hours = Int(floor(runtime / 3600))
        let minutes = Int(floor(Double(runtime).truncatingRemainder(dividingBy: 3600) / 60))
        let displayString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        
        return (runtime, displayString)
    }
    
    func calculateInstanceCosts(for instance: EC2Instance) -> (hourly: Double, current: Double, projected: Double) {
        let activities = getActivities(for: instance.id)
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        
        // Calculate current cost from today's activities
        let todayActivities = activities.filter { $0.timestamp >= startOfToday }
        let currentCost = todayActivities.reduce(0.0) { $0 + ($1.cost ?? 0.0) }
        
        // Project daily cost based on current state and hourly rate
        let projectedCost = instance.state == .running ? 
            instance.hourlyRate * 24 : currentCost
            
        return (instance.hourlyRate, currentCost, projectedCost)
    }
    
    // Add haptic feedback for errors
    private func handleError(_ error: Error, for instanceId: String) {
        if let instance = instances.first(where: { $0.id == instanceId }) {
            NotificationManager.shared.sendNotification(
                type: .instanceError(
                    message: "Error with instance '\(instance.name ?? instanceId)': \(error.localizedDescription)"
                )
            )
        }
    }
    
    func clearAllData() {
        print("🧹 Clearing all EC2Service data...")
        instances.forEach { instance in
            // Clear activities for each instance
            UserDefaults.standard.removeObject(forKey: "activities-\(instance.id)")
            UserDefaults.standard.removeObject(forKey: "history-\(instance.id)")
            UserDefaults.standard.removeObject(forKey: "runtime-\(instance.id)")
            
            // Clear widget data
            WidgetService.shared.clearWidgetData(for: instance.region)
        }
        
        // Reset login date
        loginDate = nil
        instances = []
    }
    
    func calculateCosts(for instance: EC2Instance) -> (current: Double, projected: Double) {
        guard instance.state == .running else { return (0, 0) }
        
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        
        // Calculate today's runtime and cost
        let runtime: Double
        if let launchTime = instance.launchTime {
            let startTime = max(launchTime, startOfToday)
            runtime = now.timeIntervalSince(startTime)
        } else {
            runtime = 0
        }
        
        let currentCost = (runtime / 3600.0) * instance.hourlyRate
        
        // Calculate projected cost
        let hoursRemaining = calculateRemainingHours(from: now)
        let projectedAdditionalCost = instance.hourlyRate * hoursRemaining
        let projectedTotalCost = currentCost + projectedAdditionalCost
        
        return (currentCost, projectedTotalCost)
    }
    
    private func updateInstanceCosts() {
        // Update costs for all instances
        for (index, instance) in instances.enumerated() {
            let (current, _) = calculateCosts(for: instance)
            let updatedInstance = EC2Instance(
                id: instance.id,
                instanceType: instance.instanceType,
                state: instance.state,
                name: instance.name,
                launchTime: instance.launchTime,
                publicIP: instance.publicIP,
                privateIP: instance.privateIP,
                autoStopEnabled: instance.autoStopEnabled,
                countdown: instance.countdown,
                stateTransitionTime: instance.stateTransitionTime,
                hourlyRate: instance.hourlyRate,
                runtime: instance.runtime,
                currentCost: current,
                projectedDailyCost: instance.projectedDailyCost,
                region: instance.region
            )
            instances[index] = updatedInstance
            
            // Update widget if this is the primary instance
            if index == 0 {
                WidgetService.shared.updateWidgetData(for: updatedInstance)
            }
        }
    }
    
    // Add this method to update instance runtimes
    private func updateInstanceRuntimes() {
        let updatedInstances = instances
        let now = Date()
        
        for index in updatedInstances.indices {
            let instance = updatedInstances[index]
            let runtime: Int
            
            if instance.state == .running, let launchTime = instance.launchTime {
                // Calculate runtime for running instances
                runtime = Int(now.timeIntervalSince(launchTime))
            } else {
                // Reset runtime for stopped instances
                runtime = 0
            }
            
            // Create updated instance with new runtime
            let updatedInstance = EC2Instance(
                id: instance.id,
                instanceType: instance.instanceType,
                state: instance.state,
                name: instance.name,
                launchTime: instance.launchTime,
                publicIP: instance.publicIP,
                privateIP: instance.privateIP,
                autoStopEnabled: instance.autoStopEnabled,
                countdown: instance.countdown,
                stateTransitionTime: instance.stateTransitionTime,
                hourlyRate: instance.hourlyRate,
                runtime: runtime,
                currentCost: instance.currentCost,
                projectedDailyCost: instance.projectedDailyCost,
                region: instance.region
            )
            
            instances[index] = updatedInstance
        }
        
        // Update widget data with latest instance states
        if let primaryInstance = instances.first {
            WidgetService.shared.updateWidgetData(for: primaryInstance)
        }
    }
    
    private func formatRuntime(_ runtime: TimeInterval) -> String {
        let hours = Int(floor(Double(runtime) / 3600))
        let minutes = Int(floor(Double(runtime).truncatingRemainder(dividingBy: 3600) / 60))
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    private func calculateRemainingHours(from now: Date) -> Double {
        let calendar = Calendar.current
        let hour = Double(calendar.component(.hour, from: now))
        let minute = Double(calendar.component(.minute, from: now))
        return 24.0 - hour - (minute / 60.0)
    }
    
    @MainActor
    func toggleAutoStop(for instanceId: String, isEnabled: Bool) async throws {
        print("\n🔄 Toggling auto-stop for instance \(instanceId) to \(isEnabled)")
        
        guard let index = instances.firstIndex(where: { $0.id == instanceId }) else { return }
        
        // Create a local copy of the instance
        let updatedInstance = instances[index]
        
        // Update instance state
        let instance = EC2Instance(
            id: updatedInstance.id,
            instanceType: updatedInstance.instanceType,
            state: updatedInstance.state,
            name: updatedInstance.name,
            launchTime: updatedInstance.launchTime,
            publicIP: updatedInstance.publicIP,
            privateIP: updatedInstance.privateIP,
            autoStopEnabled: isEnabled,
            countdown: updatedInstance.countdown,
            stateTransitionTime: updatedInstance.stateTransitionTime,
            hourlyRate: updatedInstance.hourlyRate,
            runtime: updatedInstance.runtime,
            currentCost: updatedInstance.currentCost,
            projectedDailyCost: updatedInstance.projectedDailyCost,
            region: updatedInstance.region
        )
        
        if isEnabled {
            // When enabling, start fresh with no time set and clear any existing settings
            instance.countdown = "Set time"
            AutoStopSettingsService.shared.saveSettings(
                for: instance.id,
                enabled: true,
                time: nil
            )
            // Remove any existing auto-stop config
            autoStopConfigs.removeValue(forKey: instance.id)
        } else {
            // When disabling, clean up everything
            await clearNotifications(for: instance.id)
            autoStopConfigs.removeValue(forKey: instance.id)
            AutoStopSettingsService.shared.clearSettings(for: instance.id)
            await endLiveActivity(for: instance.id)
            instance.countdown = nil
        }
        
        // Update the instance in the array with animation
        withAnimation {
            instances[index] = instance
        }
        
        // Force a UI update
        objectWillChange.send()
        
        print("📊 Final auto-stop state for instance \(instanceId):")
        print("  • Instance state:")
        print("    - Auto-stop enabled: \(instance.autoStopEnabled)")
        print("    - Countdown: \(instance.countdown ?? "nil")")
        print("    - Config exists: \(autoStopConfigs[instance.id] != nil)")
        
        if let settings = AutoStopSettingsService.shared.getSettings(for: instance.id) {
            print("  • Settings state:")
            print("    - Enabled: \(settings.isEnabled)")
            print("    - Stop time: \(String(describing: settings.stopTime))")
        }
    }
    
    private func endLiveActivity(for instanceId: String) async {
        // No-op - Live Activities removed
    }
    
    private func updateLiveActivities() {
        // No-op - Live Activities removed
    }
    
    // Update cancelAutoStop to remove Live Activities
    func cancelAutoStop(for instanceId: String) async {
        guard let index = instances.firstIndex(where: { $0.id == instanceId }) else { return }
        
        // Clear notifications
        await clearNotifications(for: instanceId)
        
        // Update the instance
        let updatedInstance = instances[index]
        let instance = EC2Instance(
            id: updatedInstance.id,
            instanceType: updatedInstance.instanceType,
            state: updatedInstance.state,
            name: updatedInstance.name,
            launchTime: updatedInstance.launchTime,
            publicIP: updatedInstance.publicIP,
            privateIP: updatedInstance.privateIP,
            autoStopEnabled: updatedInstance.autoStopEnabled,
            countdown: nil,
            stateTransitionTime: updatedInstance.stateTransitionTime,
            hourlyRate: updatedInstance.hourlyRate,
            runtime: updatedInstance.runtime,
            currentCost: updatedInstance.currentCost,
            projectedDailyCost: updatedInstance.projectedDailyCost,
            region: updatedInstance.region
        )
        
        // Remove from autoStopConfigs
        autoStopConfigs.removeValue(forKey: instance.id)
        
        // Update the instance in the array
        instances[index] = instance
        
        print("Auto-stop cancelled for instance \(instanceId)")
    }
    
    // Update scheduleWarningNotifications to use more frequent intervals
    private func scheduleWarningNotifications(for instanceId: String, stopTime: Date) async {
        print("\n📅 Scheduling notifications for instance \(instanceId):")
        print("  • Stop time: \(stopTime)")
        
        // Check notification settings using shared instance
        let notificationSettings = NotificationSettingsViewModel.shared
        guard notificationSettings.autoStopWarningsEnabled else {
            print("  ℹ️ Auto-stop warnings are disabled in settings")
            // Clear any existing notifications since warnings are disabled
            await clearNotifications(for: instanceId)
            return
        }
        
        // Use more intervals: 2 hours, 1 hour, 30 mins, 15 mins, 10 mins, 5 mins, 2 mins, 1 min
        let intervals = [7200, 3600, 1800, 900, 600, 300, 120, 60]
        print("  • Warning intervals: \(intervals.map { formatInterval($0) })")
        
        // First, clear any existing notifications
        await clearNotifications(for: instanceId)
        
        let timeInterval = stopTime.timeIntervalSinceNow
        
        // Schedule warning notifications if countdown updates are enabled
        if notificationSettings.autoStopCountdownEnabled {
            for interval in intervals where timeInterval > Double(interval) {
                let warningTime = stopTime.addingTimeInterval(-Double(interval))
                
                if warningTime > Date() {
                    let content = UNMutableNotificationContent()
                    content.title = "⏰ Auto-Stop Warning"
                    if let instance = instances.first(where: { $0.id == instanceId }) {
                        content.body = "Instance '\(instance.name ?? instanceId)' will stop in \(formatInterval(interval))"
                    }
                    content.sound = .default
                    content.interruptionLevel = .timeSensitive
                    
                    let trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: warningTime.timeIntervalSinceNow,
                        repeats: false
                    )
                    
                    let request = UNNotificationRequest(
                        identifier: "\(instanceId)-warning-\(interval)",
                        content: content,
                        trigger: trigger
                    )
                    
                    do {
                        try await UNUserNotificationCenter.current().add(request)
                        print("  ✅ Warning scheduled for \(formatInterval(interval)) before stop")
                    } catch {
                        print("  ❌ Failed to schedule warning: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            print("  ℹ️ Countdown updates are disabled in settings")
        }
        
        // Schedule the final notification
        let finalContent = UNMutableNotificationContent()
        finalContent.title = "🛑 Instance Auto-Stopped"
        if let instance = instances.first(where: { $0.id == instanceId }) {
            finalContent.body = "Instance '\(instance.name ?? instanceId)' has been automatically stopped"
        }
        finalContent.sound = .default
        finalContent.interruptionLevel = .timeSensitive
        
        let finalTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )
        
        let finalRequest = UNNotificationRequest(
            identifier: "\(instanceId)-autostop",
            content: finalContent,
            trigger: finalTrigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(finalRequest)
            print("  ✅ Final notification scheduled")
        } catch {
            print("  ❌ Failed to schedule final notification: \(error.localizedDescription)")
        }
    }
    
    private func formatInterval(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            if remainingMinutes > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s") and \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s")"
            }
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes) minute\(minutes == 1 ? "" : "s") and \(remainingSeconds) second\(remainingSeconds == 1 ? "" : "s")"
            }
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
    
    // Add this method to verify auto-stop configuration
    func verifyAutoStopConfig(for instanceId: String) {
        print("\n🔍 Verifying auto-stop config for instance \(instanceId)")
        
        if let config = autoStopConfigs[instanceId] {
            print("  • Found config:")
            print("    - Stop time: \(config.stopTime)")
            print("    - Time remaining: \(Int(config.stopTime.timeIntervalSinceNow)) seconds")
        } else {
            print("  ❌ No config found")
        }
        
        if let instance = instances.first(where: { $0.id == instanceId }) {
            print("  • Instance state:")
            print("    - Auto-stop enabled: \(instance.autoStopEnabled)")
            print("    - Countdown: \(instance.countdown ?? "Not set")")
        } else {
            print("  ❌ Instance not found")
        }
    }
    
    // Add this method to debug auto-stop configurations
    private func debugAutoStopState() {
        print("\n🔍 Current Auto-Stop State:")
        print("  • Number of configs: \(autoStopConfigs.count)")
        print("  • Configs: \(autoStopConfigs)")
        
        for (instanceId, config) in autoStopConfigs {
            print("\n  Instance: \(instanceId)")
            print("    • Stop time: \(config.stopTime)")
            print("    • Time remaining: \(Int(config.stopTime.timeIntervalSinceNow)) seconds")
            
            if let instance = instances.first(where: { $0.id == instanceId }) {
                print("    • Instance state: \(instance.state.rawValue)")
                print("    • Auto-stop enabled: \(instance.autoStopEnabled)")
                print("    • Countdown: \(instance.countdown ?? "Not set")")
            } else {
                print("    ❌ Instance not found")
            }
        }
    }
    
    // Add stopAutoStopMonitoring function
    private func stopAutoStopMonitoring() {
        print("\n🛑 Stopping auto-stop monitoring")
        
        // Invalidate and clear all timers
        autoStopUpdateTimer?.invalidate()
        autoStopUpdateTimer = nil
        
        for (_, timer) in autoStopTimers {
            timer.invalidate()
        }
        autoStopTimers.removeAll()
        
        for (_, timer) in countdownTimers {
            timer.invalidate()
        }
        countdownTimers.removeAll()
        
        print("  ✅ Auto-stop monitoring stopped")
    }
    
    // Update clearNotifications to handle all intervals
    private func clearNotifications(for instanceId: String) async {
        let intervals = [7200, 3600, 1800, 900, 600, 300, 120, 60]
        var notificationIds = ["\(instanceId)-autostop"]
        
        // Add all warning notification IDs
        notificationIds.append(contentsOf: intervals.map { "\(instanceId)-warning-\($0)" })
        
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: notificationIds)
        center.removeDeliveredNotifications(withIdentifiers: notificationIds)
        
        print("  ✅ Cleared all notifications for instance \(instanceId)")
    }
    
    // Update checkAutoStopConfigurations to be async
    private func checkAutoStopConfigurations() async {
        print("\n⏰ Checking auto-stop configurations...")
        
        // Load configurations from settings if autoStopConfigs is empty
        if autoStopConfigs.isEmpty {
            for instance in instances {
                // Only load configs for running instances
                if instance.state == .running,
                   let settings = AutoStopSettingsService.shared.getSettings(for: instance.id),
                   settings.isEnabled,
                   let stopTime = settings.stopTime {
                    autoStopConfigs[instance.id] = AutoStopConfig(instanceId: instance.id, stopTime: stopTime)
                    print("  • Loaded config for \(instance.id): stop at \(stopTime)")
                }
            }
        }
        
        // Create a copy to avoid modifying while iterating
        let configsToCheck = autoStopConfigs
        
        // Store original configuration
        guard let originalConfig = AWSServiceManager.default().defaultServiceConfiguration else {
            print("❌ No AWS configuration found")
            return
        }
        
        // Check each configuration
        for (instanceId, config) in configsToCheck {
            let timeRemaining = config.stopTime.timeIntervalSinceNow
            print("  • Instance \(instanceId): \(Int(timeRemaining))s remaining")
            
            if timeRemaining <= 0 {
                print("  • Stop time reached for \(instanceId)")
                
                // Find the instance to get its region
                if let instance = instances.first(where: { $0.id == instanceId }) {
                    // Configure AWS for the instance's region
                    do {
                        let credentials = try KeychainManager.shared.retrieveCredentials()
                        let regionConfig = AWSServiceConfiguration(
                            region: mapRegionToAWSType(instance.region),
                            credentialsProvider: AWSStaticCredentialsProvider(
                                accessKey: credentials.accessKeyId,
                                secretKey: credentials.secretAccessKey
                            )
                        )!
                        
                        // Set configuration for this region
                        AWSServiceManager.default().defaultServiceConfiguration = regionConfig
                        
                        // Remove config before stopping to prevent repeated attempts
                        autoStopConfigs.removeValue(forKey: instanceId)
                        
                        // Clear settings after successful stop
                        AutoStopSettingsService.shared.clearSettings(for: instanceId)
                        
                        // Stop the instance
                        try await stopInstance(instanceId)
                        
                        // Send notification about successful auto-stop
                        try await FirebaseNotificationService.shared.sendInstanceStateNotification(
                            instanceId: instance.id,
                            instanceName: instance.name ?? instance.id,
                            oldState: instance.state.rawValue,
                            newState: "stopped"
                        )
                    } catch {
                        print("  ❌ Failed to stop instance: \(error.localizedDescription)")
                        // Send error notification
                        try? await FirebaseNotificationService.shared.sendErrorNotification(
                            instanceId: instanceId,
                            error: error
                        )
                    }
                }
            }
        }
        
        // Restore original configuration
        AWSServiceManager.default().defaultServiceConfiguration = originalConfig
        
        // Stop monitoring if no configs are active
        if autoStopConfigs.isEmpty {
            stopAutoStopMonitoring()
        }
    }
    
    private func mapRegionToAWSType(_ region: String) -> AWSRegionType {
        switch region {
            case "us-east-1": return .USEast1
            case "us-east-2": return .USEast2
            case "us-west-1": return .USWest1
            case "us-west-2": return .USWest2
            case "eu-west-1": return .EUWest1
            case "eu-west-2": return .EUWest2
            case "eu-central-1": return .EUCentral1
            case "ap-southeast-1": return .APSoutheast1
            case "ap-southeast-2": return .APSoutheast2
            case "ap-northeast-1": return .APNortheast1
            case "ap-northeast-2": return .APNortheast2
            case "sa-east-1": return .SAEast1
            default: return .USEast1
        }
    }
    
    // Add startAutoStopMonitoring function
    private func startAutoStopMonitoring() {
        print("\n🔄 Starting auto-stop monitoring")
        
        // Invalidate existing timer
        autoStopUpdateTimer?.invalidate()
        autoStopUpdateTimer = nil
        
        // Create new timer that runs every second to update countdowns
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                print("\n🔄 Auto-stop monitoring tick")
                print("  • Active configs: \(self.autoStopConfigs.count)")
                
                // Update countdowns for all active configs
                for (instanceId, config) in self.autoStopConfigs {
                    await self.updateCountdown(for: instanceId, stopTime: config.stopTime)
                }
                
                // Check configurations every 5 seconds
                if Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 5) < 1 {
                    await self.checkAutoStopConfigurations()
                }
            }
        }
        
        // Make sure timer stays valid by adding it to the main run loop
        RunLoop.main.add(timer, forMode: .common)
        autoStopUpdateTimer = timer
        
        // Force an immediate check
        Task { @MainActor [weak self] in
            await self?.checkAutoStopConfigurations()
        }
        
        print("\n📊 Monitoring summary:")
        print("  • Timer scheduled and started")
        print("  • Current configs: \(autoStopConfigs)")
    }
    
    // Add restoreAutoStopTimers function
    func restoreAutoStopTimers() async {
        print("\n🔄 Restoring auto-stop timers")
        
        // First, stop monitoring and clear all existing timers
        stopAutoStopMonitoring()
        
        // Clear all existing timers and configs
        autoStopTimers.removeAll()
        countdownTimers.removeAll()
        autoStopConfigs.removeAll()
        
        // Get all settings first
        let allSettings = AutoStopSettingsService.shared.getAllSettings()
        print("📊 Current settings:")
        print("  • Number of settings: \(allSettings.count)")
        
        // Restore configurations from settings and update instance states
        for (index, instance) in instances.enumerated() {
            if let settings = allSettings[instance.id] {
                print("\n🔍 Restoring settings for instance \(instance.id)")
                print("  • Found settings: \(settings)")
                
                let updatedInstance = EC2Instance(
                    id: instance.id,
                    instanceType: instance.instanceType,
                    state: instance.state,
                    name: instance.name,
                    launchTime: instance.launchTime,
                    publicIP: instance.publicIP,
                    privateIP: instance.privateIP,
                    autoStopEnabled: settings.isEnabled,
                    countdown: settings.stopTime != nil ? DateFormatter.localizedString(from: settings.stopTime!, dateStyle: .none, timeStyle: .short) : (settings.isEnabled ? "Set time" : nil),
                    stateTransitionTime: instance.stateTransitionTime,
                    hourlyRate: instance.hourlyRate,
                    runtime: instance.runtime,
                    currentCost: instance.currentCost,
                    projectedDailyCost: instance.projectedDailyCost,
                    region: instance.region
                )
                
                // Update instance in array with animation
                withAnimation {
                    instances[index] = updatedInstance
                }
            }
        }
        
        // Start monitoring if we have any configurations
        if !autoStopConfigs.isEmpty {
            startAutoStopMonitoring()
        }
        
        // Force a UI update
        objectWillChange.send()
        
        print("\n📊 Restore summary:")
        print("  • Restored configs count: \(autoStopConfigs.count)")
        print("  • Current configs: \(autoStopConfigs)")
        print("  ✅ Auto-stop timers restored")
    }
    
    @MainActor
    private func updateCountdown(for instanceId: String, stopTime: Date) async {
        print("\n⏱️ Updating countdown for instance \(instanceId)")
        guard let index = instances.firstIndex(where: { $0.id == instanceId }) else {
            print("  ❌ Instance not found")
            return
        }
        
        let timeRemaining = stopTime.timeIntervalSince(Date())
        print("  • Time remaining: \(timeRemaining) seconds")
        
        let updatedInstance = instances[index]
        
        if timeRemaining <= 0 {
            print("  • Time has elapsed, stopping instance")
            do {
                await cancelAutoStop(for: instanceId)
                try await stopInstance(instanceId)
            } catch {
                print("  ❌ Failed to stop instance: \(error.localizedDescription)")
            }
        } else {
            // Format and display the actual stop time
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let stopTimeDisplay = formatter.string(from: stopTime)
            
            // Only update if the display has changed
            if updatedInstance.countdown != stopTimeDisplay {
                print("  • Updating stop time display to: \(stopTimeDisplay)")
                let instance = EC2Instance(
                    id: updatedInstance.id,
                    instanceType: updatedInstance.instanceType,
                    state: updatedInstance.state,
                    name: updatedInstance.name,
                    launchTime: updatedInstance.launchTime,
                    publicIP: updatedInstance.publicIP,
                    privateIP: updatedInstance.privateIP,
                    autoStopEnabled: updatedInstance.autoStopEnabled,
                    countdown: stopTimeDisplay,
                    stateTransitionTime: updatedInstance.stateTransitionTime,
                    hourlyRate: updatedInstance.hourlyRate,
                    runtime: updatedInstance.runtime,
                    currentCost: updatedInstance.currentCost,
                    projectedDailyCost: updatedInstance.projectedDailyCost,
                    region: updatedInstance.region
                )
                instances[index] = instance
            }
        }
    }
    
    func setupAutoStop(for instanceId: String, at stopTime: Date) async throws {
        print("\n⏰ Setting up auto-stop for instance \(instanceId) at \(stopTime)")
        
        guard let index = instances.firstIndex(where: { $0.id == instanceId }) else {
            print("  ❌ Instance not found")
            return
        }
        
        // Create and store the auto-stop configuration
        autoStopConfigs[instanceId] = AutoStopConfig(instanceId: instanceId, stopTime: stopTime)
        
        // Save settings
        AutoStopSettingsService.shared.saveSettings(
            for: instanceId,
            enabled: true,
            time: stopTime
        )
        
        // Schedule notifications
        await scheduleWarningNotifications(for: instanceId, stopTime: stopTime)
        
        // Update instance display
        let updatedInstance = instances[index]
        let instance = EC2Instance(
            id: updatedInstance.id,
            instanceType: updatedInstance.instanceType,
            state: updatedInstance.state,
            name: updatedInstance.name,
            launchTime: updatedInstance.launchTime,
            publicIP: updatedInstance.publicIP,
            privateIP: updatedInstance.privateIP,
            autoStopEnabled: true,
            countdown: DateFormatter.localizedString(from: stopTime, dateStyle: .none, timeStyle: .short),
            stateTransitionTime: updatedInstance.stateTransitionTime,
            hourlyRate: updatedInstance.hourlyRate,
            runtime: updatedInstance.runtime,
            currentCost: updatedInstance.currentCost,
            projectedDailyCost: updatedInstance.projectedDailyCost,
            region: updatedInstance.region
        )
        
        // Update the instance in the array
        instances[index] = instance
        
        // Start monitoring if not already running
        startAutoStopMonitoring()
        
        print("✅ Auto-stop setup complete")
    }
    
    private func generateStartNotificationText(instanceName: String) -> String {
        let startEmojis = ["🚀", "✨", "💫", "⚡️", "🌟"]
        let randomEmoji = startEmojis.randomElement() ?? "🚀"
        
        let phrases = [
            "Blast off! \(instanceName) is ready to rock! \(randomEmoji)",
            "Wakey wakey! \(instanceName) is up and running! \(randomEmoji)",
            "Power up! \(instanceName) is ready for action! \(randomEmoji)",
            "Engines on! \(instanceName) has joined the party! \(randomEmoji)",
            "Ready to roll! \(instanceName) is now online! \(randomEmoji)"
        ]
        
        return phrases.randomElement() ?? "Instance \(instanceName) started \(randomEmoji)"
    }
    
    private func generateStopNotificationText(instanceName: String, isAutoStop: Bool) -> String {
        let stopEmojis = ["💤", "🌙", "🎬", "⭐️", "🌟"]
        let randomEmoji = stopEmojis.randomElement() ?? "💤"
        
        if isAutoStop {
            let phrases = [
                "Time's up! \(instanceName) is taking a nap! \(randomEmoji)",
                "Auto-pilot engaged! \(instanceName) is going to sleep! \(randomEmoji)",
                "Mission accomplished! \(instanceName) is powering down! \(randomEmoji)",
                "That's a wrap! \(instanceName) is calling it a day! \(randomEmoji)",
                "Scheduled snooze! \(instanceName) is hitting the hay! \(randomEmoji)"
            ]
            return phrases.randomElement() ?? "Instance \(instanceName) auto-stopped \(randomEmoji)"
        } else {
            let phrases = [
                "Nap time! \(instanceName) is getting some rest! \(randomEmoji)",
                "Break time! \(instanceName) is taking five! \(randomEmoji)",
                "Shutdown success! \(instanceName) is off duty! \(randomEmoji)",
                "All done! \(instanceName) is clocking out! \(randomEmoji)",
                "Time to chill! \(instanceName) is powering down! \(randomEmoji)"
            ]
            return phrases.randomElement() ?? "Instance \(instanceName) stopped \(randomEmoji)"
        }
    }
    
    private func clearInstanceData(for instance: EC2Instance) {
        // Clear instance data from UserDefaults
        UserDefaults.standard.removeObject(forKey: getRuntimeKey(for: Date(), instanceId: instance.id))
        
        // Clear widget data
        WidgetService.shared.clearWidgetData(for: instance.region)
    }
    
    private func handleInstanceStateChange(_ instance: EC2Instance, region: String) {
        Task {
            do {
                try await InstanceMonitoringService.shared.handleInstanceStateChange(instance, region: region)
            } catch {
                print("❌ Failed to handle instance state change: \(error)")
            }
        }
    }
    
    private func updateInstance(_ instance: EC2Instance, state: InstanceState) {
        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            let oldState = instances[index].state
            let updatedInstance = instances[index]
            updatedInstance.state = state
            instances[index] = updatedInstance
            
            if oldState != state {
                Task {
                    do {
                        try await FirebaseNotificationService.shared.handleInstanceStateChange(
                            instanceId: instance.id,
                            instanceName: instance.name ?? instance.id,
                            region: instance.region,
                            oldState: oldState.rawValue,
                            newState: state.rawValue,
                            launchTime: instance.launchTime
                        )
                        handleInstanceStateChange(updatedInstance, region: instance.region)
                    } catch {
                        print("❌ Failed to handle instance state change: \(error)")
                    }
                }
            }
        }
    }
    
    func getInstanceDetails(_ instanceId: String, region: String? = nil) async throws -> EC2Instance? {
        let targetRegion = region ?? currentRegion
        
        // Ensure we have valid credentials
        let authManager = AuthenticationManager.shared
        let credentials = try authManager.getAWSCredentials()
        
        // Configure AWS services with credentials
        let credentialsProvider = AWSStaticCredentialsProvider(
            accessKey: credentials.accessKeyId,
            secretKey: credentials.secretAccessKey
        )
        
        let configuration = AWSServiceConfiguration(
            region: authManager.selectedRegion.awsRegionType,
            credentialsProvider: credentialsProvider
        )!
        
        // Set the default configuration
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Register EC2 with this configuration
        AWSEC2.register(with: configuration, forKey: "GetInstanceDetails")
        let ec2Client = AWSEC2(forKey: "GetInstanceDetails")
        
        let request = AWSEC2DescribeInstancesRequest()!
        request.instanceIds = [instanceId]
        
        do {
            let result = try await ec2Client.describeInstances(request)
            guard let reservation = result.reservations?.first,
                  let instance = reservation.instances?.first else {
                return nil
            }
            
            return createInstance(from: instance, region: targetRegion)
        } catch {
            print("❌ Failed to get instance details for \(instanceId): \(error)")
            throw error
        }
    }
    
    func listInstances(region: String? = nil) async throws -> [EC2Instance] {
        let targetRegion = region ?? currentRegion
        let request = AWSEC2DescribeInstancesRequest()!
        
        do {
            let result = try await AWSEC2.default().describeInstances(request)
            var instances: [EC2Instance] = []
            
            for reservation in result.reservations ?? [] {
                for instance in reservation.instances ?? [] {
                    if let ec2Instance = createInstance(from: instance, region: targetRegion) {
                        instances.append(ec2Instance)
                    }
                }
            }
            
            return instances
        } catch {
            print("❌ Failed to list instances: \(error)")
            throw error
        }
    }
    
    func handleInstanceStateChange(instanceId: String, region: String, state: InstanceState, launchTime: Date) async throws {
        // Ensure region is properly formatted
        let formattedRegion = region.lowercased().replacingOccurrences(of: " ", with: "-")
        
        // Convert launchTime to proper format
        let dateFormatter = ISO8601DateFormatter()
        let formattedLaunchTime = dateFormatter.string(from: launchTime)
        
        // Refresh ID token
        guard let idToken = try await refreshIDToken() else {
            throw EC2ServiceError.tokenRefreshFailed
        }
        
        // Prepare data for Firebase
        let data: [String: Any] = [
            "instanceId": instanceId,
            "region": formattedRegion,
            "state": state.rawValue,
            "launchTime": formattedLaunchTime
        ]
        
        // Send to Firebase
        try await sendToFirebase(data: data, idToken: idToken)
        
        // Handle state change
        switch state {
        case .stopped:
            try await stopInstance(instanceId)
        case .running:
            try await startInstance(instanceId)
        case .terminated:
            try await terminateInstance(instanceId)
        case .pending, .shuttingDown, .stopping, .unknown:
            break // No specific action needed for these states
        @unknown default:
            break
        }
        
        // Add this block to handle stopped state
        if state == .stopped {
            // Clear runtime alerts for this instance
            await clearRuntimeAlerts(for: instanceId)
            try? await logger.call([
                "message": "🗑️ Cleared runtime alerts for stopped instance: \(instanceId)",
                "level": "info"
            ])
        }
    }
    
    private func refreshIDToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        do {
            let token = try await user.getIDToken()
            return token
        } catch {
            throw EC2ServiceError.tokenRefreshFailed
        }
    }
    
    private func sendToFirebase(data: [String: Any], idToken: String) async throws {
        let db = Firestore.firestore()
        let document = db.collection("instanceStateChanges").document()
        
        do {
            try await document.setData(data)
        } catch {
            throw EC2ServiceError.firebaseSendFailed
        }
    }
    
    private func clearRuntimeAlerts(for instanceId: String) async {
        print("\n🧹 Clearing runtime alerts for instance \(instanceId)")
        
        do {
            // Get instance region
            guard let instance = instances.first(where: { $0.id == instanceId }) else {
                print("❌ Instance not found for clearing alerts: \(instanceId)")
                return
            }
            
            print("  • Found instance in region: \(instance.region)")
            
            // Clear all alerts for this instance in a single operation
            try await runtimeAlertManager.clearInstanceAlerts(instanceId: instanceId, region: instance.region)
            
            // Clear auto-stop settings
            AutoStopSettingsService.shared.clearSettings(for: instanceId)
            print("  • Cleared auto-stop settings")
            
            // Remove from autoStopConfigs
            autoStopConfigs.removeValue(forKey: instanceId)
            print("  • Removed from auto-stop configs")
            
            // Clear notifications
            await clearNotifications(for: instanceId)
            print("  • Cleared notifications")
            
            // Update instance state if needed
            if let index = instances.firstIndex(where: { $0.id == instanceId }) {
                let updatedInstance = instances[index]
                instances[index] = EC2Instance(
                    id: updatedInstance.id,
                    instanceType: updatedInstance.instanceType,
                    state: updatedInstance.state,
                    name: updatedInstance.name,
                    launchTime: updatedInstance.launchTime,
                    publicIP: updatedInstance.publicIP,
                    privateIP: updatedInstance.privateIP,
                    autoStopEnabled: false,
                    countdown: nil,
                    stateTransitionTime: updatedInstance.stateTransitionTime,
                    hourlyRate: updatedInstance.hourlyRate,
                    runtime: updatedInstance.runtime,
                    currentCost: updatedInstance.currentCost,
                    projectedDailyCost: updatedInstance.projectedDailyCost,
                    region: updatedInstance.region
                )
                print("  • Updated instance state")
            }
            
            // Log success using Firebase Functions
            try await logger.call([
                "message": "✅ Successfully cleared all runtime alerts and configurations for instance \(instanceId)",
                "level": "info"
            ])
            
            // Notify that runtime alerts have been cleared
            NotificationCenter.default.post(
                name: NSNotification.Name("RuntimeAlertsCleared"),
                object: instanceId
            )
            
            print("✅ Successfully cleared all runtime alerts and related configurations")
        } catch {
            print("❌ Failed to clear runtime alerts for instance \(instanceId): \(error)")
            // Log error using Firebase Functions
            try? await logger.call([
                "message": "❌ Failed to clear runtime alerts for instance \(instanceId): \(error)",
                "level": "error"
            ])
        }
    }
}

// Add this computed property to EC2Instance
extension EC2Instance {
    var formattedRuntime: String {
        let hours = Int(floor(Double(runtime) / 3600))
        let minutes = Int(floor(Double(runtime).truncatingRemainder(dividingBy: 3600) / 60))
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

// Add this enum at the top of the file, before the EC2Service class
enum EC2ServiceError: Error {
    case tokenRefreshFailed
    case firebaseSendFailed
    case instanceOperationFailed
}