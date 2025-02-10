import Foundation
import UIKit

struct InstanceRuntime: Codable {
    let instanceId: String
    let startTime: Date
    let endTime: Date
    let cost: Double // Estimated cost for this runtime period
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    var formattedCost: String {
        String(format: "$%.2f", cost)
    }
}

class InstanceHistoryManager: ObservableObject {
    static let shared = InstanceHistoryManager()
    @Published var runtimes: [InstanceRuntime] = []
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "instanceRuntimes"
    
    private init() {
        print("InstanceHistoryManager: Initializing...")
        loadRuntimes()
        
        // Observe scene disconnect instead of app termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveRuntimes),
            name: UIScene.didDisconnectNotification,
            object: nil
        )
        
        // Also observe background state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveRuntimes),
            name: UIScene.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func addRuntime(instanceId: String, startTime: Date, endTime: Date, instanceType: String) {
        let hourlyRate = getHourlyRate(for: instanceType)
        let hours = endTime.timeIntervalSince(startTime) / 3600
        let cost = hourlyRate * hours
        
        let runtime = InstanceRuntime(
            instanceId: instanceId,
            startTime: startTime,
            endTime: endTime,
            cost: cost
        )
        
        DispatchQueue.main.async {
            self.runtimes.append(runtime)
            self.saveRuntimes()
        }
        
        print("InstanceHistoryManager: Added runtime record for \(instanceId), duration: \(Int(hours))h, cost: $\(String(format: "%.2f", cost))")
    }
    
    private func getHourlyRate(for instanceType: String) -> Double {
        // Add more instance types and actual costs
        switch instanceType {
        case "t2.micro": return 0.0116
        case "t2.small": return 0.023
        case "t2.medium": return 0.0464
        default: return 0.0116 // Default to t2.micro rate
        }
    }
    
    @objc private func saveRuntimes() {
        print("InstanceHistoryManager: Saving runtimes...")
        if let encoded = try? JSONEncoder().encode(runtimes) {
            userDefaults.set(encoded, forKey: storageKey)
            userDefaults.synchronize()
            print("InstanceHistoryManager: Saved \(runtimes.count) runtime records")
        }
    }
    
    private func loadRuntimes() {
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([InstanceRuntime].self, from: data) {
            DispatchQueue.main.async {
                self.runtimes = decoded
                print("InstanceHistoryManager: Loaded \(decoded.count) runtime records")
            }
        }
    }
} 