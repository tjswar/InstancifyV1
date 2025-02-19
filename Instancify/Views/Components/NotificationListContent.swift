import SwiftUI

struct NotificationListContent: View {
    let notification: NotificationType
    
    var body: some View {
        NotificationView(notification: notification)
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

struct NotificationListContent_Previews: PreviewProvider {
    static var previews: some View {
        NotificationListContent(
            notification: .autoStopWarning(
                instanceId: "i-1234567890",
                name: "Test Instance",
                secondsRemaining: 300
            )
        )
        .previewLayout(.sizeThatFits)
    }
} 