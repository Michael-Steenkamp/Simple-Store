//
//  SyncManager.swift
//  Simple Store
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Manages real-time data synchronization between the local offline-first SwiftData container and the remote Firebase Firestore database.
/// Acts as the central `@MainActor` orchestrator for multi-tenant data ingestion and exfiltration.
@Observable
@MainActor
public final class SyncManager {
    
    // MARK: - Dependencies
    
    private var db: Firestore { Firestore.firestore() }
    
    // MARK: - Listeners
    
    private var inventoryListener: ListenerRegistration?
    private var customersListener: ListenerRegistration?
    private var employeesListener: ListenerRegistration?
    private var transactionsListener: ListenerRegistration?
    private var tagsListener: ListenerRegistration?
    private var statusesListener: ListenerRegistration?
    
    // MARK: - State Properties
    
    /// The currently active workspace ID. Used to detect tenant switching.
    private var currentTrackedStoreId: String?
    
    /// Indicates whether the manager is actively processing incoming network snapshots.
    public var isSyncing: Bool = false
    
    /// The most recent synchronization error, if any.
    public var lastSyncError: String?
    
    // MARK: - Lifecycle Management
    
    /// Initializes real-time Firestore listeners for a specific store workspace and binds them to the provided local context.
    /// - Parameters:
    ///   - storeId: The unique identifier of the target store workspace.
    ///   - context: The `@MainActor` isolated SwiftData context used for local persistence.
    public func startListening(storeId: String, context: ModelContext) {
        if currentTrackedStoreId != storeId {
            clearLocalDatabase(context: context)
            currentTrackedStoreId = storeId
        }
        
        stopAllListeners()
        isSyncing = true
        
        inventoryListener = db.collection("inventory")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingInventory(data: data, context: context)
                }
            }
            
        customersListener = db.collection("customers")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingCustomer(data: data, context: context)
                }
            }
            
        employeesListener = db.collection("employees")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingEmployee(data: data, context: context)
                }
            }
            
        transactionsListener = db.collection("transactions")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingTransaction(data: data, context: context)
                }
            }
            
        tagsListener = db.collection("tags")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingTag(data: data, context: context)
                }
            }
            
        statusesListener = db.collection("customerStatuses")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingCustomerStatus(data: data, context: context)
                }
            }
    }
    
    /// Terminates all active Firestore snapshot listeners and halts synchronization.
    public func stopAllListeners() {
        inventoryListener?.remove()
        customersListener?.remove()
        employeesListener?.remove()
        transactionsListener?.remove()
        tagsListener?.remove()
        statusesListener?.remove()
        isSyncing = false
    }
    
    // MARK: - Utilities
    
    private func handleSnapshot(_ snapshot: QuerySnapshot?, error: Error?, processor: ([String: Any]) -> Void) {
        if let error = error {
            self.lastSyncError = "Sync error: \(error.localizedDescription)"
            self.isSyncing = false
            return
        }
        
        guard let snapshot = snapshot else { return }
        
        for document in snapshot.documents {
            processor(document.data())
        }
        self.isSyncing = false
    }
    
    /// Purges the local SwiftData cache to prevent data bleeding when switching active multi-tenant workspaces.
    private func clearLocalDatabase(context: ModelContext) {
        do {
            try context.delete(model: StoreItem.self)
            try context.delete(model: Customer.self)
            try context.delete(model: Employee.self)
            try context.delete(model: Transaction.self)
            try context.delete(model: ItemTag.self)
            try context.delete(model: CustomerStatus.self)
            
            try context.delete(model: LineItem.self)
            try context.delete(model: PaymentSplit.self)
            
            try context.save()
        } catch {
            self.lastSyncError = "Local cache wipe failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Incoming Data Processors (Cloud -> Local)
    
    private func processIncomingInventory(data: [String: Any], context: ModelContext) {
        guard let name = data["name"] as? String,
              let idString = data["id"] as? String,
              let id = UUID(uuidString: idString) else { return }
        
        let stockCount = data["stockCount"] as? Int ?? 0
        let salesPrice = data["salesPrice"] as? Double ?? 0.0
        let isActive = data["isActive"] as? Bool ?? true
        
        let descriptor = FetchDescriptor<StoreItem>(predicate: #Predicate { $0.id == id })
        
        do {
            if let existingItem = try context.fetch(descriptor).first {
                existingItem.name = name
                existingItem.stockCount = stockCount
                existingItem.salesPrice = salesPrice
                existingItem.isActive = isActive
                existingItem.updatedAt = Date()
            } else {
                let newItem = StoreItem(
                    id: id,
                    storeId: data["storeId"] as? String,
                    name: name,
                    stockCount: stockCount,
                    salesPrice: salesPrice,
                    isActive: isActive
                )
                context.insert(newItem)
            }
            if context.hasChanges { try context.save() }
        } catch {
            self.lastSyncError = "Inventory sync failed: \(error.localizedDescription)"
        }
    }
    
    private func processIncomingCustomer(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let firstName = data["firstName"] as? String,
              let lastName = data["lastName"] as? String else { return }
        
        let descriptor = FetchDescriptor<Customer>(predicate: #Predicate { $0.id == id })
        
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.firstName = firstName
                existing.lastName = lastName
                existing.email = data["email"] as? String ?? ""
                existing.phone = data["phone"] as? String ?? ""
                existing.isActive = data["isActive"] as? Bool ?? true
                existing.updatedAt = Date()
            } else {
                let newCustomer = Customer(
                    id: id,
                    storeId: data["storeId"] as? String,
                    firstName: firstName,
                    lastName: lastName,
                    email: data["email"] as? String ?? "",
                    phone: data["phone"] as? String ?? ""
                )
                newCustomer.isActive = data["isActive"] as? Bool ?? true
                context.insert(newCustomer)
            }
            if context.hasChanges { try context.save() }
        } catch {
            self.lastSyncError = "Customer sync failed: \(error.localizedDescription)"
        }
    }
    
    private func processIncomingEmployee(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String else { return }
        
        let descriptor = FetchDescriptor<Employee>(predicate: #Predicate { $0.id == id })
        
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
                existing.isActive = data["isActive"] as? Bool ?? true
            } else {
                let newEmployee = Employee(
                    id: id,
                    storeId: data["storeId"] as? String,
                    name: name,
                    isActive: data["isActive"] as? Bool ?? true
                )
                context.insert(newEmployee)
            }
            if context.hasChanges { try context.save() }
        } catch {
            self.lastSyncError = "Employee sync failed: \(error.localizedDescription)"
        }
    }
    
    private func processIncomingTransaction(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString) else { return }
        
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        do {
            if try context.fetch(descriptor).first != nil { return }
            
            let totalAmount = data["totalAmount"] as? Double ?? 0.0
            let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
            
            let newTx = Transaction(
                id: id,
                storeId: data["storeId"] as? String,
                totalAmount: totalAmount,
                employeeName: data["employeeName"] as? String,
                employeeId: data["employeeId"] as? String,
                customer: nil,
                buyerEmployeeName: data["buyerEmployeeName"] as? String,
                buyerEmployeeId: data["buyerEmployeeId"] as? String
            )
            newTx.date = date
            context.insert(newTx)
            
            if let custIdStr = data["customerId"] as? String, let custId = UUID(uuidString: custIdStr) {
                let custDesc = FetchDescriptor<Customer>(predicate: #Predicate { $0.id == custId })
                if let customer = try context.fetch(custDesc).first {
                    newTx.customer = customer
                }
            }
            
            if let lineItemsData = data["lineItems"] as? [[String: Any]] {
                let newItems: [LineItem] = lineItemsData.compactMap { liData in
                    guard let liIdStr = liData["id"] as? String, let liId = UUID(uuidString: liIdStr),
                          let itemName = liData["itemName"] as? String, let itemID = liData["itemID"] as? String,
                          let qty = liData["quantity"] as? Int, let price = liData["pricePerUnit"] as? Double else { return nil }
                    
                    let newLineItem = LineItem(id: liId, itemName: itemName, itemID: itemID, quantity: qty, pricePerUnit: price)
                    context.insert(newLineItem)
                    newLineItem.transaction = newTx
                    return newLineItem
                }
                newTx.lineItems = newItems
            }
            
            if let paymentsData = data["payments"] as? [[String: Any]] {
                let newPayments: [PaymentSplit] = paymentsData.compactMap { pData in
                    guard let pIdStr = pData["id"] as? String, let pId = UUID(uuidString: pIdStr),
                          let method = pData["method"] as? String, let amount = pData["amount"] as? Double else { return nil }
                    
                    let newSplit = PaymentSplit(id: pId, method: method, amount: amount)
                    context.insert(newSplit)
                    newSplit.transaction = newTx
                    return newSplit
                }
                newTx.payments = newPayments
            }
            
            if context.hasChanges { try context.save() }
            
        } catch {
            self.lastSyncError = "Transaction sync failed: \(error.localizedDescription)"
        }
    }
    
    private func processIncomingTag(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString),
              let name = data["name"] as? String else { return }
        
        let descriptor = FetchDescriptor<ItemTag>(predicate: #Predicate { $0.id == id })
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
            } else {
                let newTag = ItemTag(id: id, storeId: data["storeId"] as? String, name: name)
                context.insert(newTag)
            }
            if context.hasChanges { try context.save() }
        } catch {
            self.lastSyncError = "Tag sync failed: \(error.localizedDescription)"
        }
    }
    
    private func processIncomingCustomerStatus(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString),
              let name = data["name"] as? String else { return }
        
        let descriptor = FetchDescriptor<CustomerStatus>(predicate: #Predicate { $0.id == id })
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
            } else {
                let newStatus = CustomerStatus(id: id, name: name, storeId: data["storeId"] as? String)
                context.insert(newStatus)
            }
            if context.hasChanges { try context.save() }
        } catch {
            self.lastSyncError = "Customer status sync failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Outgoing Data Pushers (Local -> Cloud)
    
    public func pushItemToCloud(_ item: StoreItem) async {
        guard let storeId = item.storeId else { return }
        let data: [String: Any] = [
            "id": item.id.uuidString,
            "storeId": storeId,
            "name": item.name,
            "desc": item.desc ?? "",
            "stockCount": item.stockCount,
            "salesPrice": item.salesPrice,
            "itemCost": item.itemCost,
            "barcode": item.barcode ?? "",
            "isActive": item.isActive
        ]
        try? await db.collection("inventory").document(item.id.uuidString).setData(data, merge: true)
    }
    
    public func pushTransactionToCloud(_ transaction: Transaction) async {
        guard let storeId = transaction.storeId else { return }
        
        let lineItemsData = (transaction.lineItems ?? []).map { li in
            ["id": li.id.uuidString, "itemName": li.itemName, "itemID": li.itemID, "quantity": li.quantity, "pricePerUnit": li.pricePerUnit]
        }
        
        let paymentsData = (transaction.payments ?? []).map { p in
            ["id": p.id.uuidString, "method": p.method, "amount": p.amount]
        }
        
        let data: [String: Any] = [
            "id": transaction.id.uuidString,
            "storeId": storeId,
            "date": transaction.date,
            "totalAmount": transaction.totalAmount,
            "employeeName": transaction.employeeName ?? "",
            "employeeId": transaction.employeeId ?? "",
            "customerId": transaction.customer?.id.uuidString ?? "",
            "buyerEmployeeName": transaction.buyerEmployeeName ?? "",
            "buyerEmployeeId": transaction.buyerEmployeeId ?? "",
            "lineItems": lineItemsData,
            "payments": paymentsData
        ]
        try? await db.collection("transactions").document(transaction.id.uuidString).setData(data)
    }
    
    public func pushCustomerToCloud(_ customer: Customer) async {
        guard let storeId = customer.storeId else { return }
        let data: [String: Any] = [
            "id": customer.id.uuidString,
            "storeId": storeId,
            "firstName": customer.firstName,
            "lastName": customer.lastName,
            "email": customer.email,
            "phone": customer.phone,
            "notes": customer.notes,
            "isActive": customer.isActive,
            "updatedAt": customer.updatedAt
        ]
        try? await db.collection("customers").document(customer.id.uuidString).setData(data, merge: true)
    }
    
    public func pushEmployeeToCloud(_ employee: Employee) async {
        guard let storeId = employee.storeId else { return }
        let data: [String: Any] = [
            "id": employee.id.uuidString,
            "storeId": storeId,
            "name": employee.name,
            "isActive": employee.isActive
        ]
        try? await db.collection("employees").document(employee.id.uuidString).setData(data, merge: true)
    }
    
    // MARK: - Transaction & Customer Deletions
    
    public func deleteTransactionFromCloud(_ transactionId: String) async {
        try? await db.collection("transactions").document(transactionId).delete()
    }
    
    public func deleteCustomerFromCloud(_ customerId: String) async {
        try? await db.collection("customers").document(customerId).delete()
    }
    
    // MARK: - Tag & Status Management
    
    public func pushItemTagToCloud(_ tag: ItemTag) async {
        guard let storeId = tag.storeId else { return }
        let data: [String: Any] = [
            "id": tag.id.uuidString,
            "storeId": storeId,
            "name": tag.name
        ]
        try? await db.collection("tags").document(tag.id.uuidString).setData(data, merge: true)
    }
    
    public func deleteItemTagFromCloud(_ tagId: String) async {
        try? await db.collection("tags").document(tagId).delete()
    }
    
    public func pushCustomerStatusToCloud(_ status: CustomerStatus) async {
        guard let storeId = status.storeId else { return }
        let data: [String: Any] = [
            "id": status.id.uuidString,
            "storeId": storeId,
            "name": status.name
        ]
        try? await db.collection("customerStatuses").document(status.id.uuidString).setData(data, merge: true)
    }
    
    public func deleteCustomerStatusFromCloud(_ statusId: String) async {
        try? await db.collection("customerStatuses").document(statusId).delete()
    }
    
    // MARK: - Store Profile Syncing
    
    public func pushStoreProfileToCloud(storeId: String, payload: [String: Any]) async {
        try? await db.collection("stores").document(storeId).setData(payload, merge: true)
    }
}
