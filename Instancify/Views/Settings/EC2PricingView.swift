import SwiftUI

struct EC2PricingView: View {
    @StateObject private var pricingViewModel = EC2PricingViewModel.shared
    @StateObject private var appSettings = AppSettings.shared
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    var body: some View {
        List {
            Section {
                Text("EC2 Pricing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            }
            
            Section {
                Text("Region: \(authManager.selectedRegion.displayName)")
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("General Purpose")) {
                PriceRow(instanceType: "t2.micro", description: "1 vCPU, 1 GiB RAM")
                PriceRow(instanceType: "t2.small", description: "1 vCPU, 2 GiB RAM")
                PriceRow(instanceType: "t2.medium", description: "2 vCPU, 4 GiB RAM")
                PriceRow(instanceType: "t2.large", description: "2 vCPU, 8 GiB RAM")
            }
            
            Section(header: Text("Burstable Performance")) {
                PriceRow(instanceType: "t3.micro", description: "2 vCPU, 1 GiB RAM")
                PriceRow(instanceType: "t3.small", description: "2 vCPU, 2 GiB RAM")
                PriceRow(instanceType: "t3.medium", description: "2 vCPU, 4 GiB RAM")
                PriceRow(instanceType: "t3.large", description: "2 vCPU, 8 GiB RAM")
            }
            
            Section(header: Text("Compute Optimized")) {
                PriceRow(instanceType: "c5.large", description: "2 vCPU, 4 GiB RAM")
                PriceRow(instanceType: "c5.xlarge", description: "4 vCPU, 8 GiB RAM")
            }
            
            Section(header: Text("Memory Optimized")) {
                PriceRow(instanceType: "r5.large", description: "2 vCPU, 16 GiB RAM")
                PriceRow(instanceType: "r5.xlarge", description: "4 vCPU, 32 GiB RAM")
            }
            
            Section {
                Text("* Prices shown are per hour and may vary based on region and other factors.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Link(destination: URL(string: appSettings.ec2PricingLink)!) {
                    HStack {
                        Text("View Official AWS EC2 Pricing")
                        Image(systemName: "link")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("EC2 Pricing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            pricingViewModel.updateRegion(authManager.selectedRegion)
        }
    }
}

struct PriceRow: View {
    @StateObject private var pricingViewModel = EC2PricingViewModel.shared
    let instanceType: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(instanceType)
                    .font(.headline)
                Spacer()
                Text(String(format: "$%.4f/hour", pricingViewModel.priceForInstance(instanceType, in: pricingViewModel.selectedRegion)))
                    .foregroundColor(.secondary)
            }
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
} 