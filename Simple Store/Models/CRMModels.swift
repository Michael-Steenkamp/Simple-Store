//
// CRMModels.swift
// Simple Store
//

import Foundation
import SwiftData

// MARK: - Local SwiftData Models

/// A SwiftData model representing a categorization status for a customer.
@Model
public final class CustomerStatus {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var storeId: String
    
    public var customers: [Customer]?
    
    public init(id: UUID = UUID(), name: String, storeId: String) {
        self.id = id
        self.name = name
        self.storeId = storeId
    }
}

/// A SwiftData model representing a store customer.
@Model
public final class Customer {
    @Attribute(.unique) public var id: UUID
    public var storeId: String
    public var firstName: String
    public var lastName: String
    public var email: String
    public var phone: String
    public var notes: String
    public var dateAdded: Date
    public var updatedAt: Date
    public var isActive: Bool
    
    @Relationship(inverse: \CustomerStatus.customers)
    public var status: CustomerStatus?
    
    @Relationship(deleteRule: .cascade)
    public var transactions: [Transaction]?
    
    public init(
        id: UUID = UUID(),
        storeId: String,
        firstName: String,
        lastName: String,
        email: String = "",
        phone: String = "",
        notes: String = "",
        status: CustomerStatus? = nil
    ) {
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
        self.isActive = true
    }
}

public extension Customer {
    /// A computed property returning the combined first and last name.
    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// A SwiftData model representing an employee record for local POS usage.
@Model
public final class Employee {
    @Attribute(.unique) public var id: UUID
    public var storeId: String
    public var name: String
    public var isActive: Bool
    
    public init(id: UUID = UUID(), storeId: String, name: String, isActive: Bool = true) {
        self.id = id
        self.storeId = storeId
        self.name = name
        self.isActive = isActive
    }
}

/// A SwiftData model representing a finalized point-of-sale transaction.
@Model
public final class Transaction {
    @Attribute(.unique) public var id: UUID
    public var storeId: String
    public var date: Date
    public var totalAmount: Double
    
    @Relationship(deleteRule: .cascade)
    public var lineItems: [LineItem]?
    
    @Relationship(deleteRule: .cascade)
    public var payments: [PaymentSplit]?
    
    /// The staff member processing the sale.
    public var employeeName: String?
    public var employeeId: String?
    
    /// The buyer (Customer).
    @Relationship(inverse: \Customer.transactions)
    public var customer: Customer?
    
    /// The buyer (Internal Staff).
    public var buyerEmployeeName: String?
    public var buyerEmployeeId: String?
    
    public init(
        id: UUID = UUID(),
        storeId: String,
        totalAmount: Double,
        employeeName: String? = nil,
        employeeId: String? = nil,
        customer: Customer? = nil,
        buyerEmployeeName: String? = nil,
        buyerEmployeeId: String? = nil
    ) {
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

/// A SwiftData model representing an individual item within a transaction.
@Model
public final class LineItem {
    @Attribute(.unique) public var id: UUID
    public var itemName: String
    public var itemID: String
    public var quantity: Int
    public var pricePerUnit: Double
    
    @Relationship(inverse: \Transaction.lineItems)
    public var transaction: Transaction?
    
    public init(id: UUID = UUID(), itemName: String, itemID: String, quantity: Int, pricePerUnit: Double) {
        self.id = id
        self.itemName = itemName
        self.itemID = itemID
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
    }
}

/// A SwiftData model representing a segmented payment method for a transaction.
@Model
public final class PaymentSplit {
    @Attribute(.unique) public var id: UUID
    public var method: String
    public var amount: Double
    
    @Relationship(inverse: \Transaction.payments)
    public var transaction: Transaction?
    
    public init(id: UUID = UUID(), method: String, amount: Double) {
        self.id = id
        self.method = method
        self.amount = amount
    }
}

// MARK: - Data Transfer Objects (DTOs)

public struct CustomerStatusDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let storeId: String
    
    public init(from model: CustomerStatus) {
        self.id = model.id.uuidString
        self.name = model.name
        self.storeId = model.storeId
    }
}

public struct CustomerDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let storeId: String
    public let firstName: String
    public let lastName: String
    public let email: String
    public let phone: String
    public let notes: String
    public let dateAdded: Date
    public let updatedAt: Date
    public let isActive: Bool
    public let statusId: String?
    
    public init(from model: Customer) {
        self.id = model.id.uuidString
        self.storeId = model.storeId
        self.firstName = model.firstName
        self.lastName = model.lastName
        self.email = model.email
        self.phone = model.phone
        self.notes = model.notes
        self.dateAdded = model.dateAdded
        self.updatedAt = model.updatedAt
        self.isActive = model.isActive
        self.statusId = model.status?.id.uuidString
    }
}

public struct EmployeeDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let storeId: String
    public let name: String
    public let isActive: Bool
    
    public init(from model: Employee) {
        self.id = model.id.uuidString
        self.storeId = model.storeId
        self.name = model.name
        self.isActive = model.isActive
    }
}

public struct LineItemDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let itemName: String
    public let itemID: String
    public let quantity: Int
    public let pricePerUnit: Double
    
    public init(from model: LineItem) {
        self.id = model.id.uuidString
        self.itemName = model.itemName
        self.itemID = model.itemID
        self.quantity = model.quantity
        self.pricePerUnit = model.pricePerUnit
    }
}

public struct PaymentSplitDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let method: String
    public let amount: Double
    
    public init(from model: PaymentSplit) {
        self.id = model.id.uuidString
        self.method = model.method
        self.amount = model.amount
    }
}

public struct TransactionDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let storeId: String
    public let date: Date
    public let totalAmount: Double
    public let employeeName: String?
    public let employeeId: String?
    public let customerId: String?
    public let buyerEmployeeName: String?
    public let buyerEmployeeId: String?
    
    public let lineItems: [LineItemDTO]
    public let payments: [PaymentSplitDTO]
    
    public init(from model: Transaction) {
        self.id = model.id.uuidString
        self.storeId = model.storeId
        self.date = model.date
        self.totalAmount = model.totalAmount
        self.employeeName = model.employeeName
        self.employeeId = model.employeeId
        self.customerId = model.customer?.id.uuidString
        self.buyerEmployeeName = model.buyerEmployeeName
        self.buyerEmployeeId = model.buyerEmployeeId
        
        self.lineItems = model.lineItems?.map { LineItemDTO(from: $0) } ?? []
        self.payments = model.payments?.map { PaymentSplitDTO(from: $0) } ?? []
    }
}
