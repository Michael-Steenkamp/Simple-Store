//
//  AddCustomerView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-19.
//

import SwiftUI
import SwiftData

struct AddCustomerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \CustomerStatus.name) private var allStatuses: [CustomerStatus]
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var notes = ""
    @State private var selectedStatus: CustomerStatus?
    
    var onSave: ((Customer) -> Void)? = nil
    
    var isEmailValid: Bool {
        if email.isEmpty { return false }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty && isEmailValid
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Personal Info")) {
                    TextField("First Name *", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }
                
                Section(
                    header: Text("Contact Info"),
                    footer: Text(isEmailValid ? "" : "Please ensure email formats are correct.")
                        .foregroundColor(.red)
                ) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(isEmailValid ? .gray : .red)
                        TextField("name@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(.gray)
                        
                        TextField("e.g. +1 306 555 5555", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                }
                
                Section(header: Text("Customer")) {
                    Picker("Status", selection: $selectedStatus) {
                        Text("None Assigned").tag(CustomerStatus?.none)
                        ForEach(allStatuses) { status in
                            Text(status.name).tag(CustomerStatus?.some(status))
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Add any special notes here...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleanedPhone = phone.formattedAsPhoneNumber()
                        
                        let newCustomer = Customer(
                            firstName: firstName.trimmingCharacters(in: .whitespaces),
                            lastName: lastName.trimmingCharacters(in: .whitespaces),
                            email: email.trimmingCharacters(in: .whitespaces),
                            phone: cleanedPhone,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        newCustomer.isActive = true
                        
                        modelContext.insert(newCustomer)
                        newCustomer.status = selectedStatus
                        try? modelContext.save()
                        
                        onSave?(newCustomer)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!isFormValid)
                }
            }
        }
    }
}
