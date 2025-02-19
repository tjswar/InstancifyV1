import SwiftUI
import FirebaseFirestore

// Import the models
import Foundation

// Import the shared model

struct NotificationHistoryView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @StateObject private var hapticManager = HapticManager.shared
    @State private var notifications: [NotificationHistoryItem] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    let currentRegion: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if notifications.isEmpty {
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
            if !notifications.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            clearNotifications()
                            hapticManager.impact(.medium)
                        }
                    }) {
                        Text("Clear All")
                            .foregroundColor(.pink)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await fetchNotifications()
            }
        }
    }
    
    private func processNotification(_ data: [String: Any]) -> NotificationItem? {
        print("  • Processing notification: \(data["id"] as? String ?? "unknown")")
        
        // Get fields with defaults
        let type = data["type"] as? String ?? "unknown"
        let title = data["title"] as? String ?? "Notification"
        let body = data["body"] as? String ?? "No content"
        let instanceId = data["instanceId"] as? String
        let instanceName = data["instanceName"] as? String ?? instanceId ?? "Unknown Instance"
        let region = data["region"] as? String ?? currentRegion
        let runtime = data["runtime"] as? Int
        let threshold = data["threshold"] as? Int
        
        // Handle timestamps
        let timestamp: Date?
        if let firestoreTimestamp = data["timestamp"] as? Timestamp {
            timestamp = firestoreTimestamp.dateValue()
        } else {
            timestamp = nil
        }
        
        let createdAt: Date?
        if let firestoreCreatedAt = data["createdAt"] as? Timestamp {
            createdAt = firestoreCreatedAt.dateValue()
        } else {
            createdAt = nil
        }
        
        // Format time strings
        let time = data["time"] as? String
        let formattedTime = data["formattedTime"] as? String ?? DateFormatter.localizedString(
            from: timestamp ?? Date(),
            dateStyle: .none,
            timeStyle: .short
        )
        
        print("    ✅ Notification processed:")
        print("      • Type: \(type)")
        print("      • Title: \(title)")
        print("      • Instance: \(instanceName)")
        print("      • Region: \(region)")
        print("      • Time: \(formattedTime)")
        
        return NotificationItem(
            id: data["id"] as? String ?? UUID().uuidString,
            type: type,
            title: title,
            body: body,
            instanceId: instanceId,
            instanceName: instanceName,
            region: region,
            runtime: runtime,
            threshold: threshold,
            timestamp: timestamp,
            time: time,
            formattedTime: formattedTime,
            createdAt: createdAt
        )
    }
    
    private func fetchNotifications() async {
        print("\n📝 Fetching notifications for region: \(currentRegion)")
        
        do {
            let db = Firestore.firestore()
            let query = db.collection("notificationHistory")
                .whereField("region", isEqualTo: currentRegion)
                .limit(to: 100)
            
            let snapshot = try await query.getDocuments()
            print("📊 Found \(snapshot.documents.count) notifications")
            
            let notifications = snapshot.documents.compactMap { doc -> NotificationItem? in
                var data = doc.data()
                data["id"] = doc.documentID
                return processNotification(data)
            }
            
            await MainActor.run {
                self.notifications = notifications.map { NotificationHistoryItem(from: $0) }
            }
            
            print("✅ Successfully loaded \(notifications.count) notifications")
        } catch {
            print("❌ Failed to fetch notifications: \(error)")
            await MainActor.run {
                self.error = error
                self.showError = true
            }
        }
    }
    
    private func clearNotifications() {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        notifications.forEach { notification in
            let docRef = db.collection("notificationHistory").document(notification.id)
            batch.deleteDocument(docRef)
        }
        
        batch.commit { error in
            if let error = error {
                print("Error clearing notifications: \(error)")
            } else {
                notifications.removeAll()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .symbolEffect(.bounce)
            
            Text("No Notifications")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Runtime alerts will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var notificationsListView: some View {
        VStack(spacing: 16) {
            ForEach(notifications) { notification in
                NotificationCard(notification: notification)
            }
        }
        .padding(.horizontal)
    }
}

struct NotificationCard: View {
    let notification: NotificationHistoryItem
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var hapticManager = HapticManager.shared
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }
    
    var iconAndColor: (String, Color) {
        switch notification.type {
        case "runtime_alert":
            return ("hourglass.circle.fill", .pink)
        case "instance_state_change":
            return ("arrow.triangle.2.circlepath.circle.fill", .blue)
        default:
            return ("bell.circle.fill", .gray)
        }
    }
    
    var runtimeInfo: String? {
        guard let runtime = notification.runtime else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        var info = ""
        if hours > 0 {
            info += "\(hours)h"
        }
        if minutes > 0 {
            if !info.isEmpty {
                info += " "
            }
            info += "\(minutes)m"
        }
        if let threshold = notification.threshold {
            let thresholdHours = threshold / 60
            let thresholdMinutes = threshold % 60
            info += " (Threshold: "
            if thresholdHours > 0 {
                info += "\(thresholdHours)h"
            }
            if thresholdMinutes > 0 {
                if thresholdHours > 0 {
                    info += " "
                }
                info += "\(thresholdMinutes)m"
            }
            info += ")"
        }
        return info
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconAndColor.0)
                .font(.title2)
                .foregroundColor(iconAndColor.1)
                .symbolEffect(.bounce)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(notification.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let runtime = notification.runtime {
                    Text("Runtime: \(runtime) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let threshold = notification.threshold {
                    Text("Threshold: \(threshold) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let timestamp = notification.timestamp {
                    Text("Time: \(timestamp, formatter: itemFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    NavigationView {
        NotificationHistoryView(currentRegion: "us-east-1")
            .environmentObject(NotificationManager.shared)
    }
} 
