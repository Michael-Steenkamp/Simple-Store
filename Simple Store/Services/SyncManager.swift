//
//  SyncManager.swift
//  Simple Store
//

import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Manages real-time data synchronization between the local offline-first SwiftData container and the remote Firebase Firestore database.
/// Acts as the central `@MainActor` orchestrator for multi-tenant data ingestion, exfiltration, and telemetry aggregation.
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
    private var activitiesListener: ListenerRegistration?
    
    // MARK: - State Properties
    
    private var currentTrackedStoreId: String?
    public var isSyncing: Bool = false
    public var lastSyncError: String?
    public var currentUserRole: String = "customer"
    
    private var isInventoryFirstSync = true
    private var isCustomersFirstSync = true
    private var isEmployeesFirstSync = true
    private var isTransactionsFirstSync = true
    private var isTagsFirstSync = true
    private var isStatusesFirstSync = true
    private var isActivitiesFirstSync = true
    
    // MARK: - Lifecycle Management
    
    /// Initializes data synchronization pipelines. Contextual tenant role is required to enforce strict local data isolation policies.
    public func startListening(storeId: String, role: String, context: ModelContext) {
        if let current = currentTrackedStoreId, current != storeId {
            clearLocalDatabase(context: context)
        }
        
        currentTrackedStoreId = storeId
        currentUserRole = role
        
        stopAllListeners()
        isSyncing = true
        
        isInventoryFirstSync = true
        isCustomersFirstSync = true
        isEmployeesFirstSync = true
        isTransactionsFirstSync = true
        isTagsFirstSync = true
        isStatusesFirstSync = true
        isActivitiesFirstSync = true
        
        inventoryListener = db.collection("inventory").whereField("storeId", isEqualTo: storeId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { self.lastSyncError = "Sync error: \(error.localizedDescription)"; return }
            guard let snapshot = snapshot else { return }
            
            if self.isInventoryFirstSync {
                self.reconcileInventory(snapshot: snapshot, context: context)
                self.isInventoryFirstSync = false
            }
            
            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified: self.processIncomingInventory(data: change.document.data(), context: context)
                case .removed: self.removeLocalInventory(id: change.document.documentID, context: context)
                }
            }
        }
        
        customersListener = db.collection("customers").whereField("storeId", isEqualTo: storeId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { self.lastSyncError = "Sync error: \(error.localizedDescription)"; return }
            guard let snapshot = snapshot else { return }
            
            if self.isCustomersFirstSync {
                self.reconcileCustomers(snapshot: snapshot, context: context)
                self.isCustomersFirstSync = false
            }
            
            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified: self.processIncomingCustomer(data: change.document.data(), context: context)
                case .removed: self.removeLocalCustomer(id: change.document.documentID, context: context)
                }
            }
        }
        
        employeesListener = db.collection("employees").whereField("storeId", isEqualTo: storeId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { self.lastSyncError = "Sync error: \(error.localizedDescription)"; return }
            guard let snapshot = snapshot else { return }
            
            if self.isEmployeesFirstSync {
                self.reconcileEmployees(snapshot: snapshot, context: context)
                self.isEmployeesFirstSync = false
            }
            
            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified: self.processIncomingEmployee(data: change.document.data(), context: context)
                case .removed: self.removeLocalEmployee(id: change.document.documentID, context: context)
                }
            }
        }
        
        transactionsListener = db.collection("transactions").whereField("storeId", isEqualTo: storeId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { self.lastSyncError = "Sync error: \(error.localizedDescription)"; return }
            guard let snapshot = snapshot else { return }
            
            if self.isTransactionsFirstSync {
                self.reconcileTransactions(snapshot: snapshot, context: context)
                self.isTransactionsFirstSync = false
            }
            
            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified: self.processIncomingTransaction(data: change.document.data(), context: context)
                case .removed: self.removeLocalTransaction(id: change.document.documentID, context: context)
                }
            }
        }
        
        tagsListener = db.collection("tags").whereField("storeId", isEqualTo: storeId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { self.lastSyncError = "Sync error: \(error.localizedDescription)"; return }
            guard let snapshot = snapshot else { return }
            
            if self.isTagsFirstSync {
                self.reconcileTags(snapshot: snapshot, context: context)
                self.isTagsFirstSync = false
            }
            
            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified: self.processIncomingTag(data: change.document.data(), context: context)
                case .removed: self.removeLocalTag(id: change.document.documentID, context: context)
                }
            }
        }
        
        statusesListener = db.collection("customerStatuses").whereField("storeId", isEqualTo: storeId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { self.lastSyncError = "Sync error: \(error.localizedDescription)"; return }
            guard let snapshot = snapshot else { return }
            
            if self.isStatusesFirstSync {
                self.reconcileCustomerStatuses(snapshot: snapshot, context: context)
                self.isStatusesFirstSync = false
            }
            
            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified: self.processIncomingCustomerStatus(data: change.document.data(), context: context)
                case .removed: self.removeLocalCustomerStatus(id: change.document.documentID, context: context)
                }
            }
        }
        
        activitiesListener = db.collection("activities").whereField("storeId", isEqualTo: storeId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let snapshot = snapshot else { return }
            
            if self.isActivitiesFirstSync {
                self.reconcileActivities(snapshot: snapshot, context: context)
                self.isActivitiesFirstSync = false
            }
            
            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified: self.processIncomingActivity(data: change.document.data(), context: context)
                case .removed: break
                }
            }
        }
        
        isSyncing = false
    }
    
    public func stopAllListeners() {
        inventoryListener?.remove()
        customersListener?.remove()
        employeesListener?.remove()
        transactionsListener?.remove()
        tagsListener?.remove()
        statusesListener?.remove()
        activitiesListener?.remove()
        isSyncing = false
    }
    
    // MARK: - Ghost Data Reconciliation
    
    private func reconcileInventory(snapshot: QuerySnapshot, context: ModelContext) {
        let remoteIds = Set(snapshot.documents.map { $0.documentID })
        let items = try? context.fetch(FetchDescriptor<StoreItem>())
        items?.forEach { if !remoteIds.contains($0.id.uuidString) { context.delete($0) } }
        try? context.save()
    }
    
    private func reconcileCustomers(snapshot: QuerySnapshot, context: ModelContext) {
        let remoteIds = Set(snapshot.documents.map { $0.documentID })
        let items = try? context.fetch(FetchDescriptor<Customer>())
        items?.forEach { if !remoteIds.contains($0.id.uuidString) { context.delete($0) } }
        try? context.save()
    }
    
    private func reconcileEmployees(snapshot: QuerySnapshot, context: ModelContext) {
        let remoteIds = Set(snapshot.documents.map { $0.documentID })
        let items = try? context.fetch(FetchDescriptor<Employee>())
        items?.forEach { if !remoteIds.contains($0.id.uuidString) { context.delete($0) } }
        try? context.save()
    }
    
    private func reconcileTransactions(snapshot: QuerySnapshot, context: ModelContext) {
        let remoteIds = Set(snapshot.documents.map { $0.documentID })
        let items = try? context.fetch(FetchDescriptor<Transaction>())
        items?.forEach { if !remoteIds.contains($0.id.uuidString) { context.delete($0) } }
        try? context.save()
    }
    
    private func reconcileTags(snapshot: QuerySnapshot, context: ModelContext) {
        let remoteIds = Set(snapshot.documents.map { $0.documentID })
        let items = try? context.fetch(FetchDescriptor<ItemTag>())
        items?.forEach { if !remoteIds.contains($0.id.uuidString) { context.delete($0) } }
        try? context.save()
    }
    
    private func reconcileCustomerStatuses(snapshot: QuerySnapshot, context: ModelContext) {
        let remoteIds = Set(snapshot.documents.map { $0.documentID })
        let items = try? context.fetch(FetchDescriptor<CustomerStatus>())
        items?.forEach { if !remoteIds.contains($0.id.uuidString) { context.delete($0) } }
        try? context.save()
    }
    
    private func reconcileActivities(snapshot: QuerySnapshot, context: ModelContext) {
        let remoteIds = Set(snapshot.documents.map { $0.documentID })
        let items = try? context.fetch(FetchDescriptor<ActivityLog>())
        items?.forEach { if !remoteIds.contains($0.id.uuidString) { context.delete($0) } }
        try? context.save()
    }
    
    // MARK: - Incremental Data Deletion
    
    private func removeLocalInventory(id: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<StoreItem>(predicate: #Predicate { $0.id == uuid })
        if let item = try? context.fetch(descriptor).first { context.delete(item); try? context.save() }
    }
    
    private func removeLocalCustomer(id: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<Customer>(predicate: #Predicate { $0.id == uuid })
        if let item = try? context.fetch(descriptor).first { context.delete(item); try? context.save() }
    }
    
    private func removeLocalEmployee(id: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<Employee>(predicate: #Predicate { $0.id == uuid })
        if let item = try? context.fetch(descriptor).first { context.delete(item); try? context.save() }
    }
    
    private func removeLocalTransaction(id: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == uuid })
        if let item = try? context.fetch(descriptor).first { context.delete(item); try? context.save() }
    }
    
    private func removeLocalTag(id: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<ItemTag>(predicate: #Predicate { $0.id == uuid })
        if let item = try? context.fetch(descriptor).first { context.delete(item); try? context.save() }
    }
    
    private func removeLocalCustomerStatus(id: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        let descriptor = FetchDescriptor<CustomerStatus>(predicate: #Predicate { $0.id == uuid })
        if let item = try? context.fetch(descriptor).first { context.delete(item); try? context.save() }
    }
    
    public func clearLocalDatabase(context: ModelContext) {
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
    
    // MARK: - Incoming Data Processors
    
    private func processIncomingInventory(data: [String: Any], context: ModelContext) {
        guard let name = data["name"] as? String,
              let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let storeId = data["storeId"] as? String else { return }
        
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
                
                // Safely maps the updated URL down to the cache without erroneously un-setting a valid URL state
                if let fetchedURL = data["imageURL"] as? String, !fetchedURL.isEmpty {
                    existingItem.imageURL = fetchedURL
                }
            } else {
                let fetchedURL = data["imageURL"] as? String
                let newItem = StoreItem(
                    id: id,
                    storeId: storeId,
                    name: name,
                    stockCount: stockCount,
                    salesPrice: salesPrice,
                    isActive: isActive,
                    imageURL: fetchedURL?.isEmpty == false ? fetchedURL : nil
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
              let lastName = data["lastName"] as? String,
              let storeId = data["storeId"] as? String else { return }
        
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
                    storeId: storeId,
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
              let name = data["name"] as? String,
              let storeId = data["storeId"] as? String else { return }
        
        let descriptor = FetchDescriptor<Employee>(predicate: #Predicate { $0.id == id })
        
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
                existing.email = data["email"] as? String
                existing.phone = data["phone"] as? String
                existing.isActive = data["isActive"] as? Bool ?? true
            } else {
                let newEmployee = Employee(
                    id: id,
                    storeId: storeId,
                    name: name,
                    email: data["email"] as? String,
                    phone: data["phone"] as? String,
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
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString),
              let storeId = data["storeId"] as? String else { return }
        
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        do {
            if try context.fetch(descriptor).first != nil { return }
            
            let totalAmount = data["totalAmount"] as? Double ?? 0.0
            let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
            
            let newTx = Transaction(
                id: id,
                storeId: storeId,
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
              let name = data["name"] as? String,
              let storeId = data["storeId"] as? String else { return }
        
        let descriptor = FetchDescriptor<ItemTag>(predicate: #Predicate { $0.id == id })
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
            } else {
                let newTag = ItemTag(id: id, storeId: storeId, name: name)
                context.insert(newTag)
            }
            if context.hasChanges { try context.save() }
        } catch {
            self.lastSyncError = "Tag sync failed: \(error.localizedDescription)"
        }
    }
    
    private func processIncomingCustomerStatus(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let storeId = data["storeId"] as? String else { return }
        
        let descriptor = FetchDescriptor<CustomerStatus>(predicate: #Predicate { $0.id == id })
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
            } else {
                let newStatus = CustomerStatus(id: id, name: name, storeId: storeId)
                context.insert(newStatus)
            }
            if context.hasChanges { try context.save() }
        } catch {
            self.lastSyncError = "Customer status sync failed: \(error.localizedDescription)"
        }
    }
    
    /// Parses targeted telemetry payloads with strict role isolation and cloud-synchronized state matrices to mitigate data duplication.
    private func processIncomingActivity(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString),
              let storeId = data["storeId"] as? String,
              let title = data["title"] as? String,
              let category = data["category"] as? String else { return }
        
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let count = data["count"] as? Int ?? 1
        let groupingKey = data["groupingKey"] as? String
        
        let targetRoles = data["targetRoles"] as? [String] ?? []
        let targetUserIds = data["targetUserIds"] as? [String] ?? []
        let readBy = data["readBy"] as? [String] ?? []
        let deletedBy = data["deletedBy"] as? [String] ?? []
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Exfiltration Layer: Evict log safely from local context if the user has opted to soft-delete it previously.
        if deletedBy.contains(currentUid) {
            let descriptor = FetchDescriptor<ActivityLog>(predicate: #Predicate { $0.id == id })
            if let existing = try? context.fetch(descriptor).first {
                context.delete(existing)
                try? context.save()
            }
            return
        }
        
        // Tenant Isolation: Ensuring logs strictly reflect the scope of the logged-in user.
        let matchesId = targetUserIds.contains(currentUid) || targetUserIds.contains("all")
        let hasValidRole = targetRoles.contains(self.currentUserRole)
        let hasValidTarget = matchesId || hasValidRole
        
        guard hasValidTarget else {
            // Garbage collect locally cached logs if workspace permissions are revoked or out of bounds.
            let descriptor = FetchDescriptor<ActivityLog>(predicate: #Predicate { $0.id == id })
            if let existing = try? context.fetch(descriptor).first {
                context.delete(existing)
                try? context.save()
            }
            return
        }
        
        let displayTitle = count > 1 ? "\(title) x\(count)" : title
        let isReadLocal = readBy.contains(currentUid)
        
        do {
            if let key = groupingKey {
                let descriptor = FetchDescriptor<ActivityLog>(predicate: #Predicate { $0.storeId == storeId })
                if let existingLog = try context.fetch(descriptor).first(where: { $0.groupingKey == key }) {
                    if existingLog.count != count || existingLog.isRead != isReadLocal {
                        existingLog.count = count
                        existingLog.title = displayTitle
                        existingLog.timestamp = timestamp
                        existingLog.isRead = isReadLocal // Reconcile dynamic aggregate read state via Cloud truth
                        if context.hasChanges { try context.save() }
                    }
                    return
                }
            }
            
            let descriptor = FetchDescriptor<ActivityLog>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.title = displayTitle
                existing.count = count
                existing.isRead = isReadLocal
                if context.hasChanges { try context.save() }
            } else {
                let newLog = ActivityLog(
                    id: id,
                    storeId: storeId,
                    timestamp: timestamp,
                    title: displayTitle,
                    category: category,
                    isRead: isReadLocal,
                    count: count,
                    groupingKey: groupingKey,
                    targetRoles: targetRoles,
                    targetUserIds: targetUserIds
                )
                
                context.insert(newLog)
                if context.hasChanges { try context.save() }
            }
        } catch {
            self.lastSyncError = "Activity Log sync failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Outgoing Data Pushers
    
    public func pushItemToCloud(_ item: StoreItem) {
        var data: [String: Any] = [
            "id": item.id.uuidString,
            "storeId": item.storeId,
            "name": item.name,
            "desc": item.desc ?? "",
            "stockCount": item.stockCount,
            "salesPrice": item.salesPrice,
            "itemCost": item.itemCost,
            "barcode": item.barcode ?? "",
            "isActive": item.isActive
        ]
        
        if let url = item.imageURL, url != "OFFLINE_CACHE" {
            data["imageURL"] = url
        }
        
        db.collection("inventory").document(item.id.uuidString).setData(data, merge: true)
    }
    
    public func deleteItemFromCloud(_ itemId: String) async {
        try? await db.collection("inventory").document(itemId).delete()
    }
    
    public func pushTransactionToCloud(_ transaction: Transaction) {
        let lineItemsData = (transaction.lineItems ?? []).map { li in
            ["id": li.id.uuidString, "itemName": li.itemName, "itemID": li.itemID, "quantity": li.quantity, "pricePerUnit": li.pricePerUnit]
        }
        
        let paymentsData = (transaction.payments ?? []).map { p in
            ["id": p.id.uuidString, "method": p.method, "amount": p.amount]
        }
        
        let data: [String: Any] = [
            "id": transaction.id.uuidString,
            "storeId": transaction.storeId,
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
        db.collection("transactions").document(transaction.id.uuidString).setData(data)
    }
    
    public func pushCustomerToCloud(_ customer: Customer) {
        let data: [String: Any] = [
            "id": customer.id.uuidString,
            "storeId": customer.storeId,
            "firstName": customer.firstName,
            "lastName": customer.lastName,
            "email": customer.email,
            "phone": customer.phone,
            "notes": customer.notes,
            "isActive": customer.isActive,
            "updatedAt": customer.updatedAt
        ]
        db.collection("customers").document(customer.id.uuidString).setData(data, merge: true)
    }
    
    public func pushEmployeeToCloud(_ employee: Employee) {
        var data: [String: Any] = [
            "id": employee.id.uuidString,
            "storeId": employee.storeId,
            "name": employee.name,
            "isActive": employee.isActive
        ]
        if let email = employee.email { data["email"] = email }
        if let phone = employee.phone { data["phone"] = phone }
        
        db.collection("employees").document(employee.id.uuidString).setData(data, merge: true)
    }
    
    public func deleteTransactionFromCloud(_ transactionId: String) {
        db.collection("transactions").document(transactionId).delete()
    }
    
    public func deleteCustomerFromCloud(_ customerId: String) {
        db.collection("customers").document(customerId).delete()
    }
    
    public func pushItemTagToCloud(_ tag: ItemTag) {
        let data: [String: Any] = [
            "id": tag.id.uuidString,
            "storeId": tag.storeId,
            "name": tag.name
        ]
        db.collection("tags").document(tag.id.uuidString).setData(data, merge: true)
    }
    
    public func updateStockInCloud(itemId: String, quantityDelta: Int) {
        db.collection("inventory").document(itemId).updateData([
            "stockCount": FieldValue.increment(Int64(quantityDelta))
        ])
    }
    
    public func deleteItemTagFromCloud(_ tagId: String) {
        db.collection("tags").document(tagId).delete()
    }
    
    public func pushCustomerStatusToCloud(_ status: CustomerStatus) {
        let data: [String: Any] = [
            "id": status.id.uuidString,
            "storeId": status.storeId,
            "name": status.name
        ]
        db.collection("customerStatuses").document(status.id.uuidString).setData(data, merge: true)
    }
    
    public func deleteCustomerStatusFromCloud(_ statusId: String) {
        db.collection("customerStatuses").document(statusId).delete()
    }
    
    public func pushStoreProfileToCloud(storeId: String, payload: [String: Any]) {
        db.collection("stores").document(storeId).setData(payload, merge: true)
    }
    
    // MARK: - Activity Distribution (Targeted & Aggregated)
    
    public func pushActivityToCloud(_ log: ActivityLog) {
        var data: [String: Any] = [
            "id": log.id.uuidString,
            "storeId": log.storeId,
            "timestamp": log.timestamp,
            "title": log.title,
            "category": log.category,
            "targetRoles": log.targetRoles.isEmpty ? ["admin", "employee"] : log.targetRoles,
            "targetUserIds": log.targetUserIds,
            "count": log.count,
            "readBy": log.isRead ? [Auth.auth().currentUser?.uid].compactMap { $0 } : [],
            "deletedBy": []
        ]
        
        if let key = log.groupingKey {
            data["groupingKey"] = key
        }
        
        db.collection("activities").document(log.id.uuidString).setData(data)
    }
    
    /// Dispatches telemetry aimed exclusively at individual user identifiers, isolating visibility from standard organizational roles.
    public func pushTargetedActivityToCloud(_ log: ActivityLog, targetUserIds: [String]) {
        var data: [String: Any] = [
            "id": log.id.uuidString,
            "storeId": log.storeId,
            "timestamp": log.timestamp,
            "title": log.title,
            "category": log.category,
            "targetUserIds": targetUserIds,
            "targetRoles": log.targetRoles,
            "readBy": log.isRead ? [Auth.auth().currentUser?.uid].compactMap { $0 } : [],
            "deletedBy": []
        ]
        
        if let key = log.groupingKey {
            data["groupingKey"] = key
        }
        
        db.collection("activities").document(log.id.uuidString).setData(data)
    }
    
    /// Dynamically upserts consecutive operational intents utilizing atomic increments, mitigating notification UI fatigue.
    public func pushAggregatedActivityToCloud(storeId: String, dateKey: String, baseTitle: String, category: String, targetRoles: [String] = ["admin"]) {
        let documentId = "agg_\(storeId)_\(category)_\(dateKey)"
        
        let data: [String: Any] = [
            "id": UUID().uuidString,
            "storeId": storeId,
            "timestamp": FieldValue.serverTimestamp(),
            "title": baseTitle,
            "category": category,
            "count": FieldValue.increment(Int64(1)),
            "targetRoles": targetRoles,
            "groupingKey": documentId,
            "readBy": FieldValue.delete() // Purge read states when aggregation scales upward, surfacing event natively to read users.
        ]
        
        db.collection("activities").document(documentId).setData(data, merge: true)
    }
    
    // MARK: - Activity State Operations
    
    /// Flags an individual telemetry event as consumed.
    public func markActivityRead(logId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("activities").document(logId).updateData([
            "readBy": FieldValue.arrayUnion([uid])
        ])
    }
    
    /// Unflags a consumed telemetry event, placing it back in unread queue.
    public func markActivityUnread(logId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("activities").document(logId).updateData([
            "readBy": FieldValue.arrayRemove([uid])
        ])
    }
    
    /// Establishes an arbitrary soft-delete explicitly mapping to the workspace member.
    public func deleteActivityForUser(logId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("activities").document(logId).updateData([
            "deletedBy": FieldValue.arrayUnion([uid])
        ])
    }
    
    /// Ingests an automated batch closure matrix on targeted telemetry models to offload repetitive tasks in groups.
    public func markAllActivitiesRead(unreadIds: [String]) {
        guard let uid = Auth.auth().currentUser?.uid, !unreadIds.isEmpty else { return }
        var batch = db.batch()
        var operationCount = 0
        
        for id in unreadIds {
            let docRef = db.collection("activities").document(id)
            batch.updateData(["readBy": FieldValue.arrayUnion([uid])], forDocument: docRef)
            operationCount += 1
            
            // Abide by strict 500 operation caps inherent to Firestore Batch commits.
            if operationCount == 500 {
                batch.commit()
                batch = db.batch()
                operationCount = 0
            }
        }
        
        if operationCount > 0 {
            batch.commit()
        }
    }
    
    /// Purges the active user's visual trace across broad arrays of timeline telemetry in segmented pipelines.
    public func deleteAllActivitiesForUser(logIds: [String]) {
        guard let uid = Auth.auth().currentUser?.uid, !logIds.isEmpty else { return }
        var batch = db.batch()
        var operationCount = 0
        
        for id in logIds {
            let docRef = db.collection("activities").document(id)
            batch.updateData(["deletedBy": FieldValue.arrayUnion([uid])], forDocument: docRef)
            operationCount += 1
            
            if operationCount == 500 {
                batch.commit()
                batch = db.batch()
                operationCount = 0
            }
        }
        
        if operationCount > 0 {
            batch.commit()
        }
    }
}
