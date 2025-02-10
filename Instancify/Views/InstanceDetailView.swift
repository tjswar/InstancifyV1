import SwiftUI

struct InstanceDetailView: View {
    @StateObject private var viewModel: InstanceDetailViewModel
    @StateObject private var ec2Service = EC2Service.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    init(instance: EC2Instance) {
        _viewModel = StateObject(wrappedValue: InstanceDetailViewModel(instance: instance))
    }
    
    var body: some View {
        InstanceDetailContent(viewModel: viewModel)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewModel.instance.name ?? "Instance Details")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refresh()
            }
            .onReceive(ec2Service.$instances) { _ in
                viewModel.updateFromService()
            }
            .alert("Error", isPresented: $viewModel.showError, presenting: viewModel.error) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error)
            }
            .overlay {
                if viewModel.isLoading {
                    LoadingView()
                }
            }
            .tint(appearanceViewModel.currentAccentColor)
    }
}

private struct InstanceDetailContent: View {
    @ObservedObject var viewModel: InstanceDetailViewModel
    @State private var showConfirmation = false
    @State private var selectedAction: InstanceAction?
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DetailsCard(instance: viewModel.instance)
                
                InstanceCostCard(instance: viewModel.instance)
                
                ActionCardContent(
                    viewModel: viewModel,
                    showConfirmation: $showConfirmation,
                    selectedAction: $selectedAction
                )
                
                ActivitySection(activities: viewModel.activities)
            }
            .padding()
        }
    }
}

private struct ActivitySection: View {
    let activities: [InstanceActivity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            if activities.isEmpty {
                Text("No recent activity")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 16) {
                    ForEach(activities) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

private struct ActivityRow: View {
    let activity: InstanceActivity
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Activity type with icon
                HStack(spacing: 6) {
                    Image(systemName: iconForType(activity.type))
                        .foregroundStyle(colorForType(activity.type))
                    Text(activity.type.rawValue)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(colorForType(activity.type))
                }
                
                Spacer()
                
                // Relative time
                Text(activity.relativeTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Activity details
            Text(activity.details)
                .font(.callout)
                .foregroundStyle(.primary)
            
            Divider()
        }
        .padding(.vertical, 4)
    }
    
    private func iconForType(_ type: InstanceActivity.ActivityType) -> String {
        switch type {
        case .stateChange: return "arrow.triangle.2.circlepath"
        case .autoStop: return "timer"
        case .userAction: return "person.circle"
        }
    }
    
    private func colorForType(_ type: InstanceActivity.ActivityType) -> Color {
        switch type {
        case .stateChange: return .blue
        case .autoStop: return .orange
        case .userAction: return appearanceViewModel.currentAccentColor
        }
    }
}

private struct StatusCard: View {
    let instance: EC2Instance
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatusIndicator(status: instance.state.displayString)
                Text(instance.state.displayString)
                    .font(.headline)
            }
            
            if instance.state == .running {
                Text(instance.formattedRuntime)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

private struct LoadingView: View {
    var body: some View {
        Color.black.opacity(0.2)
            .ignoresSafeArea()
            .overlay {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }
    }
}

private struct ActionsCard: View {
    @ObservedObject var viewModel: InstanceDetailViewModel
    @State private var showConfirmation = false
    @State private var selectedAction: InstanceAction?
    
    var body: some View {
        ActionCardContent(
            viewModel: viewModel,
            showConfirmation: $showConfirmation,
            selectedAction: $selectedAction
        )
    }
}

private struct ActionCardContent: View {
    let viewModel: InstanceDetailViewModel
    @Binding var showConfirmation: Bool
    @Binding var selectedAction: InstanceAction?
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Actions")
                .font(.headline)
            
            ActionButtonsGrid(
                instance: viewModel.instance,
                onActionSelected: { action in
                    selectedAction = action
                    showConfirmation = true
                }
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .confirmationDialog(
            selectedAction?.title ?? "",
            isPresented: $showConfirmation,
            titleVisibility: .visible,
            presenting: selectedAction
        ) { action in
            Button(action.confirmationText, role: action == .terminate ? .destructive : .none) {
                Task {
                    await viewModel.performAction(action)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.confirmationMessage)
        }
    }
}

private struct ActionButtonsGrid: View {
    let instance: EC2Instance
    let onActionSelected: (InstanceAction) -> Void
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    private let actions: [InstanceAction] = [
        .start,
        .stop,
        .reboot,
        .terminate
    ]
    
    var body: some View {
        LazyVGrid(columns: [.init(), .init()], spacing: 12) {
            ForEach(actions, id: \.id) { action in
                ActionButton(
                    title: action.title,
                    icon: action.icon,
                    color: appearanceViewModel.currentAccentColor,
                    isEnabled: action.isEnabled(instance.state)
                ) {
                    onActionSelected(action)
                }
            }
        }
    }
}

private struct DetailsCard: View {
    let instance: EC2Instance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                DetailRow(
                    title: "Instance ID",
                    value: instance.id,
                    icon: "server.rack"
                )
                
                DetailRow(
                    title: "Type",
                    value: instance.instanceType,
                    icon: "cpu"
                )
                
                if let publicIP = instance.publicIP {
                    DetailRow(
                        title: "Public IP",
                        value: publicIP,
                        icon: "network"
                    )
                }
                
                if let privateIP = instance.privateIP {
                    DetailRow(
                        title: "Private IP",
                        value: privateIP,
                        icon: "lock.shield"
                    )
                }
                
                if let launchTime = instance.launchTime {
                    DetailRow(
                        title: "Launch Time",
                        value: launchTime.formatted(date: .abbreviated, time: .shortened),
                        icon: "calendar"
                    )
                }
                
                RuntimeDetailRow(instance: instance)
            }
        }
        .padding()
        .glassEffect()
        .cornerRadius(12)
    }
}
