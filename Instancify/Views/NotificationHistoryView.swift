import SwiftUI

struct NotificationHistoryView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @StateObject private var hapticManager = HapticManager.shared
    let currentRegion: String
    
    var groupedNotifications: [(String, [NotificationType])] {
        let calendar = Calendar.current
        let now = Date()
        
        return Dictionary(grouping: notificationManager.pendingNotifications) { notification in
            let timestamp = notification.timestamp
            if calendar.isDateInToday(timestamp) {
                let hoursDiff = calendar.dateComponents([.hour], from: timestamp, to: now).hour ?? 0
                if hoursDiff < 1 {
                    return "Just Now"
                } else {
                    return "Today"
                }
            } else if calendar.isDateInYesterday(timestamp) {
                return "Yesterday"
            } else {
                return "Older"
            }
        }
        .mapValues { notifications in
            notifications.map { $0.notification }
        }
        .sorted { group1, group2 in
            let order = ["Just Now", "Today", "Yesterday", "Older"]
            return order.firstIndex(of: group1.key)! < order.firstIndex(of: group2.key)!
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if notificationManager.pendingNotifications.isEmpty {
                    emptyStateView
                } else {
                    notificationsListView
                }
            }
            .padding(.top)
        }
        .navigationTitle("Notification History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !notificationManager.pendingNotifications.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            notificationManager.clearNotifications()
                            hapticManager.impact(.medium)
                        }
                    }) {
                        Text("Clear All")
                            .foregroundColor(.pink)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Notifications")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Recent notifications will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var notificationsListView: some View {
        VStack(spacing: 16) {
            ForEach(groupedNotifications, id: \.0) { group in
                NotificationGroup(title: group.0, notifications: group.1)
            }
        }
        .padding(.horizontal)
    }
}

struct NotificationGroup: View {
    let title: String
    let notifications: [NotificationType]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 8) {
                ForEach(notifications) { notification in
                    NotificationCard(notification: notification)
                }
            }
        }
    }
}

struct NotificationCard: View {
    let notification: NotificationType
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var hapticManager = HapticManager.shared
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }
    
    var iconAndColor: (String, Color) {
        switch notification {
        case .runtimeAlert:
            return ("timer.circle.fill", .pink)
        case .instanceStarted:
            return ("play.circle.fill", .green)
        case .instanceStopped, .instanceAutoStopped:
            return ("stop.circle.fill", .red)
        case .autoStopWarning, .autoStopEnabled:
            return ("clock.circle.fill", .orange)
        case .instanceError:
            return ("exclamationmark.triangle.fill", .red)
        case .instanceStateChanged:
            return ("arrow.triangle.2.circlepath", .blue)
        case .instanceRunningLong:
            return ("hourglass.circle.fill", .orange)
        }
    }
    
    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.timestamp, relativeTo: Date())
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconAndColor.0)
                .font(.title2)
                .foregroundColor(iconAndColor.1)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(notification.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
        .onTapGesture {
            hapticManager.impact(.light)
        }
    }
}

extension NotificationType {
    var timestamp: Date {
        // This should be stored in the actual NotificationType, but for now returning current date
        return Date()
    }
}

#Preview {
    NavigationView {
        NotificationHistoryView(currentRegion: "us-east-1")
            .environmentObject(NotificationManager.shared)
    }
} 