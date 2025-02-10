import SwiftUI

struct NotificationsListView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        List {
            ForEach(notificationManager.pendingNotifications.indices, id: \.self) { index in
                NotificationView(
                    notification: notificationManager.pendingNotifications[index].notification
                ) {
                    withAnimation(.spring) {
                        notificationManager.removeNotification(at: index)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Notifications")
    }
}

#Preview {
    NavigationStack {
        NotificationsListView()
            .environmentObject(NotificationManager.shared)
    }
} 