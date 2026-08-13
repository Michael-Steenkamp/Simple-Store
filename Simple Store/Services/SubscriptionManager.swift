//
//  SubscriptionManager.swift
//  Simple Store
//

import StoreKit
import SwiftUI

/// Manages App Store subscriptions, StoreKit 2 transactions, and premium feature entitlements.
/// Acts as the central `@MainActor` source of truth for paywalled or administrative access.
@Observable
@MainActor
public final class SubscriptionManager {
    
    // MARK: - Entitlement State
    
    /// Indicates if the user has a valid, paid Apple App Store subscription.
    private(set) var hasActiveAppStoreSubscription: Bool = false
    
    /// Indicates if the current user is a system administrator (injected via `SessionManager`).
    var isSystemAdmin: Bool = false
    
    /// The derived single source of truth for premium feature access.
    /// Returns `true` if the user is subscribed or possesses system administrator privileges.
    var hasPremiumAccess: Bool {
        return hasActiveAppStoreSubscription || isSystemAdmin
    }
    
    // MARK: - StoreKit State
    
    private let subscriptionProductID = "com.simplestore.premium.monthly"
    
    /// The list of available subscription products fetched from App Store Connect.
    private(set) var subscriptions: [Product] = []
    
    /// Indicates if the manager is currently fetching products from the network.
    private(set) var isLoadingProducts: Bool = false
    
    private var updateListenerTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public init() {
        updateListenerTask = listenForTransactions()
        Task {
            await fetchProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        // Prevents memory leaks by ensuring the detached async sequence is terminated.
        updateListenerTask?.cancel()
    }
    
    // MARK: - StoreKit Operations
    
    /// Fetches the subscription products from App Store Connect.
    public func fetchProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        
        do {
            subscriptions = try await Product.products(for: [subscriptionProductID])
        } catch {
            // In a production environment, route this to a non-fatal crash reporting tool (e.g., Crashlytics)
            print("Failed to fetch StoreKit products: \(error.localizedDescription)")
        }
    }
    
    /// Validates the current entitlement status natively using StoreKit 2.
    public func updateSubscriptionStatus() async {
        // Explicitly scoped to StoreKit.Transaction to prevent collision with SwiftData 'Transaction' models.
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            
            if transaction.productID == subscriptionProductID {
                hasActiveAppStoreSubscription = transaction.revocationDate == nil
                return
            }
        }
        hasActiveAppStoreSubscription = false
    }
    
    /// Initiates the App Store purchase flow for a specified product.
    ///
    /// - Parameter product: The StoreKit `Product` the user intends to purchase.
    /// - Returns: A boolean indicating whether the purchase was successfully verified and completed.
    /// - Throws: An error if the StoreKit purchase operation fails.
    public func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                return false
            }
            await transaction.finish()
            await updateSubscriptionStatus()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Background Listeners
    
    /// Spawns a detached task to monitor external StoreKit transactions (e.g., renewals, outside cancellations).
    /// - Returns: A cancellable `Task` managing the async sequence.
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            // Explicitly scoped to StoreKit.Transaction to prevent collision with SwiftData 'Transaction' models.
            for await result in StoreKit.Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self.updateSubscriptionStatus()
            }
        }
    }
}
