import SwiftUI

// MARK: - Golf Swing AI Color Theme
extension Color {
    
    // MARK: - Primary Colors
    static let forestGreen = Color(red: 0.13, green: 0.42, blue: 0.13)      // #22692B
    static let cream = Color(red: 0.99, green: 0.98, blue: 0.94)            // #FDFDF0
    static let indigo = Color(red: 0.29, green: 0.33, blue: 0.55)           // #4A548C
    static let sage = Color(red: 0.62, green: 0.73, blue: 0.63)             // #9EBA87
    static let deepForest = Color(red: 0.09, green: 0.35, blue: 0.09)       // #165916 - Darker forest green
    
    // MARK: - UI Semantic Colors (Legacy - use dynamic versions)
    static let primaryBackground = Color.cream
    static let secondaryBackground = Color.sage.opacity(0.1)
    static let cardBackground = Color.white
    static let primaryText = Color.black
    static let secondaryText = Color.black.opacity(0.7)
    static let accent = Color.forestGreen
    static let accentSecondary = Color.indigo
    static let success = Color.forestGreen
    static let warning = Color.orange
    static let error = Color(red: 0.8, green: 0.2, blue: 0.2)
    
    
    // MARK: - Golf-Specific Theme Colors
    static let swingAnalysis = Color.indigo
    static let ballTracking = Color.deepForest
    static let caddieChat = Color.forestGreen
    static let physicsInsights = Color.sage
}

// MARK: - Custom Gradients
extension LinearGradient {
    static let primaryGradient = LinearGradient(
        colors: [Color.forestGreen, Color.sage],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient = LinearGradient(
        colors: [Color.cream, Color.white],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color.indigo, Color.forestGreen],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Custom Shadows
extension View {
    func golfCardShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    func golfElevatedShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.15),
            radius: 12,
            x: 0,
            y: 6
        )
    }
    
    func golfSubtleShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient.primaryGradient)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .golfElevatedShadow()
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.accent)
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accent, lineWidth: 2)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .golfCardShadow()
    }
}

// MARK: - Custom Text Styles (Malbon-inspired)
extension Text {
    func golfTitle() -> some View {
        self
            .font(.system(size: 28, weight: .medium, design: .default))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundColor(.primaryText)
    }
    
    func golfHeadline() -> some View {
        self
            .font(.system(size: 20, weight: .medium, design: .default))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundColor(.primaryText)
    }
    
    func golfSubheadline() -> some View {
        self
            .font(.system(size: 16, weight: .regular, design: .default))
            .tracking(0.4)
            .foregroundColor(.secondaryText)
    }
    
    func golfBody() -> some View {
        self
            .font(.system(size: 15, weight: .regular, design: .default))
            .tracking(0.2)
            .foregroundColor(.primaryText)
    }
    
    func golfCaption() -> some View {
        self
            .font(.system(size: 11, weight: .medium, design: .default))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundColor(.secondaryText)
    }
    
    // Additional Malbon-style variants
    func golfBrandTitle() -> some View {
        self
            .font(.system(size: 32, weight: .medium, design: .default))
            .textCase(.uppercase)
            .tracking(2.0)
            .foregroundColor(.primaryText)
    }
    
    func golfButtonText() -> some View {
        self
            .font(.system(size: 14, weight: .medium, design: .default))
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

// MARK: - Custom Card Style
struct GolfCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient.cardGradient)
            )
            .golfCardShadow()
    }
}