//
//  AddCustomerView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

/// Manages form state, validation, and multi-tenant data ingestion for new customers.
@MainActor
@Observable
final class AddCustomerViewModel {
    var firstName = ""
    var lastName = ""
    var email = ""
    var phone = ""
    var notes = ""
    var selectedStatus: CustomerStatus?
    
    var isEmailValid: Bool {
        if email.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        let emailRegex = /^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$/
        return email.wholeMatch(of: emailRegex) != nil
    }
    
    var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty && isEmailValid
    }
    
    /// Provisions a new customer and syncs it to the remote workspace.
    func saveCustomer(
        context: ModelContext,
        session: SessionManager,
        syncManager: SyncManager
    ) async -> Customer? {
        guard isFormValid else { return nil }
        
        let cleanedPhone = phone.formattedAsPhoneNumber
        // Safely unwrap activeStoreId, falling back to an empty string or default workspace identifier if unassigned
        let storeId = session.currentUser?.activeStoreId ?? ""
        
        let newCustomer = Customer(
            id: UUID(),
            storeId: storeId,
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            phone: cleanedPhone
        )
        
        newCustomer.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        newCustomer.isActive = true
        newCustomer.status = selectedStatus
        
        context.insert(newCustomer)
        try? context.save()
        
        await syncManager.pushCustomerToCloud(newCustomer)
        return newCustomer
    }
}

// MARK: - View

/// Provides the interface for provisioning new customers within the active tenant workspace.
struct AddCustomerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    @Query(sort: \CustomerStatus.name) private var allStatuses: [CustomerStatus]
    @State private var viewModel = AddCustomerViewModel()
    
    var onSave: ((Customer) -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                personalInfoSection
                contactInfoSection
                metadataSection
            }
            .scrollDismissesKeyboard(.automatic)
            .navigationTitle("New Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let customer = await viewModel.saveCustomer(
                                context: modelContext,
                                session: session,
                                syncManager: syncManager
                            ) {
                                onSave?(customer)
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(!viewModel.isFormValid)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var personalInfoSection: some View {
        Section(header: Text("Personal Info")) {
            TextField("First Name *", text: $viewModel.firstName)
                .textContentType(.givenName)
            
            TextField("Last Name", text: $viewModel.lastName)
                .textContentType(.familyName)
        }
    }
    
    private var contactInfoSection: some View {
        Section(
            header: Text("Contact Info"),
            footer: Text(viewModel.isEmailValid ? "" : "Please ensure email formats are correct.")
                .foregroundStyle(.red)
        ) {
            HStack {
                Image(systemName: "envelope")
                    .foregroundStyle(viewModel.isEmailValid ? .gray : .red)
                TextField("name@example.com", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            HStack {
                Image(systemName: "phone")
                    .foregroundStyle(.gray)
                TextField("e.g. +1 306 555 5555", text: $viewModel.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
        }
    }
    
    private var metadataSection: some View {
        Group {
            Section(header: Text("Customer")) {
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
}
