import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var appLockService = AppLockService.shared
    @StateObject private var appearanceViewModel = AppearanceSettingsViewModel.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var notificationSettings = NotificationSettingsViewModel.shared
    @StateObject private var dashboardViewModel = DashboardViewModel.shared
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                // Preview-safe content
                previewContent
            } else {
                // Full app content
                mainContent
            }
        }
        .environmentObject(appearanceViewModel)
        .environmentObject(notificationManager)
        .environmentObject(notificationSettings)
        .environmentObject(dashboardViewModel)
        .environmentObject(authManager)
        .environmentObject(appLockService)
        .tint(appearanceViewModel.currentAccentColor)
        .alertScheduledPopup()
    }
    
    private var mainContent: some View {
        NavigationView {
            ZStack {
                if !authManager.isAuthenticated {
                    AuthenticationView()
                } else {
                    if appLockService.isLocked {
                        LockScreenView()
                    } else {
                        MainTabView(selectedTab: $selectedTab)
                            .tint(appearanceViewModel.currentAccentColor)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if appLockService.isPasswordSet() {
                appLockService.lock()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            appLockService.checkLockState()
        }
        .animation(.easeInOut, value: appLockService.isLocked)
    }
    
    private var previewContent: some View {
        NavigationView {
            MainTabView(selectedTab: .constant(0))
                .tint(Color.blue)  // Use static color instead of dynamic
        }
    }
}

#Preview {
    ContentView()
}
