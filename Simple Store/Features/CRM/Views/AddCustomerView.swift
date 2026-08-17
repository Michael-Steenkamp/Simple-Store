//
//  AddCustomerView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

/// Manages form state, validation, and local data ingestion for new customers.
@MainActor
@Observable
final class AddCustomerViewModel {
    var firstName = ""
    var lastName = ""
    var email = ""
    var phone = ""
    var notes = ""
    var selectedStatus: CustomerStatus?
    
    var createAuthAccount = false
    var isProcessing = false
    var errorMessage = ""
    
    var isEmailValid: Bool {
        if email.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        let emailRegex = /^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$/
        return email.wholeMatch(of: emailRegex) != nil
    }
    
    var isFormValid: Bool {
        let hasName = !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        if createAuthAccount {
            let hasEmail = !email.trimmingCharacters(in: .whitespaces).isEmpty
            return hasName && isEmailValid && hasEmail
        }
        return hasName && isEmailValid
    }
    
    func saveCustomer(
        context: ModelContext,
        session: SessionManager,
        syncManager: SyncManager
    ) async -> Customer? {
        guard isFormValid else { return nil }
        
        isProcessing = true
        errorMessage = ""
        defer { isProcessing = false }
        
        let cleanedPhone = phone.formattedAsPhoneNumber
        let storeId = session.currentUser?.activeStoreId ?? ""
        let cleanedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let cleanedFirstName = firstName.trimmingCharacters(in: .whitespaces)
        let cleanedLastName = lastName.trimmingCharacters(in: .whitespaces)
        
        // Prevent CRM duplicates before generating tokens or local records.
        if !cleanedEmail.isEmpty {
            // Offline Protection: Check Local SwiftData Context
            let fetchDescriptor = FetchDescriptor<Customer>()
            if let allLocalCustomers = try? context.fetch(fetchDescriptor) {
                if allLocalCustomers.contains(where: { $0.email.lowercased() == cleanedEmail }) {
                    errorMessage = "This email is already registered to another local customer."
                    return nil
                }
            }
            
            // Online Protection: Check Firestore
            let emailExists = await session.isEmailRegistered(email: cleanedEmail)
            if emailExists {
                errorMessage = "This email is already registered to another user in this store."
                return nil
            }
        }
        
        if createAuthAccount {
            do {
                try await session.provisionSystemAccount(
                    email: cleanedEmail,
                    firstName: cleanedFirstName,
                    lastName: cleanedLastName,
                    phone: cleanedPhone,
                    role: .customer
                )
            } catch {
                errorMessage = "Failed to create login credentials. (\(error.localizedDescription))"
                return nil
            }
        }
        
        let newCustomer = Customer(
            id: UUID(),
            storeId: storeId,
            firstName: cleanedFirstName,
            lastName: cleanedLastName,
            email: cleanedEmail,
            phone: cleanedPhone
        )
        
        newCustomer.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        newCustomer.isActive = true
        newCustomer.status = selectedStatus
        
        context.insert(newCustomer)
        try? context.save()
        
        syncManager.pushCustomerToCloud(newCustomer)
        return newCustomer
    }
}

// MARK: - View

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
                if !viewModel.errorMessage.isEmpty {
                    Section {
                        Text(viewModel.errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                
                personalInfoSection
                contactInfoSection
                metadataSection
                authProvisioningSection
            }
            .scrollDismissesKeyboard(.automatic)
            .navigationTitle("New Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
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
                    } label: {
                        if viewModel.isProcessing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save").fontWeight(.bold)
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isProcessing)
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
                TextField(viewModel.createAuthAccount ? "name@example.com *" : "name@example.com", text: $viewModel.email)
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
    
    private var authProvisioningSection: some View {
        Section(footer: Text("If enabled, this customer will instantly be emailed a secure link to create a password and log into the app to view their receipts.")) {
            Toggle("Create App Login", isOn: $viewModel.createAuthAccount.animation(.snappy))
        }
    }
}
