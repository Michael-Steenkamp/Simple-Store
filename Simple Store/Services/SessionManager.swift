//
//  SessionManager.swift
//  Simple Store
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Manages user authentication, workspace (tenant) isolation, and global session state.
/// Acts as the central `@MainActor` source of truth for the active user's permissions and current store context.
@Observable
@MainActor
final class SessionManager {
    
    // MARK: - State Properties
    
    /// The currently authenticated user and their workspace profile.
    var currentUser: AppUser? {
        didSet {
            subscriptionManager.isSystemAdmin = currentUser?.isSystemAdmin ?? false
        }
    }
    
    /// Indicates if the session manager is currently performing a network or authentication task.
    var isLoading: Bool = true
    
    /// A user-facing error message, if any recent operation failed.
    var errorMessage: String?
    
    // MARK: - Dependencies
    
    let subscriptionManager = SubscriptionManager()
    private let db = Firestore.firestore()
    
    // MARK: - Initialization
    
    init() {
        Task {
            await checkAuthenticationState()
        }
    }
    
    // MARK: - Authentication & Routing
    
    /// Validates the current Firebase authentication state and fetches the associated `AppUser` profile.
    func checkAuthenticationState() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let authUser = Auth.auth().currentUser else {
            currentUser = nil
            return
        }
        
        do {
            let snapshot = try await db.collection("users").document(authUser.uid).getDocument()
            guard var userProfile = try snapshot.data(as: AppUser?.self) else {
                errorMessage = "User profile not found. Please re-register."
                try? Auth.auth().signOut()
                return
            }
            
            if let autoJoin = userProfile.autoJoinStoreId, userProfile.storeIds.contains(autoJoin) {
                userProfile.activeStoreId = autoJoin
                try await db.collection("users").document(authUser.uid).updateData(["activeStoreId": autoJoin])
            } else {
                userProfile.activeStoreId = nil
                try await db.collection("users").document(authUser.uid).updateData(["activeStoreId": FieldValue.delete()])
            }
            
            currentUser = userProfile
        } catch {
            errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Workspace Operations
    
    /// Switches the active workspace (tenant) context for the current user.
    /// - Parameter newStoreId: The unique identifier of the target store.
    func switchActiveStore(to newStoreId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(uid).updateData([
                "activeStoreId": newStoreId
            ])
            currentUser?.activeStoreId = newStoreId
        } catch {
            errorMessage = "Failed to switch workspaces."
        }
    }
    
    /// Links the current user to an existing store workspace as a customer.
    /// - Parameter storeId: The unique identifier of the target store.
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
            
            let newRecordId = UUID().uuidString
            let userName = currentUser?.name ?? "Guest User"
            let nameParts = userName.components(separatedBy: " ")
            let first = nameParts.first ?? "Guest"
            let last = nameParts.dropFirst().joined(separator: " ")
            
            let custData: [String: Any] = [
                "id": newRecordId,
                "storeId": storeId,
                "firstName": first,
                "lastName": last,
                "email": currentUser?.email ?? "",
                "phone": "",
                "isActive": true,
                "updatedAt": Timestamp(),
                "dateAdded": Timestamp()
            ]
            try await db.collection("customers").document(newRecordId).setData(custData)
            
            currentUser?.storeIds.append(storeId)
            currentUser?.storeRoles[storeId] = UserRole.customer.rawValue
            currentUser?.activeStoreId = storeId
            errorMessage = nil
            
        } catch {
            errorMessage = "Failed to join store: \(error.localizedDescription)"
        }
    }
    
    /// Initializes a new retail tenant and grants the current user administrative privileges.
    func createStore(storeName: String, storeEmail: String, storePhone: String, storeAddress: String, logoData: Data?) async throws {
        guard let authUser = Auth.auth().currentUser, let appUser = currentUser else {
            throw NSError(domain: "SessionManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication error. Please sign in again."])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let newStoreId = UUID().uuidString
        var logoURL = ""
        
        if let data = logoData, let url = try? await StorageManager.shared.uploadStoreLogo(data: data, storeId: newStoreId) {
            logoURL = url
        }
        
        let storeData: [String: Any] = [
            "id": newStoreId,
            "storeName": storeName,
            "storeEmail": storeEmail,
            "storePhone": storePhone,
            "storeAddress": storeAddress,
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
            "isActive": true
        ]
        try await db.collection("employees").document(newEmpId).setData(empData)
        
        currentUser?.storeIds.append(newStoreId)
        currentUser?.storeRoles[newStoreId] = UserRole.admin.rawValue
        currentUser?.activeStoreId = newStoreId
        
        // Cache basic store info for offline availability / quick retrieval
        UserDefaults.standard.set(storeName, forKey: "storeName")
        UserDefaults.standard.set(storeEmail, forKey: "storeEmail")
        UserDefaults.standard.set(storePhone, forKey: "storePhone")
        UserDefaults.standard.set(storeAddress, forKey: "storeAddress")
        if let logoData { UserDefaults.standard.set(logoData, forKey: "storeLogo") }
    }
    
    // MARK: - Account & Store Deletion Rules
    
    /// Permanently deletes the current user account and soft-deletes their associated records within active workspaces.
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
    }
    
    /// Permanently deletes a store and completely purges its sub-collections.
    /// - Note: Executes collection deletions concurrently using `TaskGroup` for performance.
    func deleteStore(storeId: String) async throws {
        guard let appUser = currentUser, appUser.role == .admin else {
            throw NSError(domain: "SessionManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Unauthorized action."])
        }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            let collections = ["inventory", "customers", "employees", "transactions", "tags", "customerStatuses"]
            for col in collections {
                group.addTask { [db] in
                    let docs = try await db.collection(col).whereField("storeId", isEqualTo: storeId).getDocuments()
                    for doc in docs.documents {
                        try await doc.reference.delete()
                    }
                }
            }
            try await group.waitForAll()
        }
        
        try await db.collection("stores").document(storeId).delete()
        
        if let authUser = Auth.auth().currentUser {
            try await db.collection("users").document(authUser.uid).updateData([
                "storeIds": FieldValue.arrayRemove([storeId]),
                "storeRoles.\(storeId)": FieldValue.delete(),
                "activeStoreId": FieldValue.delete()
            ])
            
            currentUser?.storeIds.removeAll(where: { $0 == storeId })
            currentUser?.storeRoles.removeValue(forKey: storeId)
            currentUser?.activeStoreId = currentUser?.storeIds.first
        }
    }
    
    // MARK: - Role Management Pipelines
    
    func promoteCustomerToEmployee(customerEmail: String, customerName: String) async throws {
        guard let storeId = currentUser?.activeStoreId, currentUser?.role == .admin else { return }
        
        let snapshot = try await db.collection("users")
            .whereField("storeIds", arrayContains: storeId)
            .whereField("email", isEqualTo: customerEmail)
            .getDocuments()
        
        guard let userDoc = snapshot.documents.first else {
            throw NSError(domain: "SessionManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a registered app account matching this customer's email."])
        }
        
        try await userDoc.reference.updateData([
            "storeRoles.\(storeId)": UserRole.employee.rawValue
        ])
        
        let newEmpId = UUID().uuidString
        let empData: [String: Any] = [
            "id": newEmpId,
            "storeId": storeId,
            "name": customerName,
            "isActive": true
        ]
        try await db.collection("employees").document(newEmpId).setData(empData)
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
    
    func demoteEmployeeToCustomer(employeeName: String) async throws {
        guard let storeId = currentUser?.activeStoreId, currentUser?.role == .admin else { return }
        
        let snapshot = try await db.collection("users")
            .whereField("storeIds", arrayContains: storeId)
            .whereField("name", isEqualTo: employeeName)
            .getDocuments()
        
        guard let userDoc = snapshot.documents.first else {
            throw NSError(domain: "SessionManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a registered app account matching this employee name."])
        }
        
        try await userDoc.reference.updateData([
            "storeRoles.\(storeId)": UserRole.customer.rawValue
        ])
        
        let newCustId = UUID().uuidString
        let nameParts = employeeName.components(separatedBy: " ")
        let first = nameParts.first ?? "Guest"
        let last = nameParts.dropFirst().joined(separator: " ")
        
        let userEmail = userDoc.data()["email"] as? String ?? ""
        let userPhone = userDoc.data()["phone"] as? String ?? ""
        
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
    }
    
    // MARK: - Workspace Preferences
    
    /// Toggles whether the application should bypass the Store Selection screen and route directly into a specific store.
    func toggleAutoJoin(storeId: String) async {
        guard let uid = Auth.auth().currentUser?.uid, let user = currentUser else { return }
        
        let newValue = user.autoJoinStoreId == storeId ? nil : storeId
        
        do {
            try await db.collection("users").document(uid).updateData([
                "autoJoinStoreId": newValue != nil ? newValue! : FieldValue.delete()
            ])
            currentUser?.autoJoinStoreId = newValue
        } catch {
            errorMessage = "Failed to update auto-join preference."
        }
    }
    
    /// Disconnects the user from a workspace and soft-deletes their directory presence within that store.
    func leaveStore(storeId: String) async {
        guard let uid = Auth.auth().currentUser?.uid, let appUser = currentUser else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            var updates: [String: Any] = [
                "storeIds": FieldValue.arrayRemove([storeId]),
                "storeRoles.\(storeId)": FieldValue.delete()
            ]
            
            if appUser.autoJoinStoreId == storeId {
                updates["autoJoinStoreId"] = FieldValue.delete()
            }
            
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
            
            currentUser?.storeIds.removeAll(where: { $0 == storeId })
            currentUser?.storeRoles.removeValue(forKey: storeId)
            if currentUser?.autoJoinStoreId == storeId { currentUser?.autoJoinStoreId = nil }
            if currentUser?.activeStoreId == storeId { currentUser?.activeStoreId = nil }
            
        } catch {
            errorMessage = "Failed to leave store: \(error.localizedDescription)"
        }
    }
}
