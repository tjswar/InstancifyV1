import SwiftUI

struct InstanceListView: View {
    let instances: [EC2Instance]
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(instances) { instance in
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
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(minHeight: 44)
                }
            }
            .padding()
        }
    }
} 