import SwiftUI

@MainActor
class ServiceDetailViewModel: ObservableObject {
    @Published var resources: [AWSResource] = []
    @Published var isLoading = false
    @Published var error: String?
    
    let serviceType: AWSResourceType
    
    init(serviceType: AWSResourceType) {
        self.serviceType = serviceType
    }
    
    func fetchResources() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedResources = try await AWSManager.shared.fetchResources()
            // Filter resources by type
            self.resources = fetchedResources.filter { $0.type == serviceType }
            print("Fetched \(self.resources.count) resources for \(serviceType)")
        } catch {
            self.error = error.localizedDescription
            print("Error fetching resources: \(error)")
        }
    }
} 