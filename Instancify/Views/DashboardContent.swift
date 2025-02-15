import SwiftUI
import AWSEC2

struct DashboardContent: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showSettings = false
    @State private var showRuntimeAlerts = false
    @State private var showStartAllConfirmation = false
    @State private var showStopAllConfirmation = false
    
    var body: some View {
        ZStack {
            mainContent
                .sheet(isPresented: $showRuntimeAlerts) {
                    NavigationView {
                        RuntimeAlertsView(region: viewModel.currentRegion)
                            .environmentObject(NotificationSettingsViewModel.shared)
                    }
                }
                .alert("Start All Instances", isPresented: $showStartAllConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Start All", role: .destructive) {
                        Task {
                            await viewModel.startAllInstances()
                        }
                    }
                } message: {
                    Text("Are you sure you want to start all stopped instances?")
                }
                .alert("Stop All Instances", isPresented: $showStopAllConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Stop All", role: .destructive) {
                        Task {
                            await viewModel.stopAllInstances()
                        }
                    }
                } message: {
                    Text("Are you sure you want to stop all running instances?")
                }
            
            if viewModel.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 12) {
                    Image(systemName: viewModel.isRegionSwitching ? "globe.americas.fill" : "arrow.clockwise")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(
                            .linear(duration: 1)
                            .repeatForever(autoreverses: false),
                            value: viewModel.isLoading
                        )
                    Text(viewModel.isRegionSwitching ? "Switching Region..." : "Refreshing...")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 20, y: 10)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.isLoading)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                await viewModel.refresh()
            }
        }
    }
    
    @ViewBuilder
    var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Stats Cards
                    HStack(spacing: 16) {
                        InstanceStatCard(
                            title: "Running",
                            count: viewModel.runningInstancesCount,
                            icon: "play.circle.fill",
                            color: .green
                        )
                        .glassEffect()
                        
                        InstanceStatCard(
                            title: "Stopped",
                            count: viewModel.stoppedInstancesCount,
                            icon: "stop.circle.fill",
                            color: .red
                        )
                        .glassEffect()
                    }
                    .padding(.horizontal)
                    
                    // Cost Overview Card
                    if let metrics = viewModel.costMetrics {
                        CostOverviewSection(viewModel: viewModel)
                            .glassEffect()
                            .padding(.horizontal)
                    }
                    
                    // Quick Actions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Start All
                        QuickActionButton(
                            title: "Start All",
                            icon: "play.circle.fill",
                            color: .green,
                            isEnabled: viewModel.hasStoppedInstances
                        ) {
                            showStartAllConfirmation = true
                        }
                        
                        // Stop All
                        QuickActionButton(
                            title: "Stop All",
                            icon: "stop.circle.fill",
                            color: .red,
                            isEnabled: viewModel.hasRunningInstances
                        ) {
                            showStopAllConfirmation = true
                        }
                        
                        // Refresh Status
                        QuickActionButton(
                            title: "Refresh Status",
                            icon: "arrow.clockwise",
                            color: .blue,
                            isEnabled: !viewModel.isLoading
                        ) {
                            Task {
                                await viewModel.refresh()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Instances List
                    if !viewModel.instances.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            // Region Runtime Alerts Section
                            RegionRuntimeAlertsView(viewModel: viewModel)
                                .environmentObject(NotificationSettingsViewModel.shared)
                                .padding(.horizontal)
                            
                            HStack(spacing: 8) {
                                Text("Instances")
                                    .font(.headline)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(viewModel.currentRegion)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            InstancesList(viewModel: viewModel)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await viewModel.refresh()
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }
}

struct InstanceDetailsSection: View {
    let instance: EC2Instance
    
    var body: some View {
        Section("Instance Details") {
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
            
            DetailRow(
                title: "State",
                value: instance.state.rawValue.capitalized,
                icon: "power",
                iconColor: instance.state == .running ? .green : .secondary
            )
            
            RuntimeDetailRow(instance: instance)
            
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
        }
    }
}

#Preview {
    List {
        InstanceDetailsSection(instance: EC2Instance(
            id: "i-1234567890abcdef0",
            instanceType: "t2.micro",
            state: .running,
            name: "Test Instance",
            launchTime: Date(),
            publicIP: "1.2.3.4",
            privateIP: "10.0.0.1",
            autoStopEnabled: false,
            countdown: nil,
            stateTransitionTime: nil,
            hourlyRate: 0.0116,
            runtime: 3600,
            currentCost: 0.0116,
            projectedDailyCost: 0.2784,
            region: "us-east-1"
        ))
    }
} 