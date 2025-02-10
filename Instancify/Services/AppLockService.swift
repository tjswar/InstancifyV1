import SwiftUI

@MainActor
class AppLockService: ObservableObject {
    static let shared = AppLockService()
    
    @AppStorage("appLockPassword") private var storedPassword: String = ""
    @AppStorage("useCustomPassword") private var useCustomPassword: Bool = false
    @AppStorage("lockTimer") private var lockTimer: Double = 0 // 0 = immediate
    @Published private(set) var isLocked: Bool = false
    
    private var backgroundDate: Date?
    
    static let lockTimerOptions: [(interval: Double, label: String)] = [
        (0, "Immediately"),
        (15, "15 seconds"),
        (30, "30 seconds"),
        (60, "1 minute")
    ]
    
    private init() {
        // Initialize lock state
        isLocked = useCustomPassword && !storedPassword.isEmpty
    }
    
    func lock() {
        guard useCustomPassword && !storedPassword.isEmpty else { return }
        
        if lockTimer == 0 {
            // Lock immediately
            isLocked = true
        } else {
            // Set background date for timer
            backgroundDate = Date()
        }
    }
    
    func checkLockState() {
        guard useCustomPassword && !storedPassword.isEmpty else {
            isLocked = false
            return
        }
        
        if let backgroundDate = backgroundDate {
            let timeInBackground = Date().timeIntervalSince(backgroundDate)
            if timeInBackground >= lockTimer {
                isLocked = true
            }
        }
        
        // Clear background date
        backgroundDate = nil
    }
    
    func unlock(with pin: String) -> Bool {
        guard useCustomPassword && !storedPassword.isEmpty else {
            isLocked = false
            return true
        }
        
        let success = pin == storedPassword
        if success {
            isLocked = false
            backgroundDate = nil
        }
        return success
    }
    
    func setPassword(_ pin: String) {
        storedPassword = pin
        useCustomPassword = true
        isLocked = true
    }
    
    func removePassword() {
        storedPassword = ""
        useCustomPassword = false
        isLocked = false
        backgroundDate = nil
    }
    
    func isPasswordSet() -> Bool {
        return useCustomPassword && !storedPassword.isEmpty
    }
    
    func setLockTimer(_ interval: Double) {
        lockTimer = interval
    }
    
    func getLockTimer() -> Double {
        return lockTimer
    }
} 