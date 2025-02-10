import SwiftUI

struct ServiceDetailView: View {
    @StateObject private var viewModel: ServiceDetailViewModel
    
    init(serviceType: AWSResourceType) {
        _viewModel = StateObject(wrappedValue: ServiceDetailViewModel(serviceType: serviceType))
    }
    
    var body: some View {
        List(viewModel.resources) { resource in
            InstanceRow(instance: resource.instance)
        }
        .task {
            await viewModel.fetchResources()
        }
        .navigationTitle(viewModel.serviceType.rawValue)
    }
} 