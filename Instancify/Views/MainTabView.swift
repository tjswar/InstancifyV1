import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var hapticManager = HapticManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Dashboard")
            }
            .tag(0)
            
            NavigationStack {
                NotificationHistoryView(currentRegion: dashboardViewModel.currentRegion)
            }
            .tabItem {
                Image(systemName: "clock.arrow.circlepath")
                Text("History")
            }
            .badge(notificationManager.pendingNotifications.count)
            .tag(1)
            
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(2)
        }
        .tint(appearanceViewModel.currentAccentColor)
        .onChange(of: selectedTab) { _ in
            hapticManager.selection()
        }
    }
} 