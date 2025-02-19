import SwiftUI
import UserNotifications
import ActivityKit
import BackgroundTasks
import FirebaseCore
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import AWSCore
import AWSEC2

@main
struct InstancifyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var ec2Service = EC2Service.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var appearanceViewModel = AppearanceSettingsViewModel.shared
    @StateObject private var appLockService = AppLockService.shared
    @State private var showingActionConfirmation = false
    @State private var pendingAction: (action: String, instanceId: String)?
    @State private var pendingWidgetURL: URL?
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var instanceMonitoringService = InstanceMonitoringService.shared
    
    init() {
        // Configure Firebase first
        FirebaseApp.configure()
        
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        Firestore.firestore().settings = settings
        
        print("✅ Firebase configured in InstancifyApp init")
        
        // Try anonymous sign in at app launch
        Task {
            do {
                try await Auth.auth().signInAnonymously()
                print("✅ Anonymous auth successful")
            } catch {
                print("❌ Anonymous auth failed: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(notificationManager)
                .environmentObject(ec2Service)
                .environmentObject(appearanceViewModel)
                .environmentObject(appLockService)
                .tint(appearanceViewModel.currentAccentColor)
                .task {
                    // Configure AWS services if authenticated
                    if authManager.isAuthenticated {
                        do {
                            try await authManager.configureAWSServices()
                            print("✅ AWS services configured successfully")
                            
                            // Request Live Activity authorization after AWS is configured
                            let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
                            print("Live Activities enabled: \(enabled)")
                            
                            // Initial instance fetch
                            try await ec2Service.fetchInstances()
                            
                            // Restore runtime alerts state
                            await NotificationSettingsViewModel.shared.handleAppLaunch()
                        } catch {
                            print("❌ Failed to configure AWS services: \(error)")
                        }
                    }
                }
                .onChange(of: authManager.isAuthenticated) { wasAuthenticated, isAuthenticated in
                    if isAuthenticated {
                        Task {
                            do {
                                try await authManager.configureAWSServices()
                                print("✅ AWS services configured after authentication")
                                try await ec2Service.fetchInstances()
                                
                                // Restore runtime alerts state after authentication
                                await NotificationSettingsViewModel.shared.handleAppLaunch()
                            } catch {
                                print("❌ Failed to configure AWS services: \(error)")
                            }
                        }
                    }
                }
                .onAppear {
                    UIView.appearance().tintColor = UIColor(appearanceViewModel.currentAccentColor)
                    if appLockService.isPasswordSet() {
                        appLockService.lock()
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        Task {
                            do {
                                if authManager.isAuthenticated {
                                    try await ec2Service.fetchInstances()
                                }
                                
                                if InstanceMonitoringService.shared.isMonitoring {
                                    try await InstanceMonitoringService.shared.startMonitoring()
                                }
                            } catch {
                                print("❌ Failed to refresh instances or start monitoring: \(error)")
                            }
                        }
                    } else if newPhase == .background {
                        // Handle app going to background
                        NotificationSettingsViewModel.shared.handleAppTermination()
                    }
                }
                .onChange(of: appearanceViewModel.currentAccentColor) { oldColor, newColor in
                    UIView.appearance().tintColor = UIColor(newColor)
                }
                .onChange(of: appLockService.isLocked) { wasLocked, isLocked in
                    if !isLocked, let url = pendingWidgetURL {
                        // App was unlocked and we have a pending widget URL
                        print("🔓 App unlocked. Processing pending widget action")
                        pendingWidgetURL = nil
                        handleWidgetURL(url)
                    }
                }
                .onOpenURL { url in
                    print("🔗 URL opened: \(url)")
                    handleWidgetURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    if appLockService.isPasswordSet() {
                        appLockService.lock()
                    }
                }
                .alert("Confirm Action", isPresented: $showingActionConfirmation) {
                    Button("Cancel", role: .cancel) {
                        print("❌ Action cancelled")
                        pendingAction = nil
                    }
                    
                    if let action = pendingAction {
                        Button(action.action.capitalized, role: action.action == "stop" ? .destructive : .none) {
                            print("✅ Action confirmed: \(action.action) for instance \(action.instanceId)")
                            performAction(action)
                        }
                    }
                } message: {
                    if let action = pendingAction,
                       let instance = ec2Service.instances.first(where: { $0.id == action.instanceId }) {
                        Text("Are you sure you want to \(action.action) instance '\(instance.name ?? instance.id)'?")
                    } else {
                        Text("Are you sure you want to perform this action?")
                    }
                }
        }
    }
    
    private func handleWidgetURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.scheme == "instancify" else {
            print("⚠️ Invalid URL format")
            return
        }
        
        // Parse path components (remove empty components from multiple slashes)
        let pathComponents = components.path.split(separator: "/", omittingEmptySubsequences: true)
        print("🔍 Path components: \(pathComponents)")
        
        // Handle general app URLs
        if pathComponents.count == 1 && pathComponents[0] == "instances" {
            print("📱 Opening instances view")
            return
        }
        
        // Handle widget action URLs (/start/instanceId or /stop/instanceId)
        guard pathComponents.count == 2,
              ["start", "stop"].contains(pathComponents[0]) else {
            print("⚠️ Invalid path format: expected /action/instanceId")
            return
        }
        
        let action = String(pathComponents[0])
        let instanceId = String(pathComponents[1])
        
        print("📱 Widget action received: \(action) for instance \(instanceId)")
        
        // If app is locked, store the URL and wait for unlock
        if appLockService.isPasswordSet() && appLockService.isLocked {
            print("🔒 App is locked. Storing URL for after unlock")
            pendingWidgetURL = url
            return
        }
        
        // Otherwise, proceed with the action
        processPendingWidgetAction(action: action, instanceId: instanceId)
    }
    
    private func processPendingWidgetAction(action: String, instanceId: String) {
        // Fetch instances first to ensure we have the latest data
        Task {
            do {
                let instances = try await ec2Service.fetchInstances()
                print("📍 Found \(instances.count) instances")
                
                await MainActor.run {
                    pendingAction = (action, instanceId)
                    showingActionConfirmation = true
                }
            } catch {
                print("❌ Error fetching instances: \(error.localizedDescription)")
            }
        }
    }
    
    private func performAction(_ action: (action: String, instanceId: String)) {
        print("🚀 Performing action: \(action.action) for instance \(action.instanceId)")
        
        Task {
            do {
                // Verify instance exists
                guard let instance = ec2Service.instances.first(where: { $0.id == action.instanceId }) else {
                    print("❌ Instance not found")
                    await MainActor.run {
                        showingActionConfirmation = false
                        pendingAction = nil
                    }
                    return
                }
                
                print("📍 Found instance: \(instance.name ?? instance.id)")
                
                switch action.action {
                case "start":
                    print("▶️ Starting instance \(instance.name ?? instance.id)...")
                    let _ = try await ec2Service.startInstance(action.instanceId)
                case "stop":
                    print("⏹️ Stopping instance \(instance.name ?? instance.id)...")
                    let _ = try await ec2Service.stopInstance(action.instanceId)
                default:
                    print("⚠️ Unknown action: \(action.action)")
                    return
                }
                
                print("🔄 Refreshing instances...")
                let _ = try await ec2Service.fetchInstances()
                
                await MainActor.run {
                    print("✅ Action completed successfully")
                    showingActionConfirmation = false
                    pendingAction = nil
                }
            } catch {
                print("❌ Error performing action: \(error.localizedDescription)")
                await MainActor.run {
                    showingActionConfirmation = false
                    pendingAction = nil
                }
            }
        }
    }
}