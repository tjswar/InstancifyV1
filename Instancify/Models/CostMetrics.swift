import Foundation

struct CostMetrics: Equatable {
    let dailyCost: Double
    let monthlyCost: Double
    let projectedCost: Double
    
    var dailyFormatted: String {
        String(format: "$%.2f", dailyCost)
    }
    
    var monthlyFormatted: String {
        String(format: "$%.2f", monthlyCost)
    }
    
    var projectedFormatted: String {
        String(format: "$%.2f", projectedCost)
    }
} 