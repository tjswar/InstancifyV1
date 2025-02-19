import Foundation

struct CostData {
    let today: String
    let month: String
    let projected: String
}

class CostService {
    static let shared = CostService()
    
    private init() {}
    
    func fetchCosts() async throws -> CostData {
        // Return placeholder data for now
        // TODO: Implement actual cost tracking in future versions
        return CostData(
            today: "$0.00",
            month: "$0.00",
            projected: "$0.00"
        )
    }
} 