//
//  CustomerSelectionView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// Provides a searchable interface to associate a specific CRM profile with an active POS transaction.
struct CustomerSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]
    
    @Binding var selectedCustomer: Customer?
    
    @State private var searchText = ""
    @State private var isShowingAddCustomer = false
    
    var activeCustomers: [Customer] {
        allCustomers.filter { $0.isActive }
    }
    
    var filteredCustomers: [Customer] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return activeCustomers
        } else {
            return activeCustomers.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var recentCustomers: [Customer] {
        Array(activeCustomers.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(3))
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedCustomer = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("Walk-in (No Profile)")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCustomer == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                if searchText.isEmpty && !recentCustomers.isEmpty {
                    Section("Recent Customers") {
                        ForEach(recentCustomers) { customer in
                            customerRow(for: customer)
                        }
                    }
                }
                
                Section(searchText.isEmpty ? "All Customers" : "Search Results") {
                    if filteredCustomers.isEmpty {
                        Text("No customers found.")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(filteredCustomers) { customer in
                            customerRow(for: customer)
                        }
                    }
                }
            }
            .navigationTitle("Select Customer")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by name...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddCustomer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddCustomer) {
                AddCustomerView { newCustomer in
                    self.selectedCustomer = newCustomer
                    self.dismiss()
                }
            }
        }
    }
    
    private func customerRow(for customer: Customer) -> some View {
        Button {
            selectedCustomer = customer
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(customer.fullName)
                        .foregroundStyle(.primary)
                    if let status = customer.status {
                        Text(status.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selectedCustomer?.id == customer.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}
