import SwiftUI
import AWSEC2

@MainActor
class InstanceDetailViewModel: ObservableObject {
    @Published var instance: EC2Instance
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false
    @Published var activities: [InstanceActivity] = []
    
    private let ec2Service = EC2Service.shared
    
    init(instance: EC2Instance) {
        self.instance = instance
        loadActivities()
    }
    
    private func loadActivities() {
        activities = InstanceActivity.loadActivities(for: instance.id)
    }
    
    @MainActor
    func updateFromService() {
        Task { @MainActor in
            if let updatedInstance = ec2Service.instances.first(where: { $0.id == instance.id }) {
                self.instance = updatedInstance
                loadActivities()
            }
        }
    }
    
    @MainActor
    func refresh() async {
        isLoading = true
        do {
            let instances = try await ec2Service.fetchInstances()
            if let updatedInstance = instances.first(where: { $0.id == instance.id }) {
                instance = updatedInstance
                loadActivities()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
        isLoading = false
    }
    
    @MainActor
    func performAction(_ action: InstanceAction) async {
        isLoading = true
        do {
            switch action {
            case .start:
                try await ec2Service.startInstance(instance.id)
                InstanceActivity.addActivity(
                    instanceId: instance.id,
                    type: .userAction,
                    details: "Instance started manually"
                )
            case .stop:
                try await ec2Service.stopInstance(instance.id)
                InstanceActivity.addActivity(
                    instanceId: instance.id,
                    type: .userAction,
                    details: "Instance stopped manually"
                )
            case .reboot:
                try await ec2Service.rebootInstance(instance.id)
                InstanceActivity.addActivity(
                    instanceId: instance.id,
                    type: .userAction,
                    details: "Instance rebooted"
                )
            case .terminate:
                try await ec2Service.terminateInstance(instance.id)
                InstanceActivity.addActivity(
                    instanceId: instance.id,
                    type: .userAction,
                    details: "Instance terminated"
                )
            }
            
            // Refresh activities
            loadActivities()
            
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
        isLoading = false
    }
} 