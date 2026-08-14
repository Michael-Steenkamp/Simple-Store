//
//  EditCustomerView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

/// Manages form mutations, data validation, and network synchronization for existing customer profiles.
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
    
    func saveChanges(context: ModelContext, syncManager: SyncManager) async {
        customer.firstName = firstName.trimmingCharacters(in: .whitespaces)
        customer.lastName = lastName.trimmingCharacters(in: .whitespaces)
        customer.email = email.trimmingCharacters(in: .whitespaces)
        customer.phone = phone.formattedAsPhoneNumber
        customer.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.status = selectedStatus
        customer.updatedAt = Date()
        
        try? context.save()
        await syncManager.pushCustomerToCloud(customer)
    }
    
    func promoteCustomer(session: SessionManager, context: ModelContext, syncManager: SyncManager) async -> Bool {
        actionError = ""
        do {
            try await session.promoteCustomerToEmployee(customerEmail: customer.email, customerName: customer.fullName)
            await archiveCustomer(context: context, syncManager: syncManager)
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
    
    func archiveCustomer(context: ModelContext, syncManager: SyncManager) async {
        customer.isActive = false
        customer.updatedAt = Date()
        try? context.save()
        await syncManager.pushCustomerToCloud(customer)
    }
}

// MARK: - View

/// Provides the interface for editing customer metadata, assigning statuses, and executing administrative actions.
struct EditCustomerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncManager.self) private var syncManager
    @Environment(SessionManager.self) private var session
    
    @Query(sort: \CustomerStatus.name) private var allStatuses: [CustomerStatus]
    
    @State private var viewModel: EditCustomerViewModel
    @State private var isShowingArchiveConfirm = false
    @State private var isShowingPromoteConfirm = false
    
    var onDelete: (() -> Void)? = nil
    
    /// Determines if the current user possesses multi-tenant administrative privileges.
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
                            await viewModel.saveChanges(context: modelContext, syncManager: syncManager)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(!viewModel.isFormValid)
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
                    Task {
                        await viewModel.archiveCustomer(context: modelContext, syncManager: syncManager)
                        dismiss()
                        onDelete?()
                    }
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
                TextField("name@example.com (Required)", text: $viewModel.email)
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
                    isShowingPromoteConfirm = true
                } label: {
                    Text("Promote to Employee")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.blue)
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
