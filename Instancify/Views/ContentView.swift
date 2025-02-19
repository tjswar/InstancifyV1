import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var appLockService = AppLockService.shared
    @StateObject private var appearanceViewModel = AppearanceSettingsViewModel.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var notificationSettings = NotificationSettingsViewModel.shared
    @StateObject private var dashboardViewModel = DashboardViewModel.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    
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
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }
    
    private var mainContent: some View {
        NavigationView {
            ZStack {
                if !authManager.isAuthenticated {
                    AuthenticationView()
                        .transition(.opacity)
                } else {
                    if appLockService.isLocked {
                        LockScreenView()
                            .transition(.opacity)
                    } else {
                        MainTabView(selectedTab: $selectedTab)
                            .tint(appearanceViewModel.currentAccentColor)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: appLockService.isLocked)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if appLockService.isPasswordSet() {
                appLockService.lock()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            appLockService.checkLockState()
        }
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
