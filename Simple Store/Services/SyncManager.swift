//
//  SyncManager.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import Foundation
import SwiftData
import FirebaseFirestore

@Observable
@MainActor
final class SyncManager {
    private var db: Firestore { Firestore.firestore() }
    
    // Listeners
    private var inventoryListener: ListenerRegistration?
    private var customersListener: ListenerRegistration?
    private var employeesListener: ListenerRegistration?
    private var transactionsListener: ListenerRegistration?
    private var tagsListener: ListenerRegistration?
    private var statusesListener: ListenerRegistration?
    
    // MARK: - Multi-Tenant State
    private var currentTrackedStoreId: String?
    
    var isSyncing: Bool = false
    var lastSyncError: String?
    
    // MARK: - App Lifecycle & Listeners
    
    func startListening(storeId: String, context: ModelContext) {
        // NEW: Check if the workspace changed. If so, wipe the local cache to prevent data bleeding.
        if currentTrackedStoreId != storeId {
            clearLocalDatabase(context: context)
            currentTrackedStoreId = storeId
        }
        
        stopAllListeners()
        isSyncing = true
        
        // 1. Listen to Inventory
        inventoryListener = db.collection("inventory")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingInventory(data: data, context: context)
                }
            }
            
        // 2. Listen to Customers
        customersListener = db.collection("customers")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingCustomer(data: data, context: context)
                }
            }
            
        // 3. Listen to Employees
        employeesListener = db.collection("employees")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingEmployee(data: data, context: context)
                }
            }
            
        // 4. Listen to Transactions
        transactionsListener = db.collection("transactions")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingTransaction(data: data, context: context)
                }
            }
            
        // 5. Listen to Item Tags
        tagsListener = db.collection("tags")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingTag(data: data, context: context)
                }
            }
            
        // 6. Listen to Customer Statuses
        statusesListener = db.collection("customerStatuses")
            .whereField("storeId", isEqualTo: storeId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleSnapshot(snapshot, error: error) { data in
                    self?.processIncomingCustomerStatus(data: data, context: context)
                }
            }
    }
    
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
    
    func stopAllListeners() {
        inventoryListener?.remove()
        customersListener?.remove()
        employeesListener?.remove()
        transactionsListener?.remove()
        tagsListener?.remove()
        statusesListener?.remove()
        isSyncing = false
    }
    
    // MARK: - Workspace Memory Wipe
    
    private func clearLocalDatabase(context: ModelContext) {
        do {
            // SwiftData bulk deletion removes all cached offline data for these models
            try context.delete(model: StoreItem.self)
            try context.delete(model: Customer.self)
            try context.delete(model: Employee.self)
            try context.delete(model: Transaction.self)
            try context.delete(model: ItemTag.self)
            try context.delete(model: CustomerStatus.self)
            
            // Sub-models for transactions
            try context.delete(model: LineItem.self)
            try context.delete(model: PaymentSplit.self)
            
            try context.save()
            print("Successfully wiped local cache for workspace transition.")
        } catch {
            print("Failed to clear local database: \(error.localizedDescription)")
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
        } catch { print("Failed to process inventory: \(error)") }
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
        } catch { print("Failed to process customer: \(error)") }
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
        } catch { print("Failed to process employee: \(error)") }
    }
    
    private func processIncomingTransaction(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString) else { return }
        
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        do {
            if let _ = try context.fetch(descriptor).first { return }
            
            let totalAmount = data["totalAmount"] as? Double ?? 0.0
            let timestamp = data["date"] as? Timestamp
            let date = timestamp?.dateValue() ?? Date()
            
            let newTx = Transaction(
                id: id,
                storeId: data["storeId"] as? String,
                totalAmount: totalAmount,
                employeeName: data["employeeName"] as? String,
                employeeId: data["employeeId"] as? String,
                customer: nil, // Reconstructed below
                buyerEmployeeName: data["buyerEmployeeName"] as? String,
                buyerEmployeeId: data["buyerEmployeeId"] as? String
            )
            newTx.date = date
            context.insert(newTx)
            
            // Reconstruct relationships
            if let custIdStr = data["customerId"] as? String, let custId = UUID(uuidString: custIdStr) {
                let custDesc = FetchDescriptor<Customer>(predicate: #Predicate { $0.id == custId })
                if let customer = try context.fetch(custDesc).first {
                    newTx.customer = customer
                }
            }
            
            if let lineItemsData = data["lineItems"] as? [[String: Any]] {
                var newItems: [LineItem] = []
                for liData in lineItemsData {
                    if let liIdStr = liData["id"] as? String, let liId = UUID(uuidString: liIdStr),
                       let itemName = liData["itemName"] as? String, let itemID = liData["itemID"] as? String,
                       let qty = liData["quantity"] as? Int, let price = liData["pricePerUnit"] as? Double {
                        
                        let newLineItem = LineItem(id: liId, itemName: itemName, itemID: itemID, quantity: qty, pricePerUnit: price)
                        context.insert(newLineItem)
                        newLineItem.transaction = newTx
                        newItems.append(newLineItem)
                    }
                }
                newTx.lineItems = newItems
            }
            
            if let paymentsData = data["payments"] as? [[String: Any]] {
                var newPayments: [PaymentSplit] = []
                for pData in paymentsData {
                    if let pIdStr = pData["id"] as? String, let pId = UUID(uuidString: pIdStr),
                       let method = pData["method"] as? String, let amount = pData["amount"] as? Double {
                        
                        let newSplit = PaymentSplit(id: pId, method: method, amount: amount)
                        context.insert(newSplit)
                        newSplit.transaction = newTx
                        newPayments.append(newSplit)
                    }
                }
                newTx.payments = newPayments
            }
            
            if context.hasChanges { try context.save() }
            
        } catch { print("Failed to process transaction: \(error)") }
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
        } catch { print("Failed to process tag: \(error)") }
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
        } catch { print("Failed to process customer status: \(error)") }
    }
    
    // MARK: - Offline Queue & Network Interceptor
        
        private func attemptCloudSync(storeId: String, collection: String, documentId: String, payload: [String: Any]?, operation: String, context: ModelContext, isOnline: Bool) async {
            if isOnline {
                do {
                    if operation == "delete" {
                        try await db.collection(collection).document(documentId).delete()
                    } else {
                        try await db.collection(collection).document(documentId).setData(payload ?? [:], merge: operation == "merge")
                    }
                } catch {
                    queueOfflineTask(storeId: storeId, collection: collection, documentId: documentId, payload: payload, operation: operation, context: context)
                }
            } else {
                queueOfflineTask(storeId: storeId, collection: collection, documentId: documentId, payload: payload, operation: operation, context: context)
            }
        }
        
        private func queueOfflineTask(storeId: String, collection: String, documentId: String, payload: [String: Any]?, operation: String, context: ModelContext) {
            let task = OfflineSyncTask(
                storeId: storeId,
                collection: collection,
                documentId: documentId,
                payload: payload,
                operation: operation
            )
            context.insert(task)
            try? context.save()
            print("Queued offline task for \(collection)/\(documentId)")
        }
        
        func processOfflineQueue(context: ModelContext) async {
            let descriptor = FetchDescriptor<OfflineSyncTask>(sortBy: [SortDescriptor(\.timestamp)])
            guard let tasks = try? context.fetch(descriptor), !tasks.isEmpty else { return }
            
            print("Processing \(tasks.count) offline tasks...")
            
            for task in tasks {
                do {
                    if task.operation == "delete" {
                        try await db.collection(task.collection).document(task.documentId).delete()
                    } else {
                        if let payload = task.payload {
                            try await db.collection(task.collection).document(task.documentId).setData(payload, merge: true)
                        }
                    }
                    // If successful, safely remove it from the local SwiftData queue
                    context.delete(task)
                    try? context.save()
                } catch {
                    print("Failed to sync task \(task.id): \(error.localizedDescription)")
                    break // Stop processing on the first failure to maintain chronological order
                }
            }
        }
        
        // MARK: - Outgoing Data Pushers (Local -> Cloud)
        
        func pushItemToCloud(_ item: StoreItem, context: ModelContext, isOnline: Bool) async {
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
            await attemptCloudSync(storeId: storeId, collection: "inventory", documentId: item.id.uuidString, payload: data, operation: "merge", context: context, isOnline: isOnline)
        }
        
        func pushTransactionToCloud(_ transaction: Transaction, context: ModelContext, isOnline: Bool) async {
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
            await attemptCloudSync(storeId: storeId, collection: "transactions", documentId: transaction.id.uuidString, payload: data, operation: "set", context: context, isOnline: isOnline)
        }
        
        func pushCustomerToCloud(_ customer: Customer, context: ModelContext, isOnline: Bool) async {
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
            await attemptCloudSync(storeId: storeId, collection: "customers", documentId: customer.id.uuidString, payload: data, operation: "merge", context: context, isOnline: isOnline)
        }
        
        func pushEmployeeToCloud(_ employee: Employee, context: ModelContext, isOnline: Bool) async {
            guard let storeId = employee.storeId else { return }
            let data: [String: Any] = [
                "id": employee.id.uuidString,
                "storeId": storeId,
                "name": employee.name,
                "isActive": employee.isActive
            ]
            await attemptCloudSync(storeId: storeId, collection: "employees", documentId: employee.id.uuidString, payload: data, operation: "merge", context: context, isOnline: isOnline)
        }
        
        // MARK: - Deletions
        
        func deleteTransactionFromCloud(_ transactionId: String, storeId: String, context: ModelContext, isOnline: Bool) async {
            await attemptCloudSync(storeId: storeId, collection: "transactions", documentId: transactionId, payload: nil, operation: "delete", context: context, isOnline: isOnline)
        }
        
        func deleteCustomerFromCloud(_ customerId: String, storeId: String, context: ModelContext, isOnline: Bool) async {
            await attemptCloudSync(storeId: storeId, collection: "customers", documentId: customerId, payload: nil, operation: "delete", context: context, isOnline: isOnline)
        }
        
        // MARK: - Tag & Status Management
        
        func pushItemTagToCloud(_ tag: ItemTag, context: ModelContext, isOnline: Bool) async {
            guard let storeId = tag.storeId else { return }
            let data: [String: Any] = [
                "id": tag.id.uuidString,
                "storeId": storeId,
                "name": tag.name
            ]
            await attemptCloudSync(storeId: storeId, collection: "tags", documentId: tag.id.uuidString, payload: data, operation: "merge", context: context, isOnline: isOnline)
        }
        
        func deleteItemTagFromCloud(_ tagId: String, storeId: String, context: ModelContext, isOnline: Bool) async {
            await attemptCloudSync(storeId: storeId, collection: "tags", documentId: tagId, payload: nil, operation: "delete", context: context, isOnline: isOnline)
        }
        
        func pushCustomerStatusToCloud(_ status: CustomerStatus, context: ModelContext, isOnline: Bool) async {
            guard let storeId = status.storeId else { return }
            let data: [String: Any] = [
                "id": status.id.uuidString,
                "storeId": storeId,
                "name": status.name
            ]
            await attemptCloudSync(storeId: storeId, collection: "customerStatuses", documentId: status.id.uuidString, payload: data, operation: "merge", context: context, isOnline: isOnline)
        }
        
        func deleteCustomerStatusFromCloud(_ statusId: String, storeId: String, context: ModelContext, isOnline: Bool) async {
            await attemptCloudSync(storeId: storeId, collection: "customerStatuses", documentId: statusId, payload: nil, operation: "delete", context: context, isOnline: isOnline)
        }
        
        // MARK: - Store Profile Syncing
        
        func pushStoreProfileToCloud(storeId: String, payload: [String: Any], context: ModelContext, isOnline: Bool) async {
            await attemptCloudSync(storeId: storeId, collection: "stores", documentId: storeId, payload: payload, operation: "merge", context: context, isOnline: isOnline)
        }
    }
