import SwiftUI

struct InstancesList: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.instances) { instance in
                NavigationLink(destination: InstanceDetailView(instance: instance)) {
                    InstanceRowView(
                        instance: instance,
                        isAutoStopEnabled: Binding(
                            get: { instance.autoStopEnabled },
                            set: { newValue in
                                Task {
                                    await viewModel.toggleAutoStop(for: instance.id, enabled: newValue)
                                }
                            }
                        ),
                        onAutoStopToggle: { isEnabled in
                            Task {
                                await viewModel.toggleAutoStop(for: instance.id, enabled: isEnabled)
                            }
                        }
                    )
                    .environmentObject(viewModel)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}