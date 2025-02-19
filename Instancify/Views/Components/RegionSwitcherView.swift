import SwiftUI

struct RegionSwitcherView: View {
    let currentRegion: AWSRegion
    let onRegionSelect: (AWSRegion) async throws -> Void
    @State private var showingRegionPicker = false
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        Button {
            showingRegionPicker = true
        } label: {
            Image(systemName: "globe")
                .font(.title3)
                .foregroundColor(.accentColor)
        }
        .disabled(isLoading)
        .confirmationDialog("Select Region", isPresented: $showingRegionPicker) {
            ForEach(AWSRegion.allCases) { region in
                Button(region.displayName) {
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        do {
                            try await onRegionSelect(region)
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            if let error = error {
                Text(error)
            }
        }
    }
} 