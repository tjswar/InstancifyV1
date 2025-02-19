import SwiftUI

struct AuthenticationRegionPickerView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var showRegionPicker = false
    
    var body: some View {
        Button {
            showRegionPicker = true
        } label: {
            HStack {
                Text(viewModel.selectedRegion.displayName)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(.accentColor)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .sheet(isPresented: $showRegionPicker) {
            NavigationView {
                List {
                    ForEach(AWSRegion.allCases, id: \.self) { region in
                        Button {
                            viewModel.selectedRegion = region
                            showRegionPicker = false
                        } label: {
                            HStack {
                                Text(region.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if region == viewModel.selectedRegion {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Select Region")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showRegionPicker = false
                        }
                    }
                }
            }
        }
    }
} 