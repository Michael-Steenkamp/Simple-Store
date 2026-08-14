//
//  UserProfileView.swift
//  Simple Store
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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
    var storeNameConfirmation = ""
    
    var isShowingWorkspaceSwitcher = false
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
    
    func signOut(session: SessionManager) async -> Bool {
        do {
            try Auth.auth().signOut()
            await session.checkAuthenticationState()
            return true
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            return false
        }
    }
}

@MainActor
@Observable
final class WorkspaceSwitcherViewModel {
    var myStores: [PublicStore] = []
    var isLoading = true
    
    func fetchMyStores(session: SessionManager) async {
        isLoading = true
        defer { isLoading = false }
        
        guard let storeIds = session.currentUser?.storeIds, !storeIds.isEmpty else { return }
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("stores").whereField(FieldPath.documentID(), in: storeIds).getDocuments()
            
            self.myStores = snapshot.documents.map { doc in
                let name = doc.data()["storeName"] as? String ?? "Unnamed Store"
                let address = doc.data()["storeAddress"] as? String ?? ""
                let logoURL = doc.data()["storeLogoURL"] as? String ?? ""
                return PublicStore(id: doc.documentID, name: name, address: address, logoURL: logoURL)
            }.sorted(by: { $0.name < $1.name })
            
        } catch {
            print("Failed to fetch workspaces: \(error.localizedDescription)")
        }
    }
}

// MARK: - Views

/// An interface for managing user credentials, app affiliations, and active workspace toggling.
struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    @State private var viewModel = UserProfileViewModel()
    
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.isEditing {
                    readOnlyProfileSection
                    workspacesSection
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
                        Button("Done") { dismiss() }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if !viewModel.isEditing {
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
            .fullScreenCover(isPresented: $viewModel.isShowingDiscovery) {
                StoreSelectionView()
            }
            .fullScreenCover(isPresented: $viewModel.isCreatingStore) {
                StoreSetupWizardView()
            }
            .sheet(isPresented: $viewModel.isShowingWorkspaceSwitcher) {
                WorkspaceSwitcherView()
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
                TextField("Type store name to confirm", text: $viewModel.storeNameConfirmation)
                Button("Cancel", role: .cancel) { viewModel.storeNameConfirmation = "" }
                Button("Nuke Store", role: .destructive) {
                    Task {
                        let success = await viewModel.deleteStoreCompletely(session: session)
                        if success { dismiss() }
                    }
                }
            } message: {
                Text("This action is irreversible. All store inventory, orders, customer lists, and staff accounts will be wiped from the database.")
            }
            .alert("Sign Out", isPresented: $viewModel.isShowingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        let success = await viewModel.signOut(session: session)
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
                    Text("Guest Account").foregroundStyle(.secondary).italic()
                }
            }
            
            if let phone = session.currentUser?.phone, !phone.isEmpty {
                HStack {
                    Text("Phone")
                    Spacer()
                    Text(phone).foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Text("Active Role")
                Spacer()
                let roleString = session.currentUser?.activeStoreId != nil ? (session.currentUser?.storeRoles[session.currentUser!.activeStoreId!] ?? "Guest") : "Guest"
                Text(roleString.capitalized)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15)).foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
        }
    }
    
    private var workspacesSection: some View {
        Section(header: Text("Workspaces")) {
            Button {
                viewModel.isShowingWorkspaceSwitcher = true
            } label: {
                HStack {
                    Image(systemName: "building.2.crop.circle.fill")
                        .foregroundStyle(.blue)
                    Text("My Stores")
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
            
            if isAdmin {
                Button(role: .destructive) {
                    viewModel.isShowingDeleteStoreAlert = true
                } label: {
                    Text("Delete Active Store Permanently").frame(maxWidth: .infinity, alignment: .center)
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
            
            if !viewModel.errorMessage.isEmpty { Text(viewModel.errorMessage).font(.caption).foregroundStyle(.red) }
            if !viewModel.successMessage.isEmpty { Text(viewModel.successMessage).font(.caption).foregroundStyle(.green) }
            
            Button {
                Task { await viewModel.updateProfile(session: session) }
            } label: {
                HStack {
                    if viewModel.isProcessing { ProgressView().controlSize(.small) } else { Text("Save Changes") }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(viewModel.isProcessing || (viewModel.editName.isEmpty && viewModel.editEmail.isEmpty && viewModel.newPassword.isEmpty && viewModel.editPhone.isEmpty))
        }
    }
}

// MARK: - Workspace Switcher Sub-View

struct WorkspaceSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    @State private var viewModel = WorkspaceSwitcherViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading {
                    ProgressView("Loading workspaces...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if viewModel.myStores.isEmpty {
                    Text("You haven't joined any stores yet.")
                        .foregroundStyle(.secondary).italic()
                } else {
                    ForEach(viewModel.myStores) { store in
                        Button {
                            Task {
                                await session.switchActiveStore(to: store.id)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if let url = URL(string: store.logoURL), !store.logoURL.isEmpty {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill().frame(width: 40, height: 40).clipShape(Circle())
                                        } else {
                                            placeholderIcon
                                        }
                                    }
                                } else {
                                    placeholderIcon
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(store.name).font(.headline).foregroundStyle(.primary)
                                    if let role = session.currentUser?.storeRoles[store.id] {
                                        Text(role.capitalized).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                
                                if session.currentUser?.activeStoreId == store.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue).font(.title3)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Your Workspaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { await viewModel.fetchMyStores(session: session) }
        }
    }
    
    var placeholderIcon: some View {
        Circle()
            .fill(Color(uiColor: .secondarySystemBackground))
            .frame(width: 40, height: 40)
            .overlay(Image(systemName: "storefront.fill").foregroundStyle(.gray))
    }
}
