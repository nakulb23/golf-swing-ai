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
    @Published var showPaywall = false
    
    private var transactionUpdatesTask: Task<Void, Never>?
    
    // Subscription Product IDs (matching Configuration.storekit)
    private let monthlySubscriptionID = "com.golfswingai.premium_monthly"
    private let annualSubscriptionID = "com.golfswingai.premium_annual"
    
    private var productIDs: [String] {
        [monthlySubscriptionID, annualSubscriptionID]
    }
    
    init() {
        // Start listening for transaction updates immediately at launch
        // This ensures we don't miss any successful purchases
        startTransactionUpdateListener()
        
        Task {
            await loadProducts()
        }
        checkPurchaseStatus()
        
        // Check product loading status after delay for debugging
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if availableProducts.isEmpty {
                print("⚠️ No StoreKit products loaded after 5 seconds. This might be because:")
                print("⚠️ 1. Configuration.storekit is not set in the Xcode scheme")
                print("⚠️ 2. App is running without Xcode simulator")
                print("⚠️ 3. StoreKit Testing is not enabled")
                print("⚠️ Users will need to purchase through App Store to access premium features")
                // DO NOT automatically enable development mode - this bypasses paywall
            }
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
                checkPurchaseStatus()
                
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
        
        // Try to load products if they haven't been loaded yet
        if availableProducts.isEmpty {
            print("🔄 No products loaded, attempting to load...")
            await loadProducts()
        }
        
        // Give it one more try if still empty
        if availableProducts.isEmpty {
            print("🔄 Still no products, retrying load...")
            await loadProducts()
        }
        
        print("🔘 Available products: \(availableProducts.map { $0.id })")
        guard let product = availableProducts.first(where: { $0.id == productID }) else {
            print("❌ Product not found: \(productID)")
            print("❌ Available: \(availableProducts.map { $0.id })")
            if availableProducts.isEmpty {
                print("❌ No StoreKit products available - cannot process purchase")
                purchaseError = "Store is currently unavailable. Please try again later or restart the app."
            } else {
                purchaseError = "Product not found: \(productID)"
            }
            isLoading = false
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
            checkPurchaseStatus()
        } catch {
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func checkPurchaseStatus() {
        Task {
            await checkSubscriptionStatus()
        }
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
            print("⚠️ This should NEVER be enabled in production builds")
            // Only enable for development builds with explicit developer action
            #if DEBUG
            hasPhysicsEnginePremium = true
            isSubscriptionActive = true
            #else
            print("❌ Development mode blocked in release build")
            #endif
        } else {
            // Reset to actual purchased state
            hasPhysicsEnginePremium = false
            isSubscriptionActive = false
            print("🏭 Production mode enabled - Checking actual purchases")
            checkPurchaseStatus()
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
    
    // MARK: - Paywall Controls
    
    func requirePremiumAccess() {
        if !hasPhysicsEnginePremium && !isSubscriptionActive {
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
        currentSubscription = nil
        purchaseError = nil
        showPaywall = false
    }
    
    // Validate premium access - returns true only if user has genuine premium
    func validatePremiumAccess() -> Bool {
        // In release builds, development mode should not grant access
        #if DEBUG
        return hasPhysicsEnginePremium || isSubscriptionActive
        #else
        return (hasPhysicsEnginePremium || isSubscriptionActive) && !isDevelopmentMode
        #endif
    }
    
    // Test StoreKit configuration
    func testStoreKitConfiguration() async {
        print("🧪 Testing StoreKit Configuration...")
        print("🧪 Available products count: \(availableProducts.count)")
        
        if availableProducts.isEmpty {
            print("🧪 No products loaded. Attempting to load now...")
            await loadProducts()
        }
        
        print("🧪 StoreKit Test Results:")
        print("   - Products loaded: \(availableProducts.count > 0 ? "✅" : "❌")")
        print("   - Monthly subscription: \(monthlyProduct != nil ? "✅" : "❌")")
        print("   - Annual subscription: \(annualProduct != nil ? "✅" : "❌")")
        
        if availableProducts.isEmpty {
            print("🧪 ISSUE: No products found")
            print("🧪 SOLUTION: Check Xcode scheme StoreKit configuration")
        } else {
            print("🧪 SUCCESS: StoreKit is properly configured")
        }
    }
}


// MARK: - Premium Status Extension

extension PremiumManager {
    var canAccessPhysicsEngine: Bool {
        hasPhysicsEnginePremium
    }
}