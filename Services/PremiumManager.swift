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
    
    // Subscription Product IDs
    private let monthlySubscriptionID = "com.golfswingai.premium_monthly"
    private let annualSubscriptionID = "com.golfswingai.premium_annual"
    private let physicsEngineProductID = "com.golfswingai.physics_engine_premium" // Legacy one-time purchase
    
    private var productIDs: [String] {
        [monthlySubscriptionID, annualSubscriptionID, physicsEngineProductID]
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
        
        do {
            let products = try await Product.products(for: productIDs)
            await MainActor.run {
                availableProducts = products
            }
            
            if availableProducts.isEmpty {
                print("⚠️ No products found. Ensure Configuration.storekit is set up in Xcode scheme.")
                print("⚠️ Product IDs requested: \(productIDs)")
                print("⚠️ To use StoreKit Testing:")
                print("⚠️ 1. Edit Scheme -> Run -> Options")
                print("⚠️ 2. Set StoreKit Configuration to 'Configuration.storekit'")
                print("⚠️ 3. Clean build and run again")
            } else {
                print("✅ Loaded \(availableProducts.count) products")
                for product in availableProducts {
                    print("📦 Product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
                }
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
            }
            print("❌ Make sure Configuration.storekit is configured in the Xcode scheme")
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
    
    func purchasePhysicsEngine() async {
        await purchaseSubscription(productID: physicsEngineProductID)
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
    
    // Development mode helpers
    var monthlyPrice: String {
        if let product = monthlyProduct {
            return product.displayPrice
        }
        return isDevelopmentMode ? "$1.99" : "Price unavailable"
    }
    
    var annualPrice: String {
        if let product = annualProduct {
            return product.displayPrice
        }
        return isDevelopmentMode ? "$19.99" : "Price unavailable"
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
}


// MARK: - Premium Status Extension

extension PremiumManager {
    var canAccessPhysicsEngine: Bool {
        hasPhysicsEnginePremium
    }
}