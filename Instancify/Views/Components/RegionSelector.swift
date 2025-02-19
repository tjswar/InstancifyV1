import SwiftUI

struct RegionSelector: View {
    @Binding var selectedRegion: String
    let onRegionSelect: (String) -> Void
    
    let availableRegions = [
        "us-east-1": "US East (N. Virginia)",
        "us-east-2": "US East (Ohio)",
        "us-west-1": "US West (N. California)",
        "us-west-2": "US West (Oregon)",
        "eu-west-1": "EU (Ireland)",
        "eu-central-1": "EU (Frankfurt)",
        "ap-southeast-1": "Asia Pacific (Singapore)",
        "ap-southeast-2": "Asia Pacific (Sydney)"
    ]
    
    var body: some View {
        Menu {
            ForEach(Array(availableRegions.keys.sorted()), id: \.self) { region in
                Button(action: {
                    selectedRegion = region
                    onRegionSelect(region)
                }) {
                    HStack {
                        Text(availableRegions[region] ?? region)
                        if selectedRegion == region {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "globe")
                Text(availableRegions[selectedRegion] ?? selectedRegion)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
            }
        }
    }
} 