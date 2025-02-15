import Foundation
import AWSEC2
import AWSCore
import Combine
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    private static let _shared = DashboardViewModel()
    
    static var shared: DashboardViewModel {
        return _shared
    }
    
    @Published private(set) var instances: [EC2Instance] = []
    @Published private(set) var costMetrics: CostMetrics?
    @Published private(set) var isLoading = false
    @Published private(set) var isRegionSwitching = false
    @Published private(set) var isPerformingAction = false
    @Published var showStartAllConfirmation = false
    @Published var showStopAllConfirmation = false
    @Published var error: String?
    @Published private(set) var currentRegion: String = "us-east-1"
    
    private let ec2Service = EC2Service.shared
    private let cloudWatchService = CloudWatchService.shared
    
    var runningInstancesCount: Int {
        instances.filter { $0.state == .running }.count
    }
    
    var stoppedInstancesCount: Int {
        instances.filter { $0.state == .stopped }.count
    }
    
    var hasRunningInstances: Bool {
        runningInstancesCount > 0
    }
    
    var hasStoppedInstances: Bool {
        stoppedInstancesCount > 0
    }
    
    private let instanceHourlyRates: [String: Double] = [
        "t2.micro": 0.0116,
        "t2.small": 0.023,
        "t2.medium": 0.0464,
        "t2.large": 0.0928,
        "t3.micro": 0.0104,
        "t3.small": 0.0208,
        "t3.medium": 0.0416,
        "t3.large": 0.0832
    ]
    
    init() {}
    
    func changeRegion(_ region: AWSRegion) async {
        do {
            // Get current credentials
            let credentials = try AuthenticationManager.shared.getAWSCredentials()
            
            // Configure AWS services for new region
            try await AWSManager.shared.configure(
                accessKey: credentials.accessKeyId,
                secretKey: credentials.secretAccessKey,
                region: region.awsRegionType
            )
            
            // Update EC2Service configuration
            EC2Service.shared.updateConfiguration(
                with: credentials,
                region: region.awsRegionType
            )
            
            // Refresh instances in new region
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func startAllInstances() async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        
        do {
            let stoppedInstances = instances.filter { $0.state == .stopped }
            try await ec2Service.startInstances(stoppedInstances.map { $0.id })
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func stopAllInstances() async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        
        do {
            let runningInstances = instances.filter { $0.state == .running }
            try await ec2Service.stopInstances(runningInstances.map { $0.id })
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func refresh() async {
        guard !isLoading else { return }
        
        isLoading = true
        isRegionSwitching = false
        defer { isLoading = false }
        
        do {
            async let instancesTask = ec2Service.fetchInstances()
            let fetchedInstances = try await instancesTask
            
            // Track existing instance IDs and states for change detection
            let existingInstanceStates = Dictionary(uniqueKeysWithValues: instances.map { ($0.id, $0.state) })
            
            // Check for state changes and apply alerts
            let notificationSettings = NotificationSettingsViewModel.shared
            let alertsEnabled = notificationSettings.isRuntimeAlertsEnabled(for: currentRegion)
            let hasAlerts = !notificationSettings.getAlertsForRegion(currentRegion).isEmpty
            
            if alertsEnabled && hasAlerts {
                print("\n📝 Processing alerts for region \(currentRegion)")
                print("  • Alerts enabled: \(alertsEnabled)")
                print("  • Has alerts: \(hasAlerts)")
                
                for instance in fetchedInstances {
                    if instance.state == .running {
                        let oldState = existingInstanceStates[instance.id]
                        let isNewInstance = oldState == nil
                        let stateChanged = oldState != nil && oldState != .running
                        
                        if isNewInstance {
                            print("\n📝 New running instance detected: \(instance.id)")
                            print("  • Name: \(instance.name ?? "unnamed")")
                            print("  • Launch Time: \(instance.launchTime?.description ?? "unknown")")
                            
                            await notificationSettings.handleInstanceStateChange(
                                instanceId: instance.id,
                                instanceName: instance.name ?? instance.id,
                                region: currentRegion,
                                state: "running",
                                launchTime: instance.launchTime
                            )
                        } else if stateChanged {
                            print("\n📝 Instance state changed to running: \(instance.id)")
                            print("  • Name: \(instance.name ?? "unnamed")")
                            print("  • Previous state: \(oldState?.rawValue ?? "unknown")")
                            print("  • Launch Time: \(instance.launchTime?.description ?? "unknown")")
                            
                            await notificationSettings.handleInstanceStateChange(
                                instanceId: instance.id,
                                instanceName: instance.name ?? instance.id,
                                region: currentRegion,
                                state: "running",
                                launchTime: instance.launchTime
                            )
                        }
                    }
                }
            }
            
            instances = fetchedInstances
            
            // Fetch cost metrics after we have instances
            costMetrics = try await cloudWatchService.fetchCostMetrics(for: instances)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func switchRegion(_ region: AWSRegion) async {
        guard !isLoading else { return }
        isLoading = true
        isRegionSwitching = true
        defer { 
            isLoading = false
            isRegionSwitching = false
        }
        
        do {
            // Clear current instances first
            instances = []
            costMetrics = nil
            
            // Configure AWS services for new region
            let credentials = try AuthenticationManager.shared.getAWSCredentials()
            try await AWSManager.shared.configure(
                accessKey: credentials.accessKeyId,
                secretKey: credentials.secretAccessKey,
                region: region.awsRegionType
            )
            
            // Update EC2Service configuration
            EC2Service.shared.updateConfiguration(
                with: credentials,
                region: region.awsRegionType
            )
            
            // Update current region
            currentRegion = region.rawValue
            
            // Fetch new data
            let fetchedInstances = try await ec2Service.fetchInstances()
            instances = fetchedInstances
            
            if !instances.isEmpty {
                costMetrics = try await cloudWatchService.fetchCostMetrics(for: instances)
            }
            
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func toggleAutoStop(for instanceId: String, enabled: Bool) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        
        do {
            try await ec2Service.toggleAutoStop(for: instanceId, isEnabled: enabled)
            // The EC2Service now handles all state updates, no need to modify the instance here
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func setAutoStopTime(for instanceId: String, time: Date) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        
        do {
            try await ec2Service.setupAutoStop(for: instanceId, at: time)
            // The EC2Service now handles all state updates, no need to modify the instance here
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func calculateCosts() {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        // Calculate today's cost
        let dailyCost = instances.reduce(into: 0.0) { total, instance in
            guard let rate = instanceHourlyRates[instance.instanceType] else {
                return
            }
            
            // Get activities for today only
            let activities = EC2Service.shared.getActivities(for: instance.id)
                .filter { $0.timestamp >= startOfDay }
            
            let todayRuntime = activities.reduce(0) { $0 + $1.runtime }
            total += (todayRuntime / 3600.0 * rate)
        }
        
        // Calculate month-to-date cost
        let monthlyCost = instances.reduce(into: 0.0) { total, instance in
            guard let rate = instanceHourlyRates[instance.instanceType] else {
                return
            }
            
            // Get activities for this month only
            let activities = EC2Service.shared.getActivities(for: instance.id)
                .filter { $0.timestamp >= startOfMonth }
            
            let monthRuntime = activities.reduce(0) { $0 + $1.runtime }
            total += (monthRuntime / 3600.0 * rate)
        }
        
        // Calculate projected cost based on current running instances
        let projected = instances.reduce(into: 0.0) { total, instance in
            guard instance.state == .running,
                  let rate = instanceHourlyRates[instance.instanceType] else {
                return
            }
            total += (rate * 24) // Daily rate for running instances
        }
        
        // Update the cost metrics
        costMetrics = CostMetrics(
            dailyCost: (dailyCost * 100).rounded() / 100,
            monthlyCost: (monthlyCost * 100).rounded() / 100,
            projectedCost: (projected * 100).rounded() / 100
        )
    }
    
    func startInstance(_ instanceId: String) async throws {
        isLoading = true
        isPerformingAction = true
        defer { 
            isLoading = false
            isPerformingAction = false 
        }
        
        do {
            try await ec2Service.startInstance(instanceId)
            
            // First refresh to get the latest state
            await refresh()
            
            // Get instance details and apply alerts
            if let instance = instances.first(where: { $0.id == instanceId }) {
                // Explicitly check if alerts should be applied
                let notificationSettings = NotificationSettingsViewModel.shared
                let alertsEnabled = notificationSettings.isRuntimeAlertsEnabled(for: currentRegion)
                let hasAlerts = !notificationSettings.getAlertsForRegion(currentRegion).isEmpty
                
                if alertsEnabled && hasAlerts {
                    print("📝 Applying alerts to newly started instance: \(instanceId)")
                    // Use instance.launchTime instead of current date to ensure correct timing
                    await notificationSettings.handleInstanceStateChange(
                        instanceId: instanceId,
                        instanceName: instance.name ?? instanceId,
                        region: currentRegion,
                        state: "running",
                        launchTime: instance.launchTime
                    )
                } else {
                    print("ℹ️ Skipping alerts for instance \(instanceId): enabled=\(alertsEnabled), hasAlerts=\(hasAlerts)")
                }
            }
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
} 