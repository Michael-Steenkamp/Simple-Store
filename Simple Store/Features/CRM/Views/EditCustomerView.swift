//
//  EditCustomerView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

@MainActor
@Observable
final class EditCustomerViewModel {
    var firstName: String
    var lastName: String
    var email: String
    var phone: String
    var notes: String
    var selectedStatus: CustomerStatus?
    var actionError = ""
    var successMessage = ""
    
    let customer: Customer
    
    init(customer: Customer) {
        self.customer = customer
        self.firstName = customer.firstName
        self.lastName = customer.lastName
        self.email = customer.email
        self.phone = customer.phone
        self.notes = customer.notes
        self.selectedStatus = customer.status
    }
    
    var isEmailValid: Bool {
        if email.isEmpty { return true }
        let emailRegex = /^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$/
        return email.wholeMatch(of: emailRegex) != nil
    }
    
    var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty && isEmailValid
    }
    
    func saveChanges(context: ModelContext, session: SessionManager, syncManager: SyncManager) async -> Bool {
        let cleanedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        
        if cleanedEmail != customer.email.lowercased() && !cleanedEmail.isEmpty {
            let emailExists = await session.isEmailRegistered(email: cleanedEmail)
            if emailExists {
                actionError = "This email is already registered to another user."
                return false
            }
        }
        
        customer.firstName = firstName.trimmingCharacters(in: .whitespaces)
        customer.lastName = lastName.trimmingCharacters(in: .whitespaces)
        customer.email = cleanedEmail
        customer.phone = phone.formattedAsPhoneNumber
        customer.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.status = selectedStatus
        customer.updatedAt = Date()
        
        try? context.save()
        syncManager.pushCustomerToCloud(customer)
        return true
    }
    
    func promoteCustomer(session: SessionManager, context: ModelContext, syncManager: SyncManager) async -> Bool {
        actionError = ""
        do {
            let newEmpId = try await session.promoteCustomerToEmployee(
                customerEmail: customer.email,
                customerName: customer.fullName,
                customerPhone: customer.phone
            )
            
            // Reassign transactions to properly map to the new employee identity.
            if let transactions = customer.transactions {
                let txsToUpdate = Array(transactions)
                for tx in txsToUpdate {
                    tx.buyerEmployeeId = newEmpId
                    tx.buyerEmployeeName = customer.fullName
                    tx.customer = nil
                    syncManager.pushTransactionToCloud(tx)
                }
            }
            
            archiveCustomer(context: context, syncManager: syncManager)
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
    
    func archiveCustomer(context: ModelContext, syncManager: SyncManager) {
        customer.isActive = false
        customer.updatedAt = Date()
        try? context.save()
        syncManager.pushCustomerToCloud(customer)
    }
    
    func mergeCustomer(into targetCustomer: Customer, context: ModelContext, syncManager: SyncManager) {
        if let transactions = customer.transactions {
            let txsToUpdate = Array(transactions)
            for tx in txsToUpdate {
                tx.customer = targetCustomer
                syncManager.pushTransactionToCloud(tx)
            }
        }
        
        if !customer.notes.isEmpty {
            let prefix = targetCustomer.notes.isEmpty ? "" : targetCustomer.notes + "\n\n"
            targetCustomer.notes = prefix + "--- Merged from \(customer.fullName) ---\n" + customer.notes
            targetCustomer.updatedAt = Date()
            syncManager.pushCustomerToCloud(targetCustomer)
        }
        
        let oldId = customer.id.uuidString
        context.delete(customer)
        try? context.save()
        syncManager.deleteCustomerFromCloud(oldId)
    }
}

// MARK: - View

struct EditCustomerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncManager.self) private var syncManager
    @Environment(SessionManager.self) private var session
    
    @Query(sort: \CustomerStatus.name) private var allStatuses: [CustomerStatus]
    @Query(sort: \Customer.firstName) private var allCustomers: [Customer]
    
    @State private var viewModel: EditCustomerViewModel
    @State private var isShowingArchiveConfirm = false
    @State private var isShowingPromoteConfirm = false
    @State private var isShowingMergeSheet = false
    
    var onDelete: (() -> Void)? = nil
    
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    init(customer: Customer, onDelete: (() -> Void)? = nil) {
        self.onDelete = onDelete
        _viewModel = State(initialValue: EditCustomerViewModel(customer: customer))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.actionError.isEmpty {
                    Section {
                        Text(viewModel.actionError)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                
                if !viewModel.successMessage.isEmpty {
                    Section {
                        Text(viewModel.successMessage)
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }
                
                personalInfoSection
                contactInfoSection
                metadataSection
                
                if isAdmin {
                    adminActionsSection
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let success = await viewModel.saveChanges(context: modelContext, session: session, syncManager: syncManager)
                            if success { dismiss() }
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(!viewModel.isFormValid)
                }
            }
            .sheet(isPresented: $isShowingMergeSheet) {
                MergeCustomerSelectionView(sourceCustomer: viewModel.customer, allCustomers: allCustomers) { targetCustomer in
                    viewModel.mergeCustomer(into: targetCustomer, context: modelContext, syncManager: syncManager)
                    dismiss()
                    onDelete?()
                }
            }
            .alert("Promote to Employee?", isPresented: $isShowingPromoteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Promote") {
                    Task {
                        let success = await viewModel.promoteCustomer(session: session, context: modelContext, syncManager: syncManager)
                        if success {
                            dismiss()
                            onDelete?()
                        }
                    }
                }
            } message: {
                Text("This will grant them staff access and archive their customer directory listing.")
            }
            .alert("Archive Customer", isPresented: $isShowingArchiveConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Archive", role: .destructive) {
                    viewModel.archiveCustomer(context: modelContext, syncManager: syncManager)
                    dismiss()
                    onDelete?()
                }
            } message: {
                Text("Are you sure you want to archive \(viewModel.customer.firstName) \(viewModel.customer.lastName)?")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var personalInfoSection: some View {
        Section(header: Text("Personal Info")) {
            TextField("First Name", text: $viewModel.firstName).textContentType(.givenName)
            TextField("Last Name", text: $viewModel.lastName).textContentType(.familyName)
        }
    }
    
    private var contactInfoSection: some View {
        Section(header: Text("Contact Info")) {
            HStack {
                Image(systemName: "envelope").foregroundStyle(viewModel.isEmailValid ? .gray : .red)
                TextField("name@example.com", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            HStack {
                Image(systemName: "phone").foregroundStyle(.gray)
                TextField("e.g. +1 306 555 0199", text: $viewModel.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
        }
    }
    
    private var metadataSection: some View {
        Group {
            Section(header: Text("Membership")) {
                Picker("Status", selection: $viewModel.selectedStatus) {
                    Text("None Assigned").tag(CustomerStatus?.none)
                    ForEach(allStatuses) { status in
                        Text(status.name).tag(CustomerStatus?.some(status))
                    }
                }
            }
            
            Section(header: Text("Notes")) {
                TextField("Add any special notes here...", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
    }
    
    private var adminActionsSection: some View {
        Group {
            Section {
                Button {
                    Task {
                        do {
                            try await session.sendPasswordReset(to: viewModel.email)
                            viewModel.actionError = ""
                            withAnimation { viewModel.successMessage = "Password reset link sent to \(viewModel.email)." }
                        } catch {
                            viewModel.successMessage = ""
                            withAnimation { viewModel.actionError = error.localizedDescription }
                        }
                    }
                } label: {
                    Text("Send Password Reset Link")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.blue)
                }
                .disabled(!viewModel.isEmailValid || viewModel.email.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            Section {
                Button {
                    isShowingPromoteConfirm = true
                } label: {
                    Text("Promote to Employee")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
            
            Section(footer: Text("Merging moves all past transactions to a different customer and permanently deletes this profile.")) {
                Button {
                    isShowingMergeSheet = true
                } label: {
                    Text("Merge into Another Customer")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.orange)
                        .fontWeight(.semibold)
                }
            }
            
            Section {
                Button {
                    isShowingArchiveConfirm = true
                } label: {
                    Text("Archive Customer")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Merge Selection Subview

struct MergeCustomerSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let sourceCustomer: Customer
    let allCustomers: [Customer]
    let onMerge: (Customer) -> Void
    
    @State private var searchText = ""
    @State private var selectedTarget: Customer? = nil
    @State private var isShowingConfirm = false
    
    var filtered: [Customer] {
        let available = allCustomers.filter { $0.id != sourceCustomer.id && $0.isActive }
        if searchText.isEmpty { return available }
        return available.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List(filtered) { target in
                Button {
                    selectedTarget = target
                    isShowingConfirm = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(target.fullName).font(.headline).foregroundStyle(.primary)
                        if !target.email.isEmpty { Text(target.email).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search target customer...")
            .navigationTitle("Select Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Confirm Merge", isPresented: $isShowingConfirm, presenting: selectedTarget) { target in
                Button("Cancel", role: .cancel) { }
                Button("Merge Data", role: .destructive) {
                    onMerge(target)
                }
            } message: { target in
                Text("Are you sure you want to permanently move all transactions from \(sourceCustomer.fullName) to \(target.fullName) and delete \(sourceCustomer.firstName)'s profile?")
            }
        }
    }
}
