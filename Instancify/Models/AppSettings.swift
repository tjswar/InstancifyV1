import Foundation

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var ec2PricingLink: String {
        didSet {
            UserDefaults.standard.set(ec2PricingLink, forKey: "ec2PricingLink")
        }
    }
    
    private init() {
        // Load saved pricing link or use default
        self.ec2PricingLink = UserDefaults.standard.string(forKey: "ec2PricingLink") ?? "https://aws.amazon.com/ec2/pricing/"
    }
} 