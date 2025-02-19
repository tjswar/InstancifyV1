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
    @Published private(set) var currentRegion: String = AuthenticationManager.shared.selectedRegion.rawValue {
        didSet {
            if oldValue != currentRegion {
                print("\n🌎 DashboardViewModel: Region changed from \(oldValue) to \(currentRegion)")
                // Clear all data for region change
                instances = []
                costMetrics = nil
                isRegionSwitching = true
                error = nil
                
                // Ensure EC2Service is in sync
                if ec2Service.currentRegion != currentRegion {
                    Task {
                        do {
                            let credentials = try AuthenticationManager.shared.getAWSCredentials()
                            ec2Service.updateConfiguration(
                                with: credentials,
                                region: currentRegion
                            )
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                
                // Refresh data for new region
                Task {
                    await refresh()
                }
            }
        }
    }
    
    private let ec2Service = EC2Service.shared
    private let cloudWatchService = CloudWatchService.shared
    private var regionObserver: NSObjectProtocol?
    
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
    
    init() {
        // Initialize with the current region from AuthenticationManager
        currentRegion = AuthenticationManager.shared.selectedRegion.rawValue
        
        // Listen for region changes
        regionObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RegionChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newRegion = notification.object as? String,
               let self = self {
                // Only update if the region is actually different
                if self.currentRegion != newRegion {
                    print("\n🌎 DashboardViewModel: Received region change notification: \(newRegion)")
                    Task { @MainActor in
                        // Clear current data
                        self.instances = []
                        self.costMetrics = nil
                        self.isRegionSwitching = true
                        
                        // Update region
                        self.currentRegion = newRegion
                        
                        // Ensure AWS is configured correctly
                        do {
                            let credentials = try AuthenticationManager.shared.getAWSCredentials()
                            EC2Service.shared.updateConfiguration(
                                with: credentials,
                                region: newRegion
                            )
                            // Force a refresh after region change
                            await self.refresh()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }
        }
        
        // Initial refresh with delay to ensure AWS is configured
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second delay
            await refresh()
        }
    }
    
    deinit {
        // Clean up observer
        if let observer = regionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func changeRegion(_ region: AWSRegion) async {
        guard region.rawValue != currentRegion else {
            print("🌎 Region is already set to \(region.rawValue)")
            return
        }
        
        do {
            print("\n🌎 DashboardViewModel: Changing region to \(region.rawValue)")
            isRegionSwitching = true
            
            // Update AuthenticationManager first as the source of truth
            AuthenticationManager.shared.selectedRegion = region
            
            // The rest will be handled by the currentRegion didSet observer
        } catch {
            self.error = error.localizedDescription
            isRegionSwitching = false
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
        defer { isLoading = false }
        
        do {
            // Ensure region consistency with AuthenticationManager
            let expectedRegion = AuthenticationManager.shared.selectedRegion.rawValue
            if currentRegion != expectedRegion {
                print("\n🌎 Region mismatch detected in DashboardViewModel")
                print("  • Current: \(currentRegion)")
                print("  • Expected: \(expectedRegion)")
                currentRegion = expectedRegion
                return // The didSet observer will trigger another refresh
            }
            
            // Ensure EC2Service is using the correct region
            if ec2Service.currentRegion != currentRegion {
                print("\n🌎 Updating EC2Service region to match dashboard")
                let credentials = try AuthenticationManager.shared.getAWSCredentials()
                ec2Service.updateConfiguration(
                    with: credentials,
                    region: currentRegion
                )
                // Add small delay after configuration update
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second delay
            }
            
            print("\n🔄 Refreshing dashboard for region: \(currentRegion)")
            let fetchedInstances = try await ec2Service.fetchInstances()
            
            // Only accept instances from current region
            instances = fetchedInstances.filter { $0.region == currentRegion }
            
            if !instances.isEmpty {
                costMetrics = try await cloudWatchService.fetchCostMetrics(for: instances)
            } else {
                costMetrics = nil
            }
            
            error = nil
            isRegionSwitching = false
            
            print("✅ Refresh completed for region: \(currentRegion)")
            print("  • Found \(instances.count) instances")
            
        } catch {
            self.error = error.localizedDescription
            isRegionSwitching = false
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
                region: region.rawValue
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