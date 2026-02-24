import Foundation
import StoreKit
import Combine
import SwiftUI

// MARK: - Premium Manager

@MainActor
class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    
    @Published var hasPhysicsEnginePremium = false // Always starts as false - must be purchased
    @Published var isLoading = false
    @Published var purchaseError: String?
    @Published var availableProducts: [Product] = []
    @Published var currentSubscription: Product.SubscriptionInfo.Status?
    @Published var isSubscriptionActive = false
    @Published var isDevelopmentMode = false // Production mode - use real StoreKit
    @Published var isAppStoreReviewMode = false // For Apple reviewers in production builds
    @Published var showPaywall = false
    
    private var transactionUpdatesTask: Task<Void, Never>?
    
    // Subscription Product IDs (matching Configuration.storekit)
    // IMPORTANT: These must match EXACTLY with App Store Connect configuration
    private let monthlySubscriptionID = "nakulb.GolfSwingAI.premium_monthly"
    private let annualSubscriptionID = "nakulb.GolfSwingAI.premium_annual"
    
    private var productIDs: [String] {
        [monthlySubscriptionID, annualSubscriptionID]
    }
    
    init() {
        print("🚀 PremiumManager initializing...")
        print("📱 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("📦 Product IDs to load: \(productIDs)")
        
        // Verify we're in the right environment
        #if targetEnvironment(simulator)
        print("🔧 Running in Simulator - StoreKit Testing should be configured")
        #else
        print("📱 Running on Device - Will use App Store Sandbox/Production")
        #endif
        
        // Start listening for transaction updates immediately at launch
        // This ensures we don't miss any successful purchases
        startTransactionUpdateListener()

        // ── Auto-enable review mode for App Store submissions ─────────────
        // Controlled by AppBuildConfig.autoEnableReviewMode.
        // When true (and in a Release build), Apple reviewers get immediate
        // access to all premium features without purchasing.
        // Flip AppBuildConfig.autoEnableReviewMode = false before go-live.
        #if !DEBUG
        if AppBuildConfig.autoEnableReviewMode {
            enableAppStoreReviewMode()
            print("📱 Review mode auto-enabled at launch (AppBuildConfig.autoEnableReviewMode = true)")
        }
        #endif

        // Load products immediately and retry if needed
        Task {
            print("🔄 Initial product load attempt...")
            
            // First, verify StoreKit is available
            await verifyStoreKitAvailability()
            
            // Run health check first
            await quickStoreKitHealthCheck()
            
            // Add a longer initial delay to ensure StoreKit is fully ready
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await loadProducts()
            
            // If no products loaded, try again after a short delay
            if availableProducts.isEmpty {
                print("⚠️ No products on first attempt, retrying in 2 seconds...")
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await loadProducts()
            }
            
            // Third attempt with longer delay
            if availableProducts.isEmpty {
                print("⚠️ No products on second attempt, retrying in 3 seconds...")
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await loadProducts()
            }
            
            // Final check and provide detailed status
            if availableProducts.isEmpty {
                print("❌ No products loaded after multiple attempts")
                validateStoreKitSetup()
                await simpleStoreKitTest()

                // ── Development / Simulator fallback ───────────────────────
                // In a DEBUG build running on the simulator, StoreKit testing
                // requires the scheme's Run → Options → StoreKit Configuration
                // to be set.  If it isn't (common after a clean build or Xcode
                // restart), we silently enable dev mode so work can continue.
                #if DEBUG && targetEnvironment(simulator)
                print("🔧 DEBUG/Simulator: StoreKit unavailable — enabling dev mode automatically")
                print("🔧 To fix permanently: Edit Scheme → Run → Options → StoreKit Configuration → Configuration.storekit")
                await MainActor.run {
                    isDevelopmentMode = true
                    hasPhysicsEnginePremium = true
                    isSubscriptionActive = true
                    purchaseError = nil   // suppress the scary banner
                }
                #else
                print("❌ StoreKit unavailable on this device/build — check App Store Connect sandbox setup")
                #endif
            } else {
                print("✅ StoreKit successfully configured with \(availableProducts.count) products")
                for product in availableProducts {
                    print("✅ Product loaded: \(product.id) - \(product.displayName)")
                }
            }
        }

        Task {
            await checkPurchaseStatus()
        }
    }
    
    deinit {
        transactionUpdatesTask?.cancel()
    }
    
    // MARK: - Transaction Updates Listener
    
    private func startTransactionUpdateListener() {
        print("🔄 Starting Transaction.updates listener at launch")
        transactionUpdatesTask = Task(priority: .background) {
            for await result in StoreKit.Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        switch result {
        case .verified(let transaction):
            print("✅ Transaction update received: \(transaction.productID)")
            
            // Check if this transaction is for our products
            if productIDs.contains(transaction.productID) {
                await MainActor.run {
                    hasPhysicsEnginePremium = true
                }
                
                // Finish the transaction
                await transaction.finish()
                
                // Update subscription status
                await checkPurchaseStatus()

                print("✅ Premium access granted via transaction update")
            }
            
        case .unverified(let transaction, let error):
            print("⚠️ Unverified transaction update: \(transaction.productID), error: \(error)")
        }
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        print("🔄 Loading StoreKit products...")
        print("🔍 Product IDs to load: \(productIDs)")
        print("🔍 StoreKit Configuration should be: Configuration.storekit")
        
        // Force StoreKit to initialize
        print("🔄 Forcing StoreKit initialization...")
        
        do {
            let products = try await Product.products(for: productIDs)
            await MainActor.run {
                availableProducts = products
            }
            
            if availableProducts.isEmpty {
                print("⚠️ No products found!")
                print("⚠️ Product IDs requested: \(productIDs)")
                print("⚠️ StoreKit Testing Setup:")
                print("⚠️ 1. In Xcode: Product -> Scheme -> Edit Scheme...")
                print("⚠️ 2. Select 'Run' -> 'Options' tab")
                print("⚠️ 3. Set StoreKit Configuration to 'Configuration.storekit'")
                print("⚠️ 4. Make sure 'Use StoreKit Configuration File' is checked")
                print("⚠️ 5. Clean build (Cmd+Shift+K) and run again")
                print("⚠️ 6. For device testing, configure sandbox accounts in App Store Connect")
            } else {
                print("✅ Successfully loaded \(availableProducts.count) products:")
                for product in availableProducts {
                    print("📦 \(product.id)")
                    print("   Name: \(product.displayName)")
                    print("   Price: \(product.displayPrice)")
                    print("   Type: \(product.type)")
                    if let subscription = product.subscription {
                        print("   Period: \(subscription.subscriptionPeriod)")
                    }
                }
            }
        } catch {
            await MainActor.run {
                purchaseError = "StoreKit configuration error. Please check Xcode scheme settings."
            }
            print("❌ Failed to load products: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            if let storeKitError = error as? StoreKitError {
                switch storeKitError {
                case .networkError(let underlyingError):
                    print("❌ Network error: \(underlyingError)")
                case .systemError(let underlyingError):
                    print("❌ System error: \(underlyingError)")
                case .userCancelled:
                    print("❌ User cancelled")
                case .notAvailableInStorefront:
                    print("❌ Not available in current storefront")
                case .notEntitled:
                    print("❌ Not entitled")
                case .unsupported:
                    print("❌ StoreKit operation not supported")
                case .unknown:
                    print("❌ Unknown StoreKit error")
                @unknown default:
                    print("❌ Unhandled StoreKit error: \(storeKitError)")
                }
            }
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                print("❌ User info: \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func purchaseSubscription(productID: String) async {
        print("🔘 purchaseSubscription called with productID: \(productID)")
        
        isLoading = true
        purchaseError = nil
        
        // Force reload products if they haven't been loaded yet
        if availableProducts.isEmpty {
            print("🔄 No products loaded, forcing fresh load...")
            await forceReloadProducts()
        }
        
        // Give it one more try if still empty
        if availableProducts.isEmpty {
            print("🔄 Still no products, final retry with diagnostic...")
            await testStoreKitConfiguration()
            await loadProducts()
        }
        
        print("🔘 Available products: \(availableProducts.map { $0.id })")
        guard let product = availableProducts.first(where: { $0.id == productID }) else {
            print("❌ Product not found: \(productID)")
            print("❌ Available: \(availableProducts.map { $0.id })")

            #if DEBUG && targetEnvironment(simulator)
            // StoreKit isn't configured in the scheme — silently grant access in dev.
            print("🔧 DEBUG/Simulator: Granting premium access without StoreKit (scheme not configured)")
            isDevelopmentMode = true
            hasPhysicsEnginePremium = true
            isSubscriptionActive = true
            isLoading = false
            #else
            purchaseError = availableProducts.isEmpty
                ? "Store temporarily unavailable. Please try again later."
                : "Product not found: \(productID)"
            isLoading = false
            #endif
            return
        }
        
        do {
            let result = try await product.purchase()
            await handlePurchaseResult(result)
        } catch {
            purchaseError = error.localizedDescription
            print("❌ Purchase error: \(error)")
        }
        
        isLoading = false
    }
    
    func purchaseMonthlySubscription() async {
        await purchaseSubscription(productID: monthlySubscriptionID)
    }
    
    func purchaseAnnualSubscription() async {
        await purchaseSubscription(productID: annualSubscriptionID)
    }
    
    // Legacy method - now redirects to monthly subscription
    func purchasePhysicsEngine() async {
        await purchaseSubscription(productID: monthlySubscriptionID)
    }
    
    private func handlePurchaseResult(_ result: Product.PurchaseResult) async {
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // Transaction is verified - the transaction listener will handle finishing it
                print("✅ Premium purchased successfully: \(transaction.productID)")
                print("🔄 Transaction will be processed by update listener")
                
                // Don't finish the transaction here - let the listener handle it
                // This prevents duplicate processing
                
            case .unverified(_, let error):
                purchaseError = "Purchase could not be verified: \(error.localizedDescription)"
                print("❌ Unverified purchase: \(error)")
            }
            
        case .userCancelled:
            print("👤 User cancelled purchase")
            
        case .pending:
            print("⏳ Purchase is pending - waiting for completion")
            
        @unknown default:
            purchaseError = "Unknown purchase result"
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        
        do {
            try await AppStore.sync()
            await checkPurchaseStatus()
        } catch {
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func checkPurchaseStatus() async {
        await checkSubscriptionStatus()
    }
    
    private func checkSubscriptionStatus() async {
        hasPhysicsEnginePremium = false
        currentSubscription = nil
        
        // Check for active subscriptions or one-time purchases
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if productIDs.contains(transaction.productID) {
                    hasPhysicsEnginePremium = true
                    
                    // Check if it's a subscription and get status
                    if let product = availableProducts.first(where: { $0.id == transaction.productID }),
                       let subscription = product.subscription {
                        do {
                            let statuses = try await subscription.status
                            currentSubscription = statuses.first
                        } catch {
                            print("❌ Failed to get subscription status: \(error)")
                        }
                    }
                    break
                }
            case .unverified:
                break
            }
        }
        
        // Update isSubscriptionActive based on current status
        updateSubscriptionActiveStatus()
    }
    
    private func updateSubscriptionActiveStatus() {
        guard let status = currentSubscription else {
            isSubscriptionActive = hasPhysicsEnginePremium
            return
        }
        
        switch status.state {
        case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
            isSubscriptionActive = true
        case .expired, .revoked:
            isSubscriptionActive = false
        default:
            isSubscriptionActive = false
        }
    }
    
    // MARK: - Subscription Status Helpers
    
    var subscriptionExpiryDate: Date? {
        // TODO: Implement proper expiration date retrieval when StoreKit API is clarified
        return nil
    }
    
    var monthlyProduct: Product? {
        availableProducts.first { $0.id == monthlySubscriptionID }
    }
    
    var annualProduct: Product? {
        availableProducts.first { $0.id == annualSubscriptionID }
    }
    
    // Product pricing helpers
    var monthlyPrice: String {
        if let product = monthlyProduct {
            return product.displayPrice
        }
        // Fallback prices from Configuration.storekit
        return "$1.99"
    }
    
    var annualPrice: String {
        if let product = annualProduct {
            return product.displayPrice
        }
        // Fallback prices from Configuration.storekit
        return "$21.99"
    }
    
    var isStoreKitWorking: Bool {
        return !availableProducts.isEmpty
    }
    
    // MARK: - Development Mode Controls (Use only for development/testing)
    
    func setDevelopmentMode(_ enabled: Bool) {
        isDevelopmentMode = enabled
        
        if enabled {
            print("🔧 Development mode enabled - FOR TESTING ONLY")
            print("⚠️ This bypasses App Store purchases for development")
            // Enable premium access for development/testing
            hasPhysicsEnginePremium = true
            isSubscriptionActive = true
            print("✅ Premium features unlocked for development")
        } else {
            print("🏭 Development mode disabled - Checking actual purchases")
            // Only reset if not actually purchased
            Task {
                await checkPurchaseStatus()
            }
        }
    }
    
    // This function should ONLY be used during development/testing
    // It will NOT work in release builds
    func enableDevelopmentModeForTesting() {
        #if DEBUG
        print("🔧 Enabling development mode for testing purposes (DEBUG BUILD ONLY)")
        setDevelopmentMode(true)
        #else
        print("❌ Development mode not available in release builds")
        purchaseError = "Please purchase premium features through the App Store"
        showPaywall = true
        #endif
    }

    // MARK: - App Store Review Mode (Works in production builds)

    func enableAppStoreReviewMode() {
        isAppStoreReviewMode = true
        print("📱 App Store Review Mode enabled - Premium features unlocked for Apple reviewers")
        print("⚠️ This should only be used during App Store review process")
        // Dismiss any existing paywall
        showPaywall = false
    }

    func disableAppStoreReviewMode() {
        isAppStoreReviewMode = false
        print("📱 App Store Review Mode disabled - Checking actual premium status")
        // Check actual purchase status
        Task {
            await checkPurchaseStatus()
        }
    }
    
    // MARK: - Paywall Controls
    
    func requirePremiumAccess() {
        if !canAccessPhysicsEngine {
            showPaywall = true
        }
    }
    
    func dismissPaywall() {
        showPaywall = false
    }
    
    // Force reset premium access - useful for testing paywall enforcement
    func resetPremiumAccess() {
        print("🔄 Resetting premium access to default state")
        hasPhysicsEnginePremium = false
        isSubscriptionActive = false
        isDevelopmentMode = false
        isAppStoreReviewMode = false
        currentSubscription = nil
        purchaseError = nil
        showPaywall = false
    }
    
    // Public method to force refresh StoreKit when encountering errors
    func refreshStoreKitConfiguration() async {
        print("🔄 Force refreshing StoreKit configuration due to user request...")
        await MainActor.run {
            purchaseError = nil
            isLoading = true
        }
        
        await forceReloadProducts()
        
        await MainActor.run {
            isLoading = false
        }
        
        if availableProducts.isEmpty {
            print("❌ StoreKit refresh failed - products still unavailable")
            await MainActor.run {
                purchaseError = "StoreKit configuration issue. Please restart the app or contact support."
            }
        } else {
            print("✅ StoreKit refresh successful - \(availableProducts.count) products available")
        }
    }
    
    // Validate premium access - returns true only if user has genuine premium
    func validatePremiumAccess() -> Bool {
        // Allow access for legitimate premium users, development mode (DEBUG only), or App Store review mode
        #if DEBUG
        return hasPhysicsEnginePremium || isSubscriptionActive || isDevelopmentMode || isAppStoreReviewMode
        #else
        return hasPhysicsEnginePremium || isSubscriptionActive || isAppStoreReviewMode
        #endif
    }
    
    // Force reload products with detailed diagnostics
    func forceReloadProducts() async {
        print("🔄 Force reloading StoreKit products...")
        await MainActor.run {
            availableProducts = []
            purchaseError = nil
        }
        
        // Multiple retry attempts
        for attempt in 1...3 {
            print("🔄 Attempt \(attempt)/3...")
            await loadProducts()
            
            if !availableProducts.isEmpty {
                print("✅ Products loaded on attempt \(attempt)")
                break
            }
            
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second between attempts
            }
        }
        
        await testStoreKitConfiguration()
    }
    
    // Test StoreKit configuration
    func testStoreKitConfiguration() async {
        print("🧪 === STOREKIT DIAGNOSTIC REPORT ===")
        print("🧪 Available products count: \(availableProducts.count)")
        print("🧪 Product IDs we're looking for: \(productIDs)")
        
        // Environment detection
        #if DEBUG
        print("🧪 Build configuration: DEBUG")
        #else
        print("🧪 Build configuration: RELEASE")
        #endif
        
        #if targetEnvironment(simulator)
        print("🧪 Environment: iOS Simulator")
        print("🧪 Should use: StoreKit Testing (Configuration.storekit)")
        #else
        print("🧪 Environment: Physical Device")
        print("🧪 Should use: App Store Sandbox/Production")
        #endif
        
        if availableProducts.isEmpty {
            print("🧪 No products loaded. Attempting fresh load...")
            await loadProducts()
        }
        
        print("🧪 FINAL RESULTS:")
        print("   - Products loaded: \(availableProducts.count > 0 ? "✅" : "❌") (\(availableProducts.count))")
        print("   - Monthly subscription: \(monthlyProduct != nil ? "✅" : "❌")")
        print("   - Annual subscription: \(annualProduct != nil ? "✅" : "❌")")
        
        if availableProducts.isEmpty {
            print("🧪 ❌ CRITICAL ISSUE: No products found")
            print("🧪 📋 TROUBLESHOOTING CHECKLIST:")
            print("🧪    1. Xcode → Product → Scheme → Edit Scheme")
            print("🧪    2. Run → Options → StoreKit Configuration")
            print("🧪    3. Set to 'Configuration.storekit' and check the box")
            print("🧪    4. Clean build (Cmd+Shift+K)")
            print("🧪    5. Restart Xcode and simulator")
            print("🧪    6. For device: Sign out of App Store, use sandbox account")
        } else {
            print("🧪 ✅ SUCCESS: StoreKit is working")
            for product in availableProducts {
                print("🧪    📦 \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
        }
        print("🧪 === END DIAGNOSTIC REPORT ===")
    }
    
    // Simple direct StoreKit test - bypasses all caching and retries
    func simpleStoreKitTest() async {
        print("🔬 === SIMPLE STOREKIT TEST ===")
        print("🔬 Testing direct Product.products() call...")
        print("🔬 Product IDs: \(productIDs)")
        
        do {
            let directProducts = try await Product.products(for: productIDs)
            print("🔬 Direct call result: \(directProducts.count) products")
            
            if directProducts.isEmpty {
                print("🔬 ❌ ZERO products returned")
                print("🔬 This confirms StoreKit configuration issue")
                print("🔬 Configuration.storekit is not being loaded")
            } else {
                print("🔬 ✅ Products found:")
                for product in directProducts {
                    print("🔬    \(product.id) - \(product.displayName) - \(product.displayPrice)")
                }
            }
        } catch {
            print("🔬 ❌ Direct Product.products() failed:")
            print("🔬 Error: \(error)")
            print("🔬 This means fundamental StoreKit setup issue")
        }
        
        print("🔬 === END SIMPLE TEST ===")
    }
    
    // Verify StoreKit is available and properly configured
    func verifyStoreKitAvailability() async {
        print("🔍 === STOREKIT AVAILABILITY CHECK ===")
        
        // Check if StoreKit 2 is available
        if #available(iOS 15.0, *) {
            print("✅ StoreKit 2 API available")
        } else {
            print("⚠️ Using legacy StoreKit API")
        }
        
        // Check bundle identifier
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        print("📱 Bundle Identifier: \(bundleID)")
        
        if bundleID != "nakulb.Golf-Swing-AI" {
            print("⚠️ WARNING: Bundle ID mismatch! Expected: nakulb.Golf-Swing-AI, Got: \(bundleID)")
        }
        
        // Try to get current entitlements (this works even without products loaded)
        var hasEntitlements = false
        for await result in StoreKit.Transaction.currentEntitlements {
            hasEntitlements = true
            switch result {
            case .verified(let transaction):
                print("✅ Found verified entitlement: \(transaction.productID)")
            case .unverified(let transaction, _):
                print("⚠️ Found unverified entitlement: \(transaction.productID)")
            }
        }
        
        if !hasEntitlements {
            print("ℹ️ No current entitlements found (normal for new users)")
        }
        
        print("🔍 === END AVAILABILITY CHECK ===")
    }
    
    // Validate StoreKit setup for debugging
    func validateStoreKitSetup() {
        print("📁 === STOREKIT SETUP VALIDATION ===")
        
        // Note: Configuration.storekit files are NOT included in the app bundle
        // They are only used by Xcode during development/testing
        
        print("📁 StoreKit Configuration Info:")
        print("📁 For SIMULATOR testing:")
        print("📁   1. In Xcode: Product → Scheme → Edit Scheme")
        print("📁   2. Run tab → Options → StoreKit Configuration")
        print("📁   3. Select 'Configuration.storekit' file")
        print("📁   4. Enable 'Use StoreKit Testing in Xcode'")
        print("📁")
        print("📁 For DEVICE testing:")
        print("📁   1. Use sandbox account in Settings → App Store")
        print("📁   2. Products must be configured in App Store Connect")
        print("📁   3. App must be uploaded to TestFlight or App Store Connect")
        print("📁")
        print("📁 Product IDs being requested:")
        for productID in productIDs {
            print("📁   - \(productID)")
        }
        
        print("📁 === END SETUP VALIDATION ===")
    }
    
    // Quick StoreKit configuration health check - call this first when debugging
    func quickStoreKitHealthCheck() async {
        print("🏥 === STOREKIT HEALTH CHECK ===")
        
        // 1. Check file presence
        let configExists = Bundle.main.path(forResource: "Configuration", ofType: "storekit") != nil
        print("🏥 Configuration.storekit in bundle: \(configExists ? "✅" : "❌")")
        
        // 2. Test direct product loading
        do {
            let testProducts = try await Product.products(for: [monthlySubscriptionID, annualSubscriptionID])
            print("🏥 Direct product loading: \(testProducts.isEmpty ? "❌" : "✅") (\(testProducts.count) products)")
            
            if testProducts.isEmpty {
                print("🏥 ❌ CRITICAL: StoreKit returning no products")
                print("🏥 This means scheme StoreKit configuration is NOT active")
                print("🏥 REQUIRED STEPS:")
                print("🏥   1. Stop app and simulator")
                print("🏥   2. Xcode → Product → Scheme → Edit Scheme")
                print("🏥   3. Run → Options → StoreKit Configuration")
                print("🏥   4. Select 'Configuration.storekit' file")
                print("🏥   5. Check 'Use StoreKit Configuration File'")
                print("🏥   6. Clean build + restart")
                print("🏥 ⚠️ ALTERNATIVE: Try the manual refresh in PremiumManager")
            } else {
                print("🏥 ✅ StoreKit is working correctly")
                for product in testProducts {
                    print("🏥   - \(product.id): \(product.displayName) (\(product.displayPrice))")
                }
            }
        } catch {
            print("🏥 ❌ Product loading failed: \(error)")
            print("🏥 This indicates a fundamental StoreKit setup issue")
        }
        
        print("🏥 === END HEALTH CHECK ===")
    }
    
    // Manual StoreKit refresh for debugging - call this when StoreKit appears broken
    func manualStoreKitRefresh() async {
        print("🔧 === MANUAL STOREKIT REFRESH ===")
        
        await MainActor.run {
            isLoading = true
            purchaseError = nil
            availableProducts = []
        }
        
        // Force clear any cached products
        print("🔧 Clearing cached products...")
        
        // Wait a moment for system to clear
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Attempt multiple refresh strategies
        for attempt in 1...5 {
            print("🔧 Manual refresh attempt \(attempt)/5...")
            
            do {
                let freshProducts = try await Product.products(for: productIDs)
                
                if !freshProducts.isEmpty {
                    await MainActor.run {
                        availableProducts = freshProducts
                        isLoading = false
                    }
                    
                    print("🔧 ✅ Manual refresh successful on attempt \(attempt)!")
                    print("🔧 Found \(freshProducts.count) products:")
                    for product in freshProducts {
                        print("🔧   - \(product.id): \(product.displayName) (\(product.displayPrice))")
                    }
                    return
                }
            } catch {
                print("🔧 ❌ Manual refresh attempt \(attempt) failed: \(error)")
            }
            
            // Exponential backoff
            let delay = UInt64(attempt * 1_000_000_000) // 1, 2, 3, 4, 5 seconds
            try? await Task.sleep(nanoseconds: delay)
        }
        
        await MainActor.run {
            isLoading = false
            purchaseError = "StoreKit configuration issue persists. Please restart the app or check Xcode scheme settings."
        }
        
        print("🔧 ❌ Manual refresh failed after 5 attempts")
        print("🔧 === END MANUAL REFRESH ===")
    }
}


// MARK: - Premium Status Extension

extension PremiumManager {
    var canAccessPhysicsEngine: Bool {
        // Allow access for legitimate premium users, development mode (DEBUG only), or App Store review mode
        #if DEBUG
        return hasPhysicsEnginePremium || isSubscriptionActive || isDevelopmentMode || isAppStoreReviewMode
        #else
        return hasPhysicsEnginePremium || isSubscriptionActive || isAppStoreReviewMode
        #endif
    }
}