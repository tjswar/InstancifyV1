import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var appLockService = AppLockService.shared
    @StateObject private var appearanceViewModel = AppearanceSettingsViewModel.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var notificationSettings = NotificationSettingsViewModel.shared
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                if !authManager.isAuthenticated {
                    AuthenticationView()
                        .environmentObject(authManager)
                        .environmentObject(appearanceViewModel)
                } else {
                    if appLockService.isLocked {
                        LockScreenView()
                            .environmentObject(appLockService)
                            .environmentObject(appearanceViewModel)
                    } else {
                        MainTabView(selectedTab: $selectedTab)
                            .tint(appearanceViewModel.currentAccentColor)
                            .environmentObject(authManager)
                            .environmentObject(appearanceViewModel)
                            .environmentObject(notificationManager)
                            .environmentObject(notificationSettings)
                            .environmentObject(dashboardViewModel)
                    }
                }
            }
        }
        .environmentObject(appearanceViewModel)
        .environmentObject(notificationManager)
        .environmentObject(notificationSettings)
        .environmentObject(dashboardViewModel)
        .tint(appearanceViewModel.currentAccentColor)
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
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(AppearanceSettingsViewModel.shared)
        .environmentObject(AppLockService.shared)
        .environmentObject(NotificationSettingsViewModel.shared)
}
