import SwiftUI
import AWSEC2

#if DEBUG
class MockAuthManager: ObservableObject {
    @Published var selectedRegion: AWSRegion = .usEast1
    @Published var isAuthenticated = true
    @Published var accessKeyId: String = ""
    @Published var secretAccessKey: String = ""
    
    init() {
        self.selectedRegion = .usEast1
        self.isAuthenticated = true
    }
}

class MockNotificationManager: ObservableObject {
    @Published var pendingNotifications: [(notification: NotificationType, timestamp: Date)] = []
    @Published var isAuthorized = true
    @Published var mutedInstanceIds: Set<String> = []
    
    func requestAuthorization() async throws -> Bool {
        return true
    }
}

class MockEC2Service: ObservableObject {
    func fetchInstances() async throws -> [EC2Instance] {
        return [
            EC2Instance(
                id: "i-preview1",
                instanceType: "t2.micro",
                state: .running,
                name: "Preview Instance 1",
                launchTime: Date(),
                publicIP: "1.2.3.4",
                privateIP: "10.0.0.1",
                autoStopEnabled: false,
                countdown: nil,
                stateTransitionTime: nil,
                hourlyRate: 0.0116,
                runtime: 0,
                currentCost: 0.0,
                projectedDailyCost: 0.28,
                region: "us-east-1"
            ),
            EC2Instance(
                id: "i-preview2",
                instanceType: "t2.small",
                state: .stopped,
                name: "Preview Instance 2",
                launchTime: Date().addingTimeInterval(-3600),
                publicIP: "1.2.3.5",
                privateIP: "10.0.0.2",
                autoStopEnabled: false,
                countdown: nil,
                stateTransitionTime: nil,
                hourlyRate: 0.023,
                runtime: 60,
                currentCost: 0.023,
                projectedDailyCost: 0.0,
                region: "us-east-1"
            )
        ]
    }
}

class MockDashboardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var currentRegion = "us-east-1"
    @Published var instances: [EC2Instance]
    @Published var costMetrics: CostMetrics
    
    init() {
        self.instances = [
            EC2Instance(
                id: "i-preview1",
                instanceType: "t2.micro",
                state: .running,
                name: "Preview Instance 1",
                launchTime: Date(),
                publicIP: "1.2.3.4",
                privateIP: "10.0.0.1",
                autoStopEnabled: false,
                countdown: nil,
                stateTransitionTime: nil,
                hourlyRate: 0.0116,
                runtime: 0,
                currentCost: 0.0,
                projectedDailyCost: 0.28,
                region: "us-east-1"
            ),
            EC2Instance(
                id: "i-preview2",
                instanceType: "t2.small",
                state: .stopped,
                name: "Preview Instance 2",
                launchTime: Date().addingTimeInterval(-3600),
                publicIP: "1.2.3.5",
                privateIP: "10.0.0.2",
                autoStopEnabled: false,
                countdown: nil,
                stateTransitionTime: nil,
                hourlyRate: 0.023,
                runtime: 60,
                currentCost: 0.023,
                projectedDailyCost: 0.0,
                region: "us-east-1"
            )
        ]
        self.costMetrics = CostMetrics(
            dailyCost: 0.25,
            monthlyCost: 7.50,
            projectedCost: 30.00
        )
    }
    
    func switchRegion(_ region: AWSRegion) async {
        currentRegion = region.rawValue
    }
}

class MockAppLockService: ObservableObject {
    @Published var isLocked = false
}
#endif

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    @EnvironmentObject private var authManager: AuthenticationManager
    
    init(viewModel: DashboardViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? DashboardViewModel.shared)
    }
    
    var body: some View {
        DashboardContent(viewModel: viewModel)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    RegionPickerView(viewModel: viewModel)
                }
            }
    }
}

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DashboardView()
                .environmentObject(MockAuthManager())
                .environmentObject(MockNotificationManager())
                .environmentObject(AppearanceSettingsViewModel())
                .environmentObject(MockAppLockService())
                .environmentObject(NotificationSettingsViewModel.shared)
        }
        .previewDisplayName("Dashboard")
    }
}
#endif
