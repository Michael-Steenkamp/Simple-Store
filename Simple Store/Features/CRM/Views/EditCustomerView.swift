//
//  EditCustomerView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-19.
//

import SwiftUI
import SwiftData

struct EditCustomerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Environment(SyncManager.self) private var syncManager
    @Environment(SessionManager.self) private var session
    
    let customer: Customer
    @Query(sort: \CustomerStatus.name) private var allStatuses: [CustomerStatus]
    
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var phone: String
    @State private var notes: String
    @State private var selectedStatus: CustomerStatus?
    
    @State private var isShowingArchiveConfirm = false
    @State private var isShowingPromoteConfirm = false
    @State private var actionError = ""
    
    var onDelete: (() -> Void)? = nil
    
    var isEmailValid: Bool {
        if email.isEmpty { return false }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty && isEmailValid
    }
    
    init(customer: Customer, onDelete: (() -> Void)? = nil) {
        self.customer = customer
        self.onDelete = onDelete
        _firstName = State(initialValue: customer.firstName)
        _lastName = State(initialValue: customer.lastName)
        _email = State(initialValue: customer.email)
        _phone = State(initialValue: customer.phone)
        _notes = State(initialValue: customer.notes)
        _selectedStatus = State(initialValue: customer.status)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if !actionError.isEmpty {
                    Section { Text(actionError).font(.subheadline).foregroundColor(.red) }
                }
                
                Section(header: Text("Personal Info")) {
                    TextField("First Name", text: $firstName).textContentType(.givenName)
                    TextField("Last Name", text: $lastName).textContentType(.familyName)
                }
                
                Section(header: Text("Contact Info")) {
                    HStack {
                        Image(systemName: "envelope").foregroundColor(isEmailValid ? .gray : .red)
                        TextField("name@example.com (Required)", text: $email)
                            .keyboardType(.emailAddress).textContentType(.emailAddress).autocorrectionDisabled().textInputAutocapitalization(.never)
                    }
                    HStack {
                        Image(systemName: "phone").foregroundColor(.gray)
                        TextField("e.g. +1 306 555 0199", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                    }
                }
                
                Section(header: Text("Membership")) {
                    Picker("Status", selection: $selectedStatus) {
                        Text("None Assigned").tag(CustomerStatus?.none)
                        ForEach(allStatuses) { status in
                            Text(status.name).tag(CustomerStatus?.some(status))
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Add any special notes here...", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                
                // MARK: - Admin-Only Destructive Actions
                if session.currentUser?.role == .admin {
                    Section {
                        Button(action: { isShowingPromoteConfirm = true }) {
                            Text("Promote to Employee")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Section {
                        Button(action: { isShowingArchiveConfirm = true }) {
                            Text("Archive Customer")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }.fontWeight(.bold).disabled(!isFormValid)
                }
            }
            .alert("Promote to Employee?", isPresented: $isShowingPromoteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Promote") { promoteCustomer() }
            } message: { Text("This will grant them staff access and archive their customer directory listing.") }
            .alert("Archive Customer", isPresented: $isShowingArchiveConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Archive", role: .destructive) { archiveCustomer() }
            } message: { Text("Are you sure you want to archive \(customer.firstName) \(customer.lastName)?") }
        }
    }
    
    private func saveChanges() {
        customer.firstName = firstName.trimmingCharacters(in: .whitespaces)
        customer.lastName = lastName.trimmingCharacters(in: .whitespaces)
        customer.email = email.trimmingCharacters(in: .whitespaces)
        customer.phone = phone.formattedAsPhoneNumber()
        customer.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        customer.status = selectedStatus
        customer.updatedAt = Date()
        
        try? modelContext.save()
        Task { await syncManager.pushCustomerToCloud(customer) }
        dismiss()
    }
    
    private func promoteCustomer() {
        actionError = ""
        Task {
            do {
                try await session.promoteCustomerToEmployee(customerEmail: customer.email, customerName: customer.fullName)
                archiveCustomer() // Soft-delete their customer profile after promoting
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
    
    private func archiveCustomer() {
        customer.isActive = false
        customer.updatedAt = Date()
        try? modelContext.save()
        Task { await syncManager.pushCustomerToCloud(customer) }
        dismiss()
        onDelete?()
    }
}
