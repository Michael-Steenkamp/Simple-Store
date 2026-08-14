//
//  ArchivedCustomersView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// Displays a list of soft-deleted customers and provides administrative data restoration or permanent anonymization capabilities.
struct ArchivedCustomersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]
    
    /// Filters out customers that have been permanently anonymized/scrubbed.
    var archivedCustomers: [Customer] {
        allCustomers.filter { !$0.isActive && $0.firstName != "Deleted" }
    }
    
    var body: some View {
        List {
            if archivedCustomers.isEmpty {
                Text("No archived customers.")
                    .foregroundStyle(.secondary)
                    .italic()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(archivedCustomers) { customer in
                    customerRow(customer)
                }
            }
        }
        .navigationTitle("Archived Customers")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Subviews
    
    private func customerRow(_ customer: Customer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(customer.fullName)
                .font(.headline)
            
            if !customer.email.isEmpty {
                Text(customer.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { restoreCustomer(customer) }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { permanentlyDelete(customer) }
            } label: {
                Label("Delete Forever", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                withAnimation { restoreCustomer(customer) }
            } label: {
                Label("Restore Customer", systemImage: "arrow.uturn.backward")
            }
            
            Button(role: .destructive) {
                withAnimation { permanentlyDelete(customer) }
            } label: {
                Label("Delete Forever", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Data Operations
    
    private func restoreCustomer(_ customer: Customer) {
        customer.isActive = true
        customer.updatedAt = Date()
        try? modelContext.save()
    }
    
    /// Scrubs personally identifiable information (PII) to anonymize the record while preserving relational transaction history.
    private func permanentlyDelete(_ customer: Customer) {
        customer.firstName = "Deleted"
        customer.lastName = "Customer"
        customer.email = ""
        customer.phone = ""
        customer.notes = ""
        customer.status = nil
        customer.isActive = false
        try? modelContext.save()
    }
}
