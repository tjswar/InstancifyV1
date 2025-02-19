import Foundation
import WidgetKit

public struct InstanceEntry: TimelineEntry, Codable {
    public let date: Date
    public let instanceId: String
    public let instanceName: String
    public let state: String
    public let currentCost: Double
    public let projectedDailyCost: Double
    
    public init(date: Date, instanceId: String, instanceName: String, state: String, currentCost: Double, projectedDailyCost: Double) {
        self.date = date
        self.instanceId = instanceId
        self.instanceName = instanceName
        self.state = state
        self.currentCost = currentCost
        self.projectedDailyCost = projectedDailyCost
    }
} 