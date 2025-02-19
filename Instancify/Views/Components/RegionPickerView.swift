import SwiftUI

struct RegionPickerView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showRegionPicker = false
    @State private var isAnimating = false
    
    var body: some View {
        Button {
            showRegionPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .imageScale(.medium)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                Text(authManager.selectedRegion.displayName)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .fontWeight(.medium)
            }
            .foregroundColor(.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(8)
        }
        .disabled(viewModel.isLoading)
        .onChange(of: viewModel.isLoading) { loading in
            if loading {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            } else {
                isAnimating = false
            }
        }
        .sheet(isPresented: $showRegionPicker) {
            NavigationView {
                List {
                    ForEach(AWSRegion.allCases, id: \.self) { region in
                        Button {
                            Task {
                                // First close the sheet
                                showRegionPicker = false
                                
                                // Then update the region and refresh
                                if region != authManager.selectedRegion {
                                    await viewModel.switchRegion(region)
                                    authManager.selectedRegion = region
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.accentColor)
                                    .imageScale(.medium)
                                Text(region.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if region == authManager.selectedRegion {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
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