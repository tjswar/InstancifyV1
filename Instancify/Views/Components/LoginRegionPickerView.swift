import SwiftUI

struct LoginRegionPickerView: View {
    @Binding var selectedRegion: AWSRegion
    
    var body: some View {
        Picker("Select Region", selection: $selectedRegion) {
            ForEach(AWSRegion.allCases, id: \.self) { region in
                Text(region.displayName).tag(region)
            }
        }
    }
} 