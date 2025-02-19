import SwiftUI

struct AlertScheduledPopupView: View {
    @Environment(\.dismiss) private var dismiss
    let instanceName: String
    let alertTimes: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                
                Text("Runtime Alert Created")
                    .font(.headline)
            }
            
            // Alert details
            VStack(spacing: 4) {
                Text("A runtime alert has been set for \(alertTimes).")
                    .multilineTextAlignment(.center)
                Text("You'll be notified when \(instanceName) exceeds this duration.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .font(.subheadline)
            
            // Dismiss button
            Button("OK") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: 300)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

#Preview {
    AlertScheduledPopupView(
        instanceName: "test-instance",
        alertTimes: "1h 30m, 2h"
    )
    .preferredColorScheme(.dark)
} 