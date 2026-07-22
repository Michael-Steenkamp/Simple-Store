//
//  CustomerListView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-19.
//

import SwiftUI
import SwiftData

struct CustomerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]
    
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var isShowingAddSheet = false
    
    var activeCustomers: [Customer] {
        allCustomers.filter { $0.isActive }
    }
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return activeCustomers
        } else {
            return activeCustomers.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            if filteredCustomers.isEmpty {
                Text(searchText.isEmpty ? "No active customers found." : "No results for '\(searchText)'")
                    .foregroundColor(.secondary)
                    .italic()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredCustomers) { customer in
                    NavigationLink(destination: CustomerDetailView(customer: customer)) {
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
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            archiveCustomer(customer)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .navigationTitle("Customers")
        .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search name...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    NavigationLink(destination: ArchivedCustomersView()) {
                        Image(systemName: "archivebox")
                    }
                    
                    Button(action: { isShowingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddCustomerView()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .global)
                .onEnded { value in
                    let w = value.translation.width
                    let h = value.translation.height
                    if h > 120 && abs(w) < 50 {
                        isSearchFocused = true
                    }
                }
        )
    }
    
    private func archiveCustomer(_ customer: Customer) {
        customer.isActive = false
        customer.updatedAt = Date()
        try? modelContext.save()
    }
}
