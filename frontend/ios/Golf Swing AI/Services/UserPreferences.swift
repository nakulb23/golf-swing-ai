import Foundation
import SwiftUI

// MARK: - Handedness Enum
enum Handedness: String, CaseIterable {
    case rightHanded = "right"
    case leftHanded = "left"

    var displayName: String {
        switch self {
        case .rightHanded:
            return "Right-Handed"
        case .leftHanded:
            return "Left-Handed"
        }
    }

    var icon: String {
        switch self {
        case .rightHanded:
            return "hand.point.right.fill"
        case .leftHanded:
            return "hand.point.left.fill"
        }
    }

    var description: String {
        switch self {
        case .rightHanded:
            return "Standard golf stance with left hand above right on grip"
        case .leftHanded:
            return "Mirrored golf stance with right hand above left on grip"
        }
    }
}

// MARK: - User Preferences Manager
@MainActor
class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @Published var handedness: Handedness {
        didSet {
            UserDefaults.standard.set(handedness.rawValue, forKey: "user_handedness")
            print("🏌️‍♂️ Updated handedness preference: \(handedness.displayName)")
        }
    }

    @Published var adaptAnalysisForHandedness: Bool {
        didSet {
            UserDefaults.standard.set(adaptAnalysisForHandedness, forKey: "adapt_analysis_handedness")
            print("🔄 Analysis adaptation for handedness: \(adaptAnalysisForHandedness ? "enabled" : "disabled")")
        }
    }

    @Published var showHandednessInResults: Bool {
        didSet {
            UserDefaults.standard.set(showHandednessInResults, forKey: "show_handedness_results")
        }
    }

    private init() {
        // Load saved preferences or set defaults
        let savedHandedness = UserDefaults.standard.string(forKey: "user_handedness") ?? Handedness.rightHanded.rawValue
        self.handedness = Handedness(rawValue: savedHandedness) ?? .rightHanded

        self.adaptAnalysisForHandedness = UserDefaults.standard.bool(forKey: "adapt_analysis_handedness")
        self.showHandednessInResults = UserDefaults.standard.bool(forKey: "show_handedness_results")

        print("🏌️‍♂️ Loaded user preferences - Handedness: \(handedness.displayName)")
    }

    // MARK: - Analysis Adaptation Methods

    /// Returns whether the user's stance should be mirrored for analysis
    var shouldMirrorAnalysis: Bool {
        return adaptAnalysisForHandedness && handedness == .leftHanded
    }

    /// Get the lead arm side based on handedness
    var leadArmSide: String {
        switch handedness {
        case .rightHanded:
            return "left"  // Left arm is lead for right-handed golfers
        case .leftHanded:
            return "right" // Right arm is lead for left-handed golfers
        }
    }

    /// Get the trailing arm side based on handedness
    var trailingArmSide: String {
        switch handedness {
        case .rightHanded:
            return "right" // Right arm is trailing for right-handed golfers
        case .leftHanded:
            return "left"  // Left arm is trailing for left-handed golfers
        }
    }

    /// Get expected rotation direction multiplier
    /// Right-handed: positive rotation in backswing
    /// Left-handed: negative rotation in backswing
    var rotationMultiplier: Double {
        switch handedness {
        case .rightHanded:
            return 1.0
        case .leftHanded:
            return -1.0
        }
    }

    /// Reset all preferences to defaults
    func resetToDefaults() {
        handedness = .rightHanded
        adaptAnalysisForHandedness = true
        showHandednessInResults = true

        print("🔄 Reset user preferences to defaults")
    }
}