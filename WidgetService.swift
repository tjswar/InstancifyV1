import Foundation
import WidgetKit
import Intents

class WidgetService {
    static let shared = WidgetService()
    
    private let sharedDefaults = UserDefaults(suiteName: "group.tech.md.Instancify")
    
    func updateWidgetData(for instance: EC2Instance) {
        let entry = InstanceEntry(
            date: Date(),
            configuration: InstancifyWidgetIntent(),
            instanceId: instance.id,
            instanceName: instance.name ?? "Unnamed Instance",
            state: instance.state.rawValue,
            currentCost: instance.currentCost,
            projectedDailyCost: instance.projectedDailyCost,
            region: instance.region
        )
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(entry) {
            sharedDefaults?.set(encoded, forKey: "widget-data")
            sharedDefaults?.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func clearWidgetData() {
        sharedDefaults?.removeObject(forKey: "widget-data")
        sharedDefaults?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
} 