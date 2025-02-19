import SwiftUI

struct ResourceListView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        List {
            ForEach(appState.connections) { connection in
                Section {
                    Text("Resources will appear here")
                        .foregroundColor(.secondary)
                } header: {
                    Text(String(connection.name))
                }
            }
        }
    }
}

#Preview {
    ResourceListView()
        .environmentObject(AppState.shared)
} 