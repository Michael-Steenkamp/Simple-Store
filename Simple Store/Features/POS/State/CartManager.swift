//
//  CartManager.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-21.
//

import SwiftUI
import SwiftData

@Observable
class CartManager {
    var items: [StoreItem: Int] = [:]
    var selectedCustomer: Customer? = nil
    var selectedEmployee: Employee? = nil
    
    // NEW: Payment splits now live in global memory so they aren't lost
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
