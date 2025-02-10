import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ResourceListView()
                .tabItem {
                    Label("Resources", systemImage: "server.rack")
                }
                .tag(0)
            
            AlertsView()
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
} 