import SwiftUI
import AWSEC2

#if DEBUG
class MockAuthManager: ObservableObject {
    @Published var isSignedIn: Bool = true
    @Published var currentUsername: String = "preview_user"
    @Published var identityId: String = "preview_identity"
    @Published var selectedRegion: AWSRegion = .usEast1
    @Published var credentials: AWSCredentials = .init(
        accessKeyId: "PREVIEW_ACCESS_KEY",
        secretAccessKey: "PREVIEW_SECRET_KEY"
    )
    
    func signOut() {
        // Preview implementation
    }
}
#endif

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    @EnvironmentObject private var authManager: AuthenticationManager
    
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
                .environmentObject(NotificationManager.shared)
                .environmentObject(AppearanceSettingsViewModel())
                .environmentObject(AppLockService.shared)
                .environmentObject(EC2Service.shared)
        }
    }
}
#endif
