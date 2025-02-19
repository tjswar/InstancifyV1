import SwiftUI

struct RegionPicker: View {
    let selection: AWSRegion
    let onChange: (AWSRegion) -> Void
    
    var body: some View {
        Menu {
            ForEach(AWSRegion.allCases, id: \.self) { region in
                Button {
                    onChange(region)
                } label: {
                    HStack {
                        Text(region.displayName)
                        if region == selection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "globe")
                Text(selection.displayName)
                Image(systemName: "chevron.down")
            }
        }
    }
} 