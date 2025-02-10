import Foundation
import AWSEC2

@MainActor
class EC2PricingViewModel: ObservableObject {
    static let shared = EC2PricingViewModel()
    
    @Published var instanceTypes: [String: Double] = [
        "t2.micro": 0.0116,
        "t2.small": 0.023,
        "t2.medium": 0.0464,
        "t2.large": 0.0928,
        "t3.micro": 0.0104,
        "t3.small": 0.0208,
        "t3.medium": 0.0416,
        "t3.large": 0.0832,
        "m5.large": 0.096,
        "m5.xlarge": 0.192,
        "c5.large": 0.085,
        "c5.xlarge": 0.17,
        "r5.large": 0.126,
        "r5.xlarge": 0.252
    ]
    
    @Published var selectedRegion: AWSRegion = .usEast1
    
    // Regional price multipliers (relative to us-east-1)
    private let regionMultipliers: [AWSRegion: Double] = [
        .usEast1: 1.0,      // N. Virginia
        .usEast2: 1.0,      // Ohio
        .usWest1: 1.1,      // N. California
        .usWest2: 1.05,     // Oregon
        .euWest1: 1.2,      // Ireland
        .euCentral1: 1.25,  // Frankfurt
        .apSoutheast1: 1.3, // Singapore
        .apSoutheast2: 1.3  // Sydney
    ]
    
    func priceForInstance(_ type: String, in region: AWSRegion) -> Double {
        let basePrice = instanceTypes[type] ?? 0.0
        let multiplier = regionMultipliers[region] ?? 1.0
        return basePrice * multiplier
    }
    
    func updateRegion(_ region: AWSRegion) {
        selectedRegion = region
    }
} 