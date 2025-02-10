import Foundation

class AWSServiceConfig: ObservableObject, Codable {
    @Published var enabledServices: Set<AWSServiceType>
    
    enum CodingKeys: String, CodingKey {
        case enabledServices
    }
    
    init(enabledServices: Set<AWSServiceType> = []) {
        self.enabledServices = enabledServices
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabledServices = try container.decode(Set<AWSServiceType>.self, forKey: .enabledServices)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabledServices, forKey: .enabledServices)
    }
    
    func isServiceEnabled(_ service: AWSServiceType) -> Bool {
        enabledServices.contains(service)
    }
    
    func toggleService(_ service: AWSServiceType) {
        if enabledServices.contains(service) {
            enabledServices.remove(service)
        } else {
            enabledServices.insert(service)
        }
    }
    
    static var `default`: AWSServiceConfig {
        AWSServiceConfig(enabledServices: [.ec2])
    }
} 
