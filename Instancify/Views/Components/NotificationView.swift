import SwiftUI

struct NotificationView: View {
    let notification: NotificationType
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notification.title)
                .font(.headline)
            
            Text(notification.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .swipeActions {
            Button(role: .destructive) {
                onDismiss?()
            } label: {
                Label("Dismiss", systemImage: "xmark.circle.fill")
            }
        }
    }
}

struct IconBubble: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(color.gradient)
            )
    }
}

struct NotificationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Warning notification
            NotificationView(
                notification: .autoStopWarning(
                    instanceId: "i-1234567890",
                    name: "Test Instance",
                    secondsRemaining: 45
                )
            )
            
            // Auto-stop enabled
            NotificationView(
                notification: .autoStopEnabled(
                    instanceId: "i-1234567890",
                    name: "Test Instance",
                    stopTime: Date().addingTimeInterval(3600)
                )
            )
            
            // Auto-stopped
            NotificationView(
                notification: .instanceAutoStopped(
                    instanceId: "i-1234567890",
                    name: "Test Instance"
                )
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
} 