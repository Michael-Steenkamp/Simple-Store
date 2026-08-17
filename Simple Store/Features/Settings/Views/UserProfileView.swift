//
//  UserProfileView.swift
//  Simple Store
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import SwiftData

// MARK: - View Models

@MainActor
@Observable
final class UserProfileViewModel {
    var isEditing = false
    
    var editName = ""
    var editEmail = ""
    var editPhone = ""
    var newPassword = ""
    
    var isProcessing = false
    var errorMessage = ""
    var successMessage = ""
    
    var isShowingSignOutAlert = false
    var isShowingDeleteAccountAlert = false
    var isShowingDeleteStoreAlert = false
    var isShowingLeaveStoreAlert = false
    var storeNameConfirmation = ""
    
    var isShowingMyStores = false
    var isShowingDiscovery = false
    var isCreatingStore = false
    
    func populate(from user: AppUser?) {
        editName = user?.name ?? ""
        editEmail = user?.email ?? ""
        editPhone = user?.phone ?? ""
    }
    
    func updateProfile(session: SessionManager) async {
        isProcessing = true
        errorMessage = ""
        successMessage = ""
        
        guard let firebaseUser = Auth.auth().currentUser, let appUser = session.currentUser else {
            isProcessing = false
            return
        }
        
        do {
            var emailNotice = ""
            var firestoreUpdates: [String: Any] = [:]
            
            if !editEmail.isEmpty && editEmail != appUser.email {
                try await firebaseUser.sendEmailVerification(beforeUpdatingEmail: editEmail)
                emailNotice = " A verification link was sent."
                firestoreUpdates["email"] = editEmail
            }
            if !newPassword.isEmpty { try await firebaseUser.updatePassword(to: newPassword) }
            if !editName.isEmpty && editName != appUser.name { firestoreUpdates["name"] = editName }
            if !editPhone.isEmpty && editPhone != appUser.phone { firestoreUpdates["phone"] = editPhone }
            
            if !firestoreUpdates.isEmpty {
                let db = Firestore.firestore()
                try await db.collection("users").document(appUser.id ?? "").updateData(firestoreUpdates)
                if !editName.isEmpty { session.currentUser?.name = editName }
                if !editEmail.isEmpty { session.currentUser?.email = editEmail }
                if !editPhone.isEmpty { session.currentUser?.phone = editPhone }
            }
            
            successMessage = "Profile updated successfully.\(emailNotice)"
            newPassword = ""
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { self.isEditing = false }
                self.successMessage = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }
    
    func deleteAccount(session: SessionManager) async -> Bool {
        do {
            try await session.deleteCurrentAccount()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func deleteStoreCompletely(session: SessionManager) async -> Bool {
        guard let storeId = session.currentUser?.activeStoreId else { return false }
        do {
            try await session.deleteStore(storeId: storeId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func leaveCurrentStore(session: SessionManager) async -> Bool {
        guard let storeId = session.currentUser?.activeStoreId else { return false }
        await session.leaveStore(storeId: storeId)
        if session.errorMessage == nil {
            return true
        } else {
            errorMessage = session.errorMessage ?? "Failed to leave workspace."
            return false
        }
    }
    
    /// Executes a hard wipe of the local SwiftData environment upon sign-out to prevent context leakage across user profiles.
    func signOut(session: SessionManager, syncManager: SyncManager, context: ModelContext) async -> Bool {
        do {
            syncManager.stopAllListeners()
            syncManager.clearLocalDatabase(context: context)
            
            try Auth.auth().signOut()
            await session.checkAuthenticationState()
            return true
        } catch {
            errorMessage = "Error signing out: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Views

/// An interface for managing user credentials, app affiliations, and active workspace toggling.
struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    @AppStorage("storeName") private var currentStoreName: String = ""
    @State private var viewModel = UserProfileViewModel()
    
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    private var hasActiveStore: Bool {
        session.currentUser?.activeStoreId != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.errorMessage.isEmpty {
                    Section {
                        Text(viewModel.errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                
                if !viewModel.isEditing {
                    readOnlyProfileSection
                    storesSection
                    dangerZoneSection
                    
                    Section {
                        Button(role: .destructive) {
                            viewModel.isShowingSignOutAlert = true
                        } label: {
                            Text("Sign Out").frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                } else {
                    editProfileSection
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Profile" : "My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.isEditing {
                        Button("Cancel") { withAnimation { viewModel.isEditing = false } }
                    } else {
                        Button("Close") { dismiss() }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isEditing {
                        Button("Save") {
                            Task {
                                await viewModel.updateProfile(session: session)
                            }
                        }
                        .disabled(viewModel.isProcessing || (viewModel.editName.isEmpty && viewModel.editEmail.isEmpty && viewModel.newPassword.isEmpty && viewModel.editPhone.isEmpty))
                    } else {
                        Button {
                            withAnimation { viewModel.isEditing = true }
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .onAppear {
                viewModel.populate(from: session.currentUser)
            }
            .overlay {
                if let progress = session.deletionProgress {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView().scaleEffect(1.5)
                            Text("Processing Request")
                                .font(.headline)
                            Text(progress)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .sheet(isPresented: $viewModel.isShowingDiscovery) {
                StoreSelectionView(isPresentedModally: true)
            }
            .sheet(isPresented: $viewModel.isCreatingStore) {
                StoreSetupWizardView(isPresentedInSheet: true)
            }
            .sheet(isPresented: $viewModel.isShowingMyStores) {
                MyStoresView(isPresentedFromProfile: true)
            }
            .alert("Delete Account", isPresented: $viewModel.isShowingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        let success = await viewModel.deleteAccount(session: session)
                        if success { dismiss() }
                    }
                }
            } message: {
                Text("Are you sure? This archives your directory information and permanently removes your login credentials.")
            }
            .alert("Delete Entire Store?", isPresented: $viewModel.isShowingDeleteStoreAlert) {
                TextField("Store Name", text: $viewModel.storeNameConfirmation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                
                Button("Cancel", role: .cancel) {
                    viewModel.storeNameConfirmation = ""
                }
                
                Button("Delete Store", role: .destructive) {
                    Task {
                        let success = await viewModel.deleteStoreCompletely(session: session)
                        if success { dismiss() }
                    }
                }
                .disabled(viewModel.storeNameConfirmation != currentStoreName)
            } message: {
                Text("Type \"\(currentStoreName)\" to confirm deletion. This action is irreversible. All store inventory, orders, customer lists, and staff accounts will be wiped from the database.")
            }
            .alert("Leave Store", isPresented: $viewModel.isShowingLeaveStoreAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave Workspace", role: .destructive) {
                    Task {
                        let success = await viewModel.leaveCurrentStore(session: session)
                        if success { dismiss() }
                    }
                }
            } message: {
                Text("Are you sure you want to leave this store? You will lose access to its inventory and data.")
            }
            .alert("Sign Out", isPresented: $viewModel.isShowingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        let success = await viewModel.signOut(session: session, syncManager: syncManager, context: modelContext)
                        if success { dismiss() }
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var readOnlyProfileSection: some View {
        Section(header: Text("Profile Information")) {
            HStack {
                Text("Name")
                Spacer()
                Text(session.currentUser?.name ?? "Unknown").foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Email")
                Spacer()
                if let email = session.currentUser?.email, !email.isEmpty {
                    Text(email).foregroundStyle(.secondary)
                } else {
                    Text("Unknown Email").foregroundStyle(.secondary).italic()
                }
            }
            
            if let phone = session.currentUser?.phone, !phone.isEmpty {
                HStack {
                    Text("Phone")
                    Spacer()
                    Text(phone).foregroundStyle(.secondary)
                }
            }
            
            if hasActiveStore {
                HStack {
                    Text("Active Role")
                    Spacer()
                    let roleString = session.currentUser?.role?.rawValue.capitalized ?? "Browsing"
                    Text(roleString)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15)).foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var storesSection: some View {
        Section(header: Text("Stores")) {
            Button {
                viewModel.isShowingMyStores = true
            } label: {
                HStack {
                    Image(systemName: "building.2.crop.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Joined Stores")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(session.currentUser?.storeIds.count ?? 0) Joined")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var dangerZoneSection: some View {
        Section(header: Text("Danger Zone")) {
            Button(role: .destructive) {
                viewModel.isShowingDeleteAccountAlert = true
            } label: {
                Text("Delete Account").frame(maxWidth: .infinity, alignment: .center)
            }
            
            if hasActiveStore {
                if isAdmin {
                    Button(role: .destructive) {
                        viewModel.storeNameConfirmation = ""
                        viewModel.isShowingDeleteStoreAlert = true
                    } label: {
                        Text("Delete Active Store Permanently").frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    Button(role: .destructive) {
                        viewModel.isShowingLeaveStoreAlert = true
                    } label: {
                        Text("Leave Current Store").frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }
    
    private var editProfileSection: some View {
        Section(
            header: Text("Update Profile"),
            footer: Text("Note: Changing your email or password may require you to sign in again.")
        ) {
            TextField("Update Name", text: $viewModel.editName).textContentType(.name)
            TextField("Update Email", text: $viewModel.editEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never)
            TextField("Update Phone", text: $viewModel.editPhone).keyboardType(.phonePad)
            SecureField("New Password (Optional)", text: $viewModel.newPassword).textContentType(.newPassword)
            
            if !viewModel.successMessage.isEmpty { Text(viewModel.successMessage).font(.caption).foregroundStyle(.green) }
        }
    }
}
