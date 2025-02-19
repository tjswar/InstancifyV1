import SwiftUI

class AppearanceSettingsViewModel: ObservableObject {
    static let shared = AppearanceSettingsViewModel()
    
    @AppStorage("accentColor") private var storedAccentColor: String = "blue"
    @Published private(set) var selectedAccentColor: String = "blue"
    
    let availableColors = [
        "blue": Color.blue,
        "purple": Color.purple,
        "pink": Color.pink,
        "red": Color.red,
        "orange": Color.orange,
        "yellow": Color.yellow,
        "green": Color.green,
        "mint": Color.mint,
        "teal": Color.teal,
        "indigo": Color.indigo
    ]
    
    init() {
        selectedAccentColor = storedAccentColor
    }
    
    func setAccentColor(_ color: String) {
        selectedAccentColor = color
        storedAccentColor = color
    }
    
    var currentAccentColor: Color {
        availableColors[selectedAccentColor] ?? .blue
    }
} 