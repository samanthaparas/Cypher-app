//
//  IAPManager.swift
//  c705
//
//  Created for Apple In-App Purchase integration
//
//  PURPOSE: Handles in-app purchases through Apple's StoreKit: loading
//  products, buying beats or subscriptions, and checking what the user
//  owns. Version 1.0 does not sell anything, so this is groundwork for
//  a later release.
//

import Foundation
import StoreKit
import Combine

@MainActor
// @Published lists below (products, purchased IDs, active subscription) redraw any screen
// showing them.
class IAPManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscriptions: [Product] = []
    @Published var activeSubscription: Product?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    // Subscription product IDs
    // The subscription product names, which must match what is set up in App Store Connect.
    static let subscriptionProductIDs = [
        "c705.creator.plus",
        "c705.creator.pro"
    ]
    
    // Beat product ID prefix
    // Each beat needs its own product named beat.lease plus its id in App Store Connect. That
    // does not scale to many beats.
    static let beatProductIDPrefix = "beat.lease"
    
    // Starts listening for purchase updates as soon as the manager is created.
    init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    /**
     * Load products from App Store Connect
     * Product IDs should match format: beat.lease.{beatId}
     */
    // Asks Apple for the price and details of the given products.
    func loadProducts(productIDs: [String]) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: productIDs)
            self.products = products
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("Error loading products: \(error)")
        }
        
        isLoading = false
    }
    
    /**
     * Load subscription products
     */
    // Loads the subscription products the same way.
    func loadSubscriptions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: Self.subscriptionProductIDs)
            self.subscriptions = products
        } catch {
            errorMessage = "Failed to load subscriptions: \(error.localizedDescription)"
            print("Error loading subscriptions: \(error)")
        }
        
        isLoading = false
    }
    
    /**
     * Purchase a subscription
     */
    // Starts a subscription purchase. If it succeeds, the purchase is also reported to our
    // backend so the server records which plan the user has.
    func purchaseSubscription(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            
            // Send to backend for validation and storage
            if let receipt = await getReceipt() {
                do {
                    let tier = product.id == "c705.creator.plus" ? "CREATOR_PLUS" : "PRO_CREATOR"
                    let expiresAt = transaction.expirationDate?.ISO8601Format()
                    _ = try await APIService.shared.subscribe(
                        tier: tier,
                        productId: product.id,
                        receipt: receipt,
                        expiresAt: expiresAt
                    )
                    activeSubscription = product
                } catch {
                    print("Failed to sync subscription to backend: \(error)")
                }
            }
            
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }
    
    /**
     * Check current subscription status
     */
    // Asks our backend which plan the user is on and updates activeSubscription to match.
    func checkSubscriptionStatus() async {
        do {
            let subscription = try await APIService.shared.getSubscription()
            
            // Update active subscription based on backend status
            if subscription.isActive {
                let productID = subscription.tier == .CREATOR_PLUS ? "c705.creator.plus" : "c705.creator.pro"
                if let product = subscriptions.first(where: { $0.id == productID }) {
                    activeSubscription = product
                }
            } else {
                activeSubscription = nil
            }
        } catch {
            print("Failed to check subscription status: \(error)")
        }
    }
    
    /**
     * Purchase a product
     */
    // Buys one product. It returns nothing if the user cancels or the payment is still pending,
    // and finishes the transaction so Apple stops re-sending it.
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }
    
    /**
     * Get receipt data for backend validation
     */
    // Returns an identifier for the purchase so the server can record it. In production the
    // server should verify it with Apple, which is not built yet.
    func getReceipt() async -> String? {
        // For StoreKit 2, we use transaction receipts
        // In production, you should validate with Apple's App Store Server API
        // Get current entitlements (subscriptions)
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Return transaction ID as receipt identifier
                // transaction.id is UInt64, convert to String
                // In production, use App Store Server API for full receipt
                return String(transaction.id)
            }
        }
        return nil
    }
    
    /**
     * Listen for transaction updates
     */
    // Watches for purchases that finish later, for example approved by a parent or bought on
    // another device.
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    /**
     * Verify transaction signature
     * Nonisolated because it's called from detached tasks
     */
    // Apple signs every purchase. This accepts the verified ones and rejects any that fail the
    // check.
    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw IAPError.unverifiedTransaction
        case .verified(let safe):
            return safe
        }
    }
}

// The things that can go wrong with a purchase, with readable messages.
enum IAPError: Error {
    case unverifiedTransaction
    case productNotFound
    case purchaseFailed
    
    var localizedDescription: String {
        switch self {
        case .unverifiedTransaction:
            return "Transaction could not be verified"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}

