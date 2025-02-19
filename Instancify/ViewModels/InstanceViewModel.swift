import Foundation
import SwiftUI
import AWSEC2

@MainActor
class InstanceViewModel: ObservableObject {
    @Published var instances: [EC2Instance] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let ec2Service = EC2Service.shared
    
    func refreshInstances() async {
        isLoading = true
        error = nil
        
        do {
            instances = try await ec2Service.listInstances()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func updateInstance(_ instance: EC2Instance) {
        DispatchQueue.main.async { [weak self] in
            if let index = self?.instances.firstIndex(where: { $0.id == instance.id }) {
                self?.instances[index] = instance
            }
        }
    }
    
    func startInstance(_ instance: EC2Instance) async throws {
        try await ec2Service.startInstance(instance.id)
        await refreshInstances()
    }
    
    func stopInstance(_ instance: EC2Instance) async throws {
        try await ec2Service.stopInstance(instance.id)
        await refreshInstances()
    }
    
    func terminateInstance(_ instance: EC2Instance) async throws {
        try await ec2Service.terminateInstance(instance.id)
        await refreshInstances()
    }
    
    private func handleInstanceStateChange(_ instance: EC2Instance) async {
        print("\n🔄 Handling state change for instance \(instance.id)")
        print("  • Name: \(instance.name ?? "unnamed")")
        print("  • State: \(instance.state.rawValue)")
        print("  • Region: \(instance.region)")
        
        // Schedule runtime alerts when instance starts
        if instance.state == .running {
            print("\n⏰ Instance is running - scheduling runtime alerts")
            do {
                try await ScheduledNotifications.shared.scheduleRuntimeNotifications(
                    instanceId: instance.id,
                    instanceName: instance.name,
                    region: instance.region,
                    launchTime: Date()
                )
            } catch {
                print("❌ Failed to schedule runtime alerts: \(error)")
            }
        }
        
        // Clear runtime alerts when instance stops or terminates
        if instance.state == .stopped || instance.state == .terminated {
            print("\n🗑️ Instance stopped/terminated - clearing runtime alerts")
            do {
                try await FirebaseNotificationService.shared.clearInstanceAlerts(
                    instanceId: instance.id,
                    region: instance.region
                )
            } catch {
                print("❌ Failed to clear runtime alerts: \(error)")
            }
        }
        
        // Update instance state in UI
        DispatchQueue.main.async {
            if let index = self.instances.firstIndex(where: { $0.id == instance.id }) {
                self.instances[index] = instance
            }
        }
    }
} 