//
//  CRMModels.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-19.
//

import Foundation
import SwiftData

// MARK: - Customer Status
@Model
final class CustomerStatus {
    var id: UUID = UUID()
    var name: String = ""
    var storeId: String?
    
    var customers: [Customer]?
    
    init(id: UUID = UUID(), name: String, storeId: String?) {
        self.id = id
        self.name = name
        self.storeId = storeId
    }
}

// MARK: - Customer
@Model
final class Customer {
    var id: UUID = UUID()
    var storeId: String?
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var notes: String = ""
    var dateAdded: Date = Date()
    var updatedAt: Date = Date()
    var isActive: Bool = true
    
    @Relationship(inverse: \CustomerStatus.customers)
    var status: CustomerStatus?
    
    @Relationship(deleteRule: .cascade)
    var transactions: [Transaction]?
    
    init(id: UUID = UUID(), storeId: String? = nil, firstName: String, lastName: String, email: String = "", phone: String = "", notes: String = "", status: CustomerStatus? = nil) {
        self.id = id
        self.storeId = storeId
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.notes = notes
        self.status = status
        self.dateAdded = Date()
        self.updatedAt = Date()
    }
}

extension Customer {
    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// MARK: - Employee
@Model
final class Employee {
    var id: UUID = UUID()
    var storeId: String?
    var name: String = ""
    var isActive: Bool = true
    
    init(id: UUID = UUID(), storeId: String? = nil, name: String, isActive: Bool = true) {
        self.id = id
        self.storeId = storeId
        self.name = name
        self.isActive = isActive
    }
}

// MARK: - Transaction (The Complete Order)
@Model
final class Transaction {
    var id: UUID = UUID()
    var storeId: String?
    var date: Date = Date()
    var totalAmount: Double = 0.0
    
    @Relationship(deleteRule: .cascade)
    var lineItems: [LineItem]?
    
    @Relationship(deleteRule: .cascade)
    var payments: [PaymentSplit]?
    
    // The staff member processing the sale
    var employeeName: String?
    var employeeId: String?
    
    // The buyer (Customer)
    @Relationship(inverse: \Customer.transactions)
    var customer: Customer?
    
    // NEW: The buyer (Internal Staff)
    var buyerEmployeeName: String?
    var buyerEmployeeId: String?
    
    init(id: UUID = UUID(), storeId: String? = nil, totalAmount: Double, employeeName: String? = nil, employeeId: String? = nil, customer: Customer? = nil, buyerEmployeeName: String? = nil, buyerEmployeeId: String? = nil) {
        self.id = id
        self.storeId = storeId
        self.date = Date()
        self.totalAmount = totalAmount
        self.employeeName = employeeName
        self.employeeId = employeeId
        self.customer = customer
        self.buyerEmployeeName = buyerEmployeeName
        self.buyerEmployeeId = buyerEmployeeId
    }
}

// MARK: - Line Item
@Model
final class LineItem {
    var id: UUID = UUID()
    var itemName: String = ""
    var itemID: String = ""
    var quantity: Int = 0
    var pricePerUnit: Double = 0.0
    
    @Relationship(inverse: \Transaction.lineItems)
    var transaction: Transaction?
    
    init(id: UUID = UUID(), itemName: String, itemID: String, quantity: Int, pricePerUnit: Double) {
        self.id = id
        self.itemName = itemName
        self.itemID = itemID
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
    }
}

// MARK: - Payment Split
@Model
final class PaymentSplit {
    var id: UUID = UUID()
    var method: String = ""
    var amount: Double = 0.0
    
    @Relationship(inverse: \Transaction.payments)
    var transaction: Transaction?
    
    init(id: UUID = UUID(), method: String, amount: Double) {
        self.id = id
        self.method = method
        self.amount = amount
    }
}
