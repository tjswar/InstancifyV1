import UIKit
import SwiftUI
import BackgroundTasks
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ContentView())
        self.window = window
        window.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        print("📱 Scene did disconnect")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("\n📱 Scene becoming active")
        Task {
            do {
                // Reset badge count
                let center = UNUserNotificationCenter.current()
                try? await center.setBadgeCount(0)
                
                let monitoringService = InstanceMonitoringService.shared
                
                if !monitoringService.isMonitoring {
                    try await monitoringService.startMonitoring()
                }
                
                try await monitoringService.checkAllRegions()
            } catch {
                print("❌ Error in sceneDidBecomeActive: \(error)")
            }
        }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        print("📱 Scene will resign active")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("\n📱 Scene entered background")
        
        // Create a background task to ensure we have time to complete our work
        let taskID = UIApplication.shared.beginBackgroundTask {
            print("⚠️ Background task expiring...")
        }
        
        Task {
            do {
                let monitoringService = InstanceMonitoringService.shared
                
                if !monitoringService.isMonitoring {
                    try await monitoringService.startMonitoring()
                }
                
                try await monitoringService.checkAllRegions()
                
                // Schedule background tasks
                await AppDelegate.shared.scheduleBackgroundTasks()
                print("✅ Background tasks scheduled")
            } catch {
                print("❌ Error in sceneDidEnterBackground: \(error)")
            }
        }
        
        // Always end the background task
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("\n📱 Scene will enter foreground")
        Task {
            do {
                let monitoringService = InstanceMonitoringService.shared
                
                if !monitoringService.isMonitoring {
                    try await monitoringService.startMonitoring()
                }
                
                try await monitoringService.checkAllRegions()
            } catch {
                print("❌ Error in sceneWillEnterForeground: \(error)")
            }
        }
    }
} 