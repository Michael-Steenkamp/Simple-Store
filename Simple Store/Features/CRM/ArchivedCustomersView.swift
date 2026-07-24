//
//  ArchivedCustomersView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-21.
//

import SwiftUI
import SwiftData

struct ArchivedCustomersView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]
    
    var archivedCustomers: [Customer] {
        // Filters out customers that have been "scrubbed" and permanently deleted
        allCustomers.filter { !$0.isActive && $0.firstName != "Deleted" }
    }
    
    var body: some View {
        List {
            if archivedCustomers.isEmpty {
                Text("No archived customers.")
                    .foregroundColor(.secondary)
                    .italic()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(archivedCustomers) { customer in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.fullName)
                            .font(.headline)
                        
                        if !customer.email.isEmpty {
                            Text(customer.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            withAnimation {
                                restoreCustomer(customer)
                            }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation {
                                permanentlyDelete(customer)
                            }
                        } label: {
                            Label("Delete Forever", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            withAnimation {
                                restoreCustomer(customer)
                            }
                        } label: {
                            Label("Restore Customer", systemImage: "arrow.uturn.backward")
                        }
                        
                        Button(role: .destructive) {
                            withAnimation {
                                permanentlyDelete(customer)
                            }
                        } label: {
                            Label("Delete Forever", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Archived Customers")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func restoreCustomer(_ customer: Customer) {
        customer.isActive = true
        customer.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func permanentlyDelete(_ customer: Customer) {
        // Scrub the data to anonymize the record and preserve transaction history
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
