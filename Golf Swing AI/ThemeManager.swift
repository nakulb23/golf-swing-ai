import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gear"
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var appearanceMode: AppearanceMode = .system
    @Published var effectiveColorScheme: ColorScheme? = nil
    
    private let appearanceModeKey = "appearanceMode"
    
    init() {
        // Load saved preference or default to system
        if let savedMode = UserDefaults.standard.string(forKey: appearanceModeKey),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
        updateEffectiveColorScheme()
    }
    
    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: appearanceModeKey)
        updateEffectiveColorScheme()
    }
    
    private func updateEffectiveColorScheme() {
        switch appearanceMode {
        case .light:
            effectiveColorScheme = .light
        case .dark:
            effectiveColorScheme = .dark
        case .system:
            effectiveColorScheme = nil // Let system decide
        }
    }
    
    // Legacy support for simple toggle
    var isDarkMode: Bool {
        return appearanceMode == .dark
    }
    
    func toggleDarkMode() {
        switch appearanceMode {
        case .light, .system:
            setAppearanceMode(.dark)
        case .dark:
            setAppearanceMode(.light)
        }
    }
}

// MARK: - Dynamic Color Extensions
extension Color {
    // Dynamic colors that adapt to light/dark mode
    static func dynamicColor(light: Color, dark: Color) -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    
    // MARK: - Dark Mode Color Variants
    static let darkForestGreen = Color(red: 0.16, green: 0.50, blue: 0.16)     // Lighter for dark mode
    static let darkCream = Color(red: 0.12, green: 0.12, blue: 0.12)           // Dark background
    static let darkIndigo = Color(red: 0.40, green: 0.44, blue: 0.65)          // Lighter indigo
    static let darkSage = Color(red: 0.70, green: 0.80, blue: 0.71)            // Lighter sage
    static let darkCardBackground = Color(red: 0.18, green: 0.18, blue: 0.18)  // Dark card
    
    // MARK: - Updated Semantic Colors (Dynamic)
    static let primaryBackgroundDynamic = dynamicColor(light: .cream, dark: .darkCream)
    static let secondaryBackgroundDynamic = dynamicColor(light: .sage.opacity(0.1), dark: .darkSage.opacity(0.1))
    static let cardBackgroundDynamic = dynamicColor(light: .white, dark: .darkCardBackground)
    static let primaryTextDynamic = dynamicColor(light: .black, dark: .white)
    static let secondaryTextDynamic = dynamicColor(light: .black.opacity(0.7), dark: .white.opacity(0.7))
    static let accentDynamic = dynamicColor(light: .forestGreen, dark: .darkForestGreen)
    static let accentSecondaryDynamic = dynamicColor(light: .indigo, dark: .darkIndigo)
}

// MARK: - Updated Gradients for Dark Mode
extension LinearGradient {
    static let primaryGradientDynamic = LinearGradient(
        colors: [Color.accentDynamic, Color.dynamicColor(light: .sage, dark: .darkSage)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradientDynamic = LinearGradient(
        colors: [Color.cardBackgroundDynamic, Color.cardBackgroundDynamic.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
}