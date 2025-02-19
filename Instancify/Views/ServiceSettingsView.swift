import SwiftUI
import AWSCore
import AWSEC2

struct ServiceSettingsView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var enabledServices: Set<AWSService> = []
    
    init() {
        _enabledServices = State(initialValue: Set(AWSService.allCases.filter { $0.isEnabled }))
    }
    
    var body: some View {
        Form {
            Section(header: Text("AWS Region")) {
                Picker("Region", selection: $authManager.selectedRegion) {
                    ForEach(AWSRegion.allCases, id: \.self) { region in
                        Text(region.displayName)
                            .tag(region)
                    }
                }
                .onChange(of: authManager.selectedRegion) { newValue in
                    Task {
                        try? await authManager.updateRegion(newValue)
                    }
                }
            }
            
            Section(header: Text("Enabled Services")) {
                ForEach(AWSService.allCases, id: \.self) { service in
                    PrimitiveToggle(
                        isOn: Binding(
                            get: { service.isEnabled },
                            set: { newValue in
                                if newValue {
                                    enabledServices.insert(service)
                                } else {
                                    enabledServices.remove(service)
                                }
                                UserDefaults.standard.set(newValue, forKey: "service.\(service.rawValue).enabled")
                            }
                        ),
                        label: service.displayName
                    )
                }
            }
        }
        .navigationTitle("Service Settings")
        .onAppear {
            enabledServices = Set(AWSService.allCases.filter { $0.isEnabled })
        }
    }
}

#Preview {
    ServiceSettingsView()
} 