import SwiftUI

struct ColorButton: View {
    let colorName: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
        }
    }
}

struct ColorPickerView: View {
    @ObservedObject var viewModel: AppearanceSettingsViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(viewModel.availableColors.keys.sorted()), id: \.self) { colorName in
                    ColorButton(
                        colorName: colorName,
                        color: viewModel.availableColors[colorName] ?? .blue,
                        isSelected: colorName == viewModel.selectedAccentColor,
                        action: { viewModel.setAccentColor(colorName) }
                    )
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
        }
    }
}

struct AppearanceSettingsView: View {
    @StateObject private var viewModel = AppearanceSettingsViewModel.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Accent Color")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack {
                        ColorPickerView(viewModel: viewModel)
                    }
                    .glassEffect()
                    .cornerRadius(12)
                    
                    Text("Choose your preferred accent color for the app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
} 