//
//  SubscriptionManager.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import StoreKit
import SwiftUI

/// Manages App Store subscriptions and developer overrides.
@Observable
@MainActor
final class SubscriptionManager {
    /// Tracks if the user has a valid, paid Apple subscription.
    private(set) var hasActiveAppStoreSubscription: Bool = false
    
    /// Injected from SessionManager: tracks if the user is the developer.
    var isSystemAdmin: Bool = false
    
    /// The single source of truth for premium feature access.
    var hasPremiumAccess: Bool {
        return hasActiveAppStoreSubscription || isSystemAdmin
    }
    
    // StoreKit product identifiers
    private let subscriptionProductID = "com.simplestore.premium.monthly"
    private(set) var subscriptions: [Product] = []
    private(set) var isLoadingProducts: Bool = false
    
    private var updateListenerTask: Task<Void, Never>? = nil
    
    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await fetchProducts()
            await updateSubscriptionStatus()
        }
    }
    
    /// Fetches the subscription products from App Store Connect.
    func fetchProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        
        do {
            subscriptions = try await Product.products(for: [subscriptionProductID])
        } catch {
            print("Failed to fetch StoreKit products: \(error.localizedDescription)")
        }
    }
    
    /// Checks the current entitlement status natively via StoreKit 2.
    func updateSubscriptionStatus() async {
        // Use StoreKit.Transaction to avoid collision with the SwiftData POS Transaction model
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            
            if transaction.productID == subscriptionProductID {
                // Check if the subscription hasn't been revoked or expired
                hasActiveAppStoreSubscription = transaction.revocationDate == nil
                return
            }
        }
        hasActiveAppStoreSubscription = false
    }
    
    /// Initiates a purchase process for the user.
    func purchase(_ product: Product) async throws -> Bool {
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
    
    /// Listens for external transaction updates (e.g., renewals, cancellations outside the app).
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            // Use StoreKit.Transaction to avoid collision with the SwiftData POS Transaction model
            for await result in StoreKit.Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self.updateSubscriptionStatus()
            }
        }
    }
}
