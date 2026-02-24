# Golf Swing AI — Production Readiness Report

**Date:** February 24, 2026
**Scope:** iOS App — Full architecture audit prior to App Store go-live
**Verdict:** ⚠️ CONDITIONAL GO — 1 critical blocker, 4 high-priority issues, and several medium/low items to address

---

## Executive Summary

The app is well-structured for a v1.0 launch. The StoreKit 2 paywall, round-logging data model, and tab navigation are solid. However, **one line of code will ship the app in Apple-reviewer mode to real users** if not changed, and there are several areas where features are scaffolded but not actually implemented (authentication, settings toggles, reset password). These must be understood and intentionally accepted before going live.

---

## 🔴 CRITICAL BLOCKER

### 1. `autoEnableReviewMode` is set to `true`

**File:** `AppBuildConfig.swift`, line 28

```swift
static let autoEnableReviewMode: Bool = true  // ⚠️ MUST BE false BEFORE GO-LIVE
```

**Impact:** Every user who downloads your app from the App Store will automatically get all premium features for free. Revenue will be $0. The paywall will never appear.

**Fix:** Before archiving for the final go-live submission:
1. Set `autoEnableReviewMode = false`
2. `Product → Clean Build Folder (⌘⇧K)`
3. Archive and distribute

This is the single most important change before launch. Everything else is lower priority.

---

## 🟠 HIGH PRIORITY

### 2. Authentication is Entirely Simulated — No Real Backend

**File:** `AuthenticationManager.swift`

The email/password sign-in flow creates a user object locally without contacting any server. The code even has a comment acknowledging this:

```swift
// TODO: Replace with actual backend authentication
```

**What this means in practice:**
- Any email address + any 8-character password will "sign in" successfully
- Passwords are never stored or verified anywhere
- `resetPassword` is a fake 3-second delay — it sends no email and resets nothing
- All user data lives in `UserDefaults`, which is wiped on app reinstall
- If a user reinstalls the app, they lose all data and must "create an account" again

**Decision required:** Is this intentional for v1.0? If yes, consider:
- Removing the email/password login UI entirely and using Apple Sign-In only (more honest UX)
- Showing a "local account" warning in Settings so users understand their data isn't backed up
- If not intentional, a real auth backend (Firebase Auth, Supabase, etc.) is needed before launch

### 3. Settings Toggles Are Not Wired to Anything

**File:** `SettingsView.swift`

The Notifications, Haptic Feedback, and Auto-Save Videos toggles use `@State` variables that are not:
- Persisted across app restarts
- Connected to iOS notification permissions (`UNUserNotificationCenter`)
- Connected to `UIImpactFeedbackGenerator`
- Connected to any video-saving logic

**Impact:** Users will toggle these settings and nothing will change. The next time they open the app, the toggles will reset to default. This is a trust-damaging UX bug.

**Fix options:**
- Persist to `UserPreferences` and wire to actual system APIs before launch, **or**
- Remove these toggles from the UI until they are implemented

### 4. `subscriptionExpiryDate` is Not Implemented

**File:** `PremiumManager.swift`

```swift
var subscriptionExpiryDate: Date? {
    // TODO: Implement proper expiration date retrieval
    return nil
}
```

If any part of the UI shows "expires on…" or uses this value for logic, it will silently fail or show nothing. Verify no UI surfaces this value. If it does, remove the display or implement it via `Transaction.currentEntitlements`.

### 5. Google Sign-In Configured on a Background Thread

**File:** `Golf_Swing_AIApp.swift`

```swift
DispatchQueue.global(qos: .background).async {
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
}
```

If the app is opened via a Google OAuth redirect URL before this background block completes, `GIDSignIn` will not have its configuration and the redirect will silently fail.

**Fix:** Move Google Sign-In configuration to the main thread synchronously during app init:
```swift
GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
```

---

## 🟡 MEDIUM PRIORITY

### 6. Round Log Data Has No Backup or Size Limit

**File:** `RoundLogManager.swift`

All round log data is stored in `UserDefaults` under key `"golf_round_log_v1"`. There is no:
- Maximum size limit (heavy users logging every round for years could accumulate MBs in UserDefaults, which is not designed for large data)
- iCloud or CloudKit backup
- Export feature

**Recommendation:** Consider migrating to a file-based store (JSON file in the Documents directory) or adding a CloudKit path for v1.1. For launch, add a note in the UI or Privacy section that data is stored locally only.

### 7. Analytics Are Local-Only (Never Transmitted)

**File:** `SimpleAnalytics.swift`

The analytics system stores events in `UserDefaults` with a 500-event cap but never sends them anywhere. You have no visibility into how users are using the app post-launch.

**Recommendation:** Before launch, decide whether to:
- Wire up a lightweight analytics service (PostHog, Mixpanel, Amplitude — all have free tiers and strong privacy practices)
- Or remove `SimpleAnalytics` references entirely and accept launching without usage data

### 8. Launch Screen Has a 3-Second Fake Progress Bar

**File:** `MinimalLaunchScreen.swift`

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
    withAnimation { isActive = true }
}
```

The 3-second delay is hardcoded and not tied to any real initialization work. This adds unnecessary friction on every cold launch. Consider reducing to 1.0–1.5 seconds or replacing with a real completion callback from your async setup work.

### 9. Hardcoded Fallback Prices in PremiumManager

**File:** `PremiumManager.swift`

```swift
var monthlyPrice: String { product?.displayPrice ?? "$1.99" }
var annualPrice: String  { product?.displayPrice ?? "$21.99" }
```

If StoreKit fails to load products (first launch, poor connectivity, or sandbox issues), the UI will show "$1.99" and "$21.99" as hardcoded strings. These won't reflect international pricing or future price changes.

**Recommendation:** Show "—" or a loading indicator as the fallback rather than a hardcoded dollar amount. Add a retry path if products fail to load.

### 10. Google Sign-In Produces Unfriendly Usernames

**File:** `AuthenticationManager.swift`

```swift
let username = "google_user_\(Date().timeIntervalSince1970)"
```

Users who sign in with Google get a username like `google_user_1740235412.3`. This appears in Settings and any UI that surfaces the username. Use the user's Google display name (`GIDGoogleUser.profile?.name`) or email prefix instead.

---

## 🔵 LOW PRIORITY / POLISH

### 11. Dead Code: `SwingAnalysisView_OLD.swift`

A file named `SwingAnalysisView_OLD.swift` exists in the project. If it's compiled into the main target, it increases binary size and creates confusion during future maintenance. Remove it from the target or delete the file entirely.

### 12. Test File May Be in Main Target

**File:** `LocalAIValidationTest.swift`

If this file is compiled into the main app target (rather than a test target), it increases binary size and could expose debug-only code paths. Verify it belongs to the test target only.

### 13. Excessive `print` Statements in PremiumManager

`PremiumManager.swift` contains many diagnostic `print()` calls for StoreKit debugging. These ship to production and appear in device console logs, which is information leakage. Wrap them in `#if DEBUG` or use `os.Logger` with a subsystem that compiles out in release builds.

### 14. Privacy View Has Hardcoded App Version

**File:** `SimplePrivacyView.swift`

The data deletion email template hardcodes `"1.0.0"` as the app version. Use `AppBuildConfig.appVersion` instead so it stays accurate automatically across future updates.

### 15. Analytics `sessionId` Never Rotates

**File:** `SimpleAnalytics.swift`

The `sessionId` is a persistent UUID stored in `UserDefaults` that never changes. All analytics events from the same device are permanently tied to the same ID. Consider generating a new session ID per app launch to limit long-term user profiling, even if the data stays local.

---

## ✅ What's Working Well

- **StoreKit 2 integration** — `Product.products(for:)`, `Transaction.currentEntitlements`, `Transaction.updates` listener, and `AppStore.sync()` are all correctly implemented
- **`canAccessPhysicsEngine` gating** — correctly excludes `isDevelopmentMode` from Release builds via `#if DEBUG`; review mode gating is sound and won't leak to real users once the flag is flipped
- **`AppBuildConfig` architecture** — single source of truth for build flags is a great pattern; the go-live checklist in the file header is clear and actionable
- **Data models** — `GolfRound`, `HoleEntry`, `ShotEntry` are well-structured, `Codable`/`Identifiable`/`Sendable`, and the scoring calculations handle edge cases correctly (e.g., `scoreRelativeToPar` excludes unplayed holes)
- **`RoundLogManager`** — clean `@MainActor` singleton with proper CRUD; thread-safe design
- **Hidden 5-tap review mode gesture** — elegant escape hatch for Apple reviewers that doesn't require a code change; correctly guarded to Release builds only
- **`GolfClub.grouped`** — correct category grouping; the `DisclosureGroup` bug fix in `HoleEntryView` makes club selection fully functional
- **Apple Sign-In** — implemented via `ASAuthorizationController`; the right primary auth path for an iOS app

---

## Go-Live Checklist

```
□ [MUST DO]  AppBuildConfig.swift: set autoEnableReviewMode = false
□ [MUST DO]  Verify settings toggles either work or are removed from UI
□ [SHOULD]   Move Google Sign-In config to main thread (remove DispatchQueue.global)
□ [SHOULD]   Replace hardcoded fallback prices with "—" loading placeholder
□ [SHOULD]   Fix Google username to use GIDGoogleUser.profile?.name
□ [SHOULD]   Remove SwingAnalysisView_OLD.swift from target
□ [SHOULD]   Wrap PremiumManager print() calls in #if DEBUG
□ [SHOULD]   Fix SimplePrivacyView to use AppBuildConfig.appVersion
□ [DECIDE]   Auth is local-only — intentional for v1.0 or needs a real backend?
□ [DECIDE]   Analytics are local-only — add a service or remove entirely?
□ [ACCEPT]   Round log data is device-local with no backup — document this for users
```

---

*Files reviewed: AppBuildConfig.swift, Golf_Swing_AIApp.swift, PremiumManager.swift, RoundLogManager.swift, ContentView.swift, SimpleAnalytics.swift, AuthenticationManager.swift, UserPreferences.swift, MinimalLaunchScreen.swift, SimplePrivacyView.swift, RoundLogModels.swift, SettingsView.swift, HoleEntryView.swift, RoundLogModels.swift*
