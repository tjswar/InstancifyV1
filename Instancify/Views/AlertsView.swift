import SwiftUI

struct AlertsView: View {
    var body: some View {
        NavigationView {
            List {
                Text("No alerts")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Alerts")
        }
    }
}

#Preview {
    AlertsView()
} 