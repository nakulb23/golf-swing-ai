import Foundation

// MARK: - App Build Configuration
//
// This is the SINGLE SOURCE OF TRUTH for all build-time and launch-time flags.
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │                    GO-LIVE CHECKLIST (after Apple approval)             │
// ├─────────────────────────────────────────────────────────────────────────┤
// │ 1. Set autoEnableReviewMode = false  (line below)                       │
// │ 2. Product → Clean Build Folder (⌘⇧K)                                  │
// │ 3. Product → Archive                                                    │
// │ 4. Distribute App → App Store Connect → Submit for Distribution         │
// │                                                                         │
// │ That's it. Everything else is guarded by #if DEBUG at compile time.     │
// └─────────────────────────────────────────────────────────────────────────┘

enum AppBuildConfig {

    // ── Review Build Flag ────────────────────────────────────────────────
    // Set to `true` when submitting to Apple for review.
    // Set to `false` before the final go-live production release.
    //
    // When true: PremiumManager auto-enables review mode at launch so
    // Apple reviewers can access all premium features without purchasing.
    //
    // ⚠️  FLIP THIS TO false BEFORE GO-LIVE ⚠️
    static let autoEnableReviewMode: Bool = true

    // ── Hidden Review Mode Gesture ───────────────────────────────────────
    // In Release builds, Apple reviewers can tap the version label this many
    // times to toggle review mode on/off. Set to 0 to disable the gesture
    // entirely in the go-live build (or just leave it — users won't find it).
    static let reviewModeTapCount: Int = 5

    // ── Computed helpers ─────────────────────────────────────────────────

    /// True only in DEBUG builds (Xcode dev runs, simulator, etc.)
    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// True when running in the iOS Simulator (any build configuration)
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Summary string for console / Settings footer
    static var buildDescription: String {
        #if DEBUG
        let config = "DEBUG"
        #else
        let config = autoEnableReviewMode ? "REVIEW" : "PRODUCTION"
        #endif
        return "\(config) • v\(appVersion) (\(buildNumber))"
    }

    // ── App version helpers ──────────────────────────────────────────────

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }
}
