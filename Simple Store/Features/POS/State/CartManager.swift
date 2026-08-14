//
//  CartManager.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// Centralized `@MainActor` state container managing the active point-of-sale checkout session.
/// Guarantees thread-safe access to cart items, selected personnel, and payment drafts.
@MainActor
@Observable
public final class CartManager {
    var items: [StoreItem: Int] = [:]
    var selectedCustomer: Customer? = nil
    var selectedEmployee: Employee? = nil
    
    // Payment splits live in global memory to persist across sheet dismissals
    var paymentSplits: [PaymentSplitDraft] = []
    
    var totalItemCount: Int {
        items.values.reduce(0, +)
    }
    
    var totalAmount: Double {
        items.reduce(0) { $0 + ($1.key.salesPrice * Double($1.value)) }
    }
    
    func add(_ item: StoreItem) {
        let currentQuantity = items[item] ?? 0
        if currentQuantity < item.stockCount {
            items[item] = currentQuantity + 1
        }
    }
    
    func remove(_ item: StoreItem) {
        guard let currentQuantity = items[item] else { return }
        if currentQuantity > 1 {
            items[item] = currentQuantity - 1
        } else {
            items.removeValue(forKey: item)
        }
    }
    
    func completelyRemove(_ item: StoreItem) {
        items.removeValue(forKey: item)
    }
    
    func clearCart() {
        items.removeAll()
        selectedCustomer = nil
        selectedEmployee = nil
        paymentSplits.removeAll()
    }
}
