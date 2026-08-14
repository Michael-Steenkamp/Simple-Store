//
//  SubscriptionManager.swift
//  Simple Store
//

import StoreKit
import SwiftUI

// MARK: - Utilities

/// A thread-safe wrapper that automatically cancels a Task when deallocated.
/// This natively bypasses Swift 6 actor-isolation restrictions inside `deinit`.
fileprivate final class TaskCanceller: Sendable {
    let task: Task<Void, Never>
    init(task: Task<Void, Never>) { self.task = task }
    deinit { task.cancel() }
}

/// Manages App Store subscriptions, StoreKit 2 transactions, and premium feature entitlements.
/// Acts as the central `@MainActor` source of truth for paywalled or administrative access.
@Observable
@MainActor
public final class SubscriptionManager {
    
    // MARK: - Entitlement State
    
    private(set) var hasActiveAppStoreSubscription: Bool = false
    var isSystemAdmin: Bool = false
    
    var hasPremiumAccess: Bool {
        return hasActiveAppStoreSubscription || isSystemAdmin
    }
    
    // MARK: - StoreKit State
    
    private let subscriptionProductID = "com.simplestore.premium.monthly"
    private(set) var subscriptions: [Product] = []
    private(set) var isLoadingProducts: Bool = false
    
    private var transactionObserver: TaskCanceller?
    
    // MARK: - Initialization
    
    public init() {
        Task {
            await fetchProducts()
            await updateSubscriptionStatus()
        }
        
        let task = Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.updateSubscriptionStatus()
            }
        }
        
        transactionObserver = TaskCanceller(task: task)
    }
    
    // MARK: - StoreKit Operations
    
    public func fetchProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        
        do {
            subscriptions = try await Product.products(for: [subscriptionProductID])
        } catch {
            print("Failed to fetch StoreKit products: \(error.localizedDescription)")
        }
    }
    
    public func updateSubscriptionStatus() async {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            
            if transaction.productID == subscriptionProductID {
                hasActiveAppStoreSubscription = transaction.revocationDate == nil
                return
            }
        }
        hasActiveAppStoreSubscription = false
    }
    
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
}
