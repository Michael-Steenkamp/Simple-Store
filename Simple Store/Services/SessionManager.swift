//
//  SessionManager.swift
//  Simple Store
//

import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

/// Manages user authentication, workspace (tenant) isolation, and global session state.
/// Acts as the central `@MainActor` source of truth for the active user's permissions and current store context.
@Observable
@MainActor
final class SessionManager {
    
    // MARK: - State Properties
    
    var currentUser: AppUser?
    var isLoading: Bool = true
    var errorMessage: String?
    var deletionProgress: String? = nil
    
    // MARK: - Dependencies
    
    let subscriptionManager = SubscriptionManager()
    private var db: Firestore { Firestore.firestore() }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await checkAuthenticationState()
        }
    }
    
    // MARK: - Authentication & Routing
    
    func checkAuthenticationState() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let authUser = Auth.auth().currentUser else {
            currentUser = nil
            subscriptionManager.isSystemAdmin = false
            return
        }
        
        do {
            let docRef = db.collection("users").document(authUser.uid)
            let snapshot: DocumentSnapshot
            
            if let cachedDoc = try? await docRef.getDocument(source: .cache), cachedDoc.exists {
                snapshot = cachedDoc
                Task.detached { try? await docRef.getDocument(source: .server) }
            } else {
                snapshot = try await docRef.getDocument(source: .default)
            }
            
            guard let userProfile = try snapshot.data(as: AppUser?.self) else {
                errorMessage = "User profile not found. Please re-register."
                try? Auth.auth().signOut()
                return
            }
            
            currentUser = userProfile
            subscriptionManager.isSystemAdmin = userProfile.isSystemAdmin
            
        } catch {
            errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Workspace Operations
    
    func switchActiveStore(to newStoreId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData([
                "activeStoreId": newStoreId
            ])
            if var updatedUser = currentUser {
                updatedUser.activeStoreId = newStoreId
                currentUser = updatedUser
            }
        } catch {
            errorMessage = "Failed to switch workspaces."
        }
    }
    
    func joinStore(storeId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Authentication error. Please sign in again."
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let storeDoc = try await db.collection("stores").document(storeId).getDocument()
            guard storeDoc.exists else {
                errorMessage = "Store not found. It may have been deleted."
                return
            }
            
            try await db.collection("users").document(uid).updateData([
                "storeIds": FieldValue.arrayUnion([storeId]),
                "storeRoles.\(storeId)": UserRole.customer.rawValue,
                "activeStoreId": storeId
            ])
            
            let userEmail = currentUser?.email ?? ""
            var customerAlreadyExists = false
            
            if !userEmail.isEmpty {
                let custQuery = try await db.collection("customers")
                    .whereField("storeId", isEqualTo: storeId)
                    .whereField("email", isEqualTo: userEmail)
                    .getDocuments()
                
                if !custQuery.isEmpty {
                    customerAlreadyExists = true
                }
            }
            
            if !customerAlreadyExists {
                let newRecordId = UUID().uuidString
                let userName = currentUser?.name ?? "Unknown User"
                let nameParts = userName.components(separatedBy: " ")
                let first = nameParts.first ?? "Unknown"
                let last = nameParts.dropFirst().joined(separator: " ")
                
                let custData: [String: Any] = [
                    "id": newRecordId,
                    "storeId": storeId,
                    "firstName": first,
                    "lastName": last,
                    "email": userEmail,
                    "phone": "",
                    "isActive": true,
                    "updatedAt": Timestamp(),
                    "dateAdded": Timestamp()
                ]
                try await db.collection("customers").document(newRecordId).setData(custData)
            }
            
            if var updatedUser = currentUser {
                updatedUser.storeIds.append(storeId)
                updatedUser.storeRoles[storeId] = UserRole.customer.rawValue
                updatedUser.activeStoreId = storeId
                currentUser = updatedUser
            }
            errorMessage = nil
            
        } catch {
            errorMessage = "Failed to join store: \(error.localizedDescription)"
        }
    }
    
    func createStore(
        storeName: String,
        storeEmail: String,
        storePhone: String,
        storeAddress: String,
        storeWebsite: String,
        receiptThankYou: String,
        receiptReturnPolicy: String,
        showLogoOnReceipt: Bool,
        showAddressOnReceipt: Bool,
        showWebsiteOnReceipt: Bool,
        showEmployeeOnReceipt: Bool,
        logoData: Data?
    ) async throws {
        guard let authUser = Auth.auth().currentUser, let appUser = currentUser else {
            throw NSError(domain: "SessionManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication error. Please sign in again."])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let newStoreId = UUID().uuidString
        var logoURL = ""
        
        if let data = logoData {
            if let url = try? await StorageManager.shared.uploadStoreLogo(data: data, storeId: newStoreId) {
                logoURL = url
            } else {
                logoURL = "OFFLINE_CACHE"
            }
        }
        
        let storeData: [String: Any] = [
            "id": newStoreId,
            "storeName": storeName,
            "storeEmail": storeEmail,
            "storePhone": storePhone,
            "storeAddress": storeAddress,
            "storeWebsite": storeWebsite,
            "receiptThankYou": receiptThankYou,
            "receiptReturnPolicy": receiptReturnPolicy,
            "showLogoOnReceipt": showLogoOnReceipt,
            "showAddressOnReceipt": showAddressOnReceipt,
            "showWebsiteOnReceipt": showWebsiteOnReceipt,
            "showEmployeeOnReceipt": showEmployeeOnReceipt,
            "storeLogoURL": logoURL,
            "createdAt": Timestamp()
        ]
        
        try await db.collection("stores").document(newStoreId).setData(storeData)
        
        try await db.collection("users").document(authUser.uid).updateData([
            "storeIds": FieldValue.arrayUnion([newStoreId]),
            "storeRoles.\(newStoreId)": UserRole.admin.rawValue,
            "activeStoreId": newStoreId
        ])
        
        let newEmpId = UUID().uuidString
        let empData: [String: Any] = [
            "id": newEmpId,
            "storeId": newStoreId,
            "name": appUser.name,
            "email": appUser.email ?? "",
            "phone": appUser.phone ?? "",
            "isActive": true
        ]
        try await db.collection("employees").document(newEmpId).setData(empData)
        
        if var updatedUser = currentUser {
            updatedUser.storeIds.append(newStoreId)
            updatedUser.storeRoles[newStoreId] = UserRole.admin.rawValue
            updatedUser.activeStoreId = newStoreId
            currentUser = updatedUser
        }
        
        UserDefaults.standard.set(storeName, forKey: "storeName")
        UserDefaults.standard.set(storeEmail, forKey: "storeEmail")
        UserDefaults.standard.set(storePhone, forKey: "storePhone")
        UserDefaults.standard.set(storeAddress, forKey: "storeAddress")
        UserDefaults.standard.set(storeWebsite, forKey: "storeWebsite")
        UserDefaults.standard.set(receiptThankYou, forKey: "receiptThankYou")
        UserDefaults.standard.set(receiptReturnPolicy, forKey: "receiptReturnPolicy")
        UserDefaults.standard.set(showLogoOnReceipt, forKey: "showLogoOnReceipt")
        UserDefaults.standard.set(showAddressOnReceipt, forKey: "showAddressOnReceipt")
        UserDefaults.standard.set(showWebsiteOnReceipt, forKey: "showWebsiteOnReceipt")
        UserDefaults.standard.set(showEmployeeOnReceipt, forKey: "showCashierOnReceipt")
        
        if let logoData {
            UserDefaults.standard.set(logoData, forKey: "storeLogo")
        } else {
            UserDefaults.standard.removeObject(forKey: "storeLogo")
        }
    }
    
    // MARK: - Validation & Recovery
    
    /// Queries the active workspace to prevent duplicate account creation based on email.
    func isEmailRegistered(email: String) async -> Bool {
        guard let storeId = currentUser?.activeStoreId else { return false }
        let targetEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        
        do {
            let custQuery = try await db.collection("customers")
                .whereField("storeId", isEqualTo: storeId)
                .whereField("email", isEqualTo: targetEmail)
                .getDocuments()
            
            if !custQuery.isEmpty { return true }
            
            let empQuery = try await db.collection("employees")
                .whereField("storeId", isEqualTo: storeId)
                .whereField("email", isEqualTo: targetEmail)
                .getDocuments()
            
            return !empQuery.isEmpty
        } catch {
            return false
        }
    }
    
    func sendPasswordReset(to resetEmail: String) async throws {
        let trimmedEmail = resetEmail.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else {
            throw NSError(domain: "SessionManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Email address cannot be empty."])
        }
        try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
    }
    
    // MARK: - Account Provisioning
    
    func provisionSystemAccount(email: String, firstName: String, lastName: String, phone: String, role: UserRole) async throws {
        guard let storeId = currentUser?.activeStoreId else {
            throw NSError(domain: "SessionManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No active store context found."])
        }
        
        let secondaryAppName = "TenantProvisioningApp"
        var secondaryApp = FirebaseApp.app(name: secondaryAppName)
        
        if secondaryApp == nil {
            guard let defaultOptions = FirebaseApp.app()?.options else {
                throw NSError(domain: "SessionManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Firebase configuration missing."])
            }
            FirebaseApp.configure(name: secondaryAppName, options: defaultOptions)
            secondaryApp = FirebaseApp.app(name: secondaryAppName)
        }
        
        guard let app = secondaryApp else {
            throw NSError(domain: "SessionManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize provisioning framework."])
        }
        
        let secondaryAuth = Auth.auth(app: app)
        
        let tempPassword = UUID().uuidString.prefix(12) + "A1!"
        let authResult = try await secondaryAuth.createUser(withEmail: email, password: String(tempPassword))
        let newUid = authResult.user.uid
        
        let newUser = AppUser(
            id: newUid,
            name: "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces),
            email: email,
            phone: phone,
            isSystemAdmin: false,
            storeIds: [storeId],
            storeRoles: [storeId: role.rawValue],
            activeStoreId: storeId
        )
        
        let userData = try Firestore.Encoder().encode(newUser)
        try await db.collection("users").document(newUid).setData(userData)
        
        try await Auth.auth().sendPasswordReset(withEmail: email)
        try? secondaryAuth.signOut()
    }
    
    // MARK: - Account & Store Deletion Rules
    
    func deleteCurrentAccount() async throws {
        guard let authUser = Auth.auth().currentUser, let appUser = currentUser else { return }
        
        if appUser.role == .admin, let storeId = appUser.activeStoreId {
            let adminQuery = try await db.collection("users")
                .whereField("storeIds", arrayContains: storeId)
                .whereField("storeRoles.\(storeId)", isEqualTo: UserRole.admin.rawValue)
                .getDocuments()
            
            if adminQuery.documents.count <= 1 {
                throw NSError(domain: "SessionManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot delete account. You are the sole administrator of an active store. Please assign another admin or delete the store entirely."])
            }
        }
        
        if let storeId = appUser.activeStoreId {
            if appUser.role == .customer {
                let match = try await db.collection("customers").whereField("storeId", isEqualTo: storeId).whereField("email", isEqualTo: appUser.email ?? "").getDocuments()
                for doc in match.documents {
                    try await doc.reference.updateData(["firstName": "Deleted", "lastName": "Customer", "isActive": false])
                }
            } else if appUser.role == .employee {
                let match = try await db.collection("employees").whereField("storeId", isEqualTo: storeId).whereField("name", isEqualTo: appUser.name).getDocuments()
                for doc in match.documents {
                    try await doc.reference.updateData(["isActive": false])
                }
            }
        }
        
        try await db.collection("users").document(authUser.uid).delete()
        try await authUser.delete()
        
        try? Auth.auth().signOut()
        currentUser = nil
        subscriptionManager.isSystemAdmin = false
    }
    
    func deleteStore(storeId: String) async throws {
        guard let appUser = currentUser, appUser.role == .admin else {
            throw NSError(domain: "SessionManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Unauthorized action."])
        }
        
        let database = db
        
        deletionProgress = "Purging category /inventory..."
        let invDocs = try await database.collection("inventory").whereField("storeId", isEqualTo: storeId).getDocuments()
        for doc in invDocs.documents { try await doc.reference.delete() }
        
        deletionProgress = "Purging category /customers..."
        let custDocs = try await database.collection("customers").whereField("storeId", isEqualTo: storeId).getDocuments()
        for doc in custDocs.documents { try await doc.reference.delete() }
        
        deletionProgress = "Purging category /employees..."
        let empDocs = try await database.collection("employees").whereField("storeId", isEqualTo: storeId).getDocuments()
        for doc in empDocs.documents { try await doc.reference.delete() }
        
        deletionProgress = "Purging category /transactions..."
        let txDocs = try await database.collection("transactions").whereField("storeId", isEqualTo: storeId).getDocuments()
        for doc in txDocs.documents { try await doc.reference.delete() }
        
        deletionProgress = "Purging category /tags..."
        let tagDocs = try await database.collection("tags").whereField("storeId", isEqualTo: storeId).getDocuments()
        for doc in tagDocs.documents { try await doc.reference.delete() }
        
        deletionProgress = "Purging category /customerStatuses..."
        let statDocs = try await database.collection("customerStatuses").whereField("storeId", isEqualTo: storeId).getDocuments()
        for doc in statDocs.documents { try await doc.reference.delete() }
        
        deletionProgress = "Finalizing workspace teardown..."
        try await database.collection("stores").document(storeId).delete()
        
        if let authUser = Auth.auth().currentUser {
            try await database.collection("users").document(authUser.uid).updateData([
                "storeIds": FieldValue.arrayRemove([storeId]),
                "storeRoles.\(storeId)": FieldValue.delete(),
                "activeStoreId": FieldValue.delete()
            ])
            
            if var updatedUser = currentUser {
                updatedUser.storeIds.removeAll(where: { $0 == storeId })
                updatedUser.storeRoles.removeValue(forKey: storeId)
                updatedUser.activeStoreId = updatedUser.storeIds.first
                currentUser = updatedUser
            }
        }
        
        deletionProgress = nil
    }
    
    // MARK: - Role Management Pipelines
    
    /// Promotes a customer and returns the newly generated Employee ID to facilitate transaction migration.
    func promoteCustomerToEmployee(customerEmail: String, customerName: String, customerPhone: String) async throws -> String {
        guard let storeId = currentUser?.activeStoreId, currentUser?.role == .admin else {
            throw NSError(domain: "SessionManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Unauthorized."])
        }
        
        let snapshot = try await db.collection("users")
            .whereField("storeIds", arrayContains: storeId)
            .whereField("email", isEqualTo: customerEmail)
            .getDocuments()
        
        if let userDoc = snapshot.documents.first {
            try await userDoc.reference.updateData([
                "storeRoles.\(storeId)": UserRole.employee.rawValue
            ])
        }
        
        let newEmpId = UUID().uuidString
        var empData: [String: Any] = [
            "id": newEmpId,
            "storeId": storeId,
            "name": customerName,
            "isActive": true
        ]
        
        if !customerEmail.isEmpty { empData["email"] = customerEmail }
        if !customerPhone.isEmpty { empData["phone"] = customerPhone }
        
        try await db.collection("employees").document(newEmpId).setData(empData)
        return newEmpId
    }
    
    func promoteEmployeeToAdmin(employeeName: String) async throws {
        guard let storeId = currentUser?.activeStoreId, currentUser?.role == .admin else { return }
        
        let snapshot = try await db.collection("users")
            .whereField("storeIds", arrayContains: storeId)
            .whereField("name", isEqualTo: employeeName)
            .getDocuments()
        
        guard let userDoc = snapshot.documents.first else {
            throw NSError(domain: "SessionManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a registered app account matching this exact employee name."])
        }
        
        try await userDoc.reference.updateData([
            "storeRoles.\(storeId)": UserRole.admin.rawValue
        ])
    }
    
    func fetchStoreAdminNames() async -> [String] {
        guard let storeId = currentUser?.activeStoreId else { return [] }
        do {
            let snapshot = try await db.collection("users")
                .whereField("storeIds", arrayContains: storeId)
                .whereField("storeRoles.\(storeId)", isEqualTo: UserRole.admin.rawValue)
                .getDocuments()
            
            return snapshot.documents.compactMap { $0.data()["name"] as? String }
        } catch {
            return []
        }
    }
    
    /// Demotes an employee and returns the newly generated Customer ID to facilitate transaction migration.
    func demoteEmployeeToCustomer(employeeName: String) async throws -> String {
        guard let storeId = currentUser?.activeStoreId, currentUser?.role == .admin else {
            throw NSError(domain: "SessionManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Unauthorized."])
        }
        
        let snapshot = try await db.collection("users")
            .whereField("storeIds", arrayContains: storeId)
            .whereField("name", isEqualTo: employeeName)
            .getDocuments()
        
        let newCustId = UUID().uuidString
        var userEmail = ""
        var userPhone = ""
        
        if let userDoc = snapshot.documents.first {
            try await userDoc.reference.updateData([
                "storeRoles.\(storeId)": UserRole.customer.rawValue
            ])
            userEmail = userDoc.data()["email"] as? String ?? ""
            userPhone = userDoc.data()["phone"] as? String ?? ""
        }
        
        let nameParts = employeeName.components(separatedBy: " ")
        let first = nameParts.first ?? "Unknown"
        let last = nameParts.dropFirst().joined(separator: " ")
        
        let custData: [String: Any] = [
            "id": newCustId,
            "storeId": storeId,
            "firstName": first,
            "lastName": last,
            "email": userEmail,
            "phone": userPhone,
            "isActive": true,
            "updatedAt": Timestamp(),
            "dateAdded": Timestamp()
        ]
        
        try await db.collection("customers").document(newCustId).setData(custData)
        return newCustId
    }
    
    // MARK: - Workspace Preferences
    
    func leaveStore(storeId: String) async {
        guard let uid = Auth.auth().currentUser?.uid, let appUser = currentUser else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let updates: [String: Any] = [
                "storeIds": FieldValue.arrayRemove([storeId]),
                "storeRoles.\(storeId)": FieldValue.delete()
            ]
            
            try await db.collection("users").document(uid).updateData(updates)
            
            let role = appUser.storeRoles[storeId]
            if role == UserRole.customer.rawValue {
                let match = try await db.collection("customers").whereField("storeId", isEqualTo: storeId).whereField("email", isEqualTo: appUser.email ?? "").getDocuments()
                for doc in match.documents {
                    try await doc.reference.updateData(["firstName": "Left", "lastName": "Store", "isActive": false])
                }
            } else if role == UserRole.employee.rawValue || role == UserRole.admin.rawValue {
                let match = try await db.collection("employees").whereField("storeId", isEqualTo: storeId).whereField("name", isEqualTo: appUser.name).getDocuments()
                for doc in match.documents {
                    try await doc.reference.updateData(["isActive": false])
                }
            }
            
            if var updatedUser = currentUser {
                updatedUser.storeIds.removeAll(where: { $0 == storeId })
                updatedUser.storeRoles.removeValue(forKey: storeId)
                if updatedUser.activeStoreId == storeId { updatedUser.activeStoreId = nil }
                currentUser = updatedUser
            }
            
        } catch {
            errorMessage = "Failed to leave store: \(error.localizedDescription)"
        }
    }
}
