//
//  CustomerListView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// The primary CRM directory, supporting multi-tenant search, filtering, and administrative archiving.
struct CustomerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var session
    
    @Query(sort: \Customer.lastName) private var allCustomers: [Customer]
    @Query(sort: \CustomerStatus.name) private var allStatuses: [CustomerStatus]
    
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var isShowingAddSheet = false
    @State private var selectedFilterStatuses: Set<CustomerStatus> = []
    
    /// Securely verifies administrative capabilities via the multi-tenant `AppUser` model.
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    var activeCustomers: [Customer] {
        allCustomers.filter { $0.isActive }
    }
    
    var isFilterActive: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty || !selectedFilterStatuses.isEmpty
    }
    
    var filteredCustomers: [Customer] {
        var customers = activeCustomers
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            customers = customers.filter { customer in
                customer.fullName.localizedCaseInsensitiveContains(searchText) ||
                customer.email.localizedCaseInsensitiveContains(searchText) ||
                customer.phone.localizedCaseInsensitiveContains(searchText)
            }
        }
        if !selectedFilterStatuses.isEmpty {
            customers = customers.filter { customer in
                guard let status = customer.status else { return false }
                return selectedFilterStatuses.contains(status)
            }
        }
        return customers
    }
    
    var body: some View {
        VStack(spacing: 0) {
            CustomerFilterBarView(
                searchText: $searchText,
                selectedFilterStatuses: $selectedFilterStatuses,
                allStatuses: allStatuses,
                isFilterActive: isFilterActive
            )
            
            List {
                if filteredCustomers.isEmpty {
                    Text(isFilterActive ? "No matching customers found." : "No active customers found.")
                        .foregroundStyle(.secondary)
                        .italic()
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredCustomers) { customer in
                        NavigationLink(destination: CustomerDetailView(customer: customer)) {
                            CustomerCardRowView(customer: customer)
                        }
                        .modifier(AdminCustomerActionModifier(isAdmin: isAdmin, customer: customer) {
                            archiveCustomer(customer)
                        })
                    }
                }
            }
        }
        .navigationTitle("Customers")
        .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search customer name, email, phone...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    if isAdmin {
                        NavigationLink(destination: ArchivedCustomersView()) {
                            Image(systemName: "archivebox")
                        }
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
    }
    
    private func archiveCustomer(_ customer: Customer) {
        guard isAdmin else { return }
        customer.isActive = false
        customer.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Helper Modifiers

/// Restricts destructive swipe actions to strictly verified administrators.
private struct AdminCustomerActionModifier: ViewModifier {
    let isAdmin: Bool
    let customer: Customer
    let onArchive: () -> Void
    
    func body(content: Content) -> some View {
        if isAdmin {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { onArchive() }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(.red)
                }
        } else {
            content
        }
    }
}

// MARK: - Customer Card Component

struct CustomerCardRowView: View {
    let customer: Customer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(customer.fullName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if let status = customer.status {
                    TagPillView(name: status.name)
                }
            }
            
            if !customer.email.isEmpty || !customer.phone.isEmpty {
                HStack(spacing: 12) {
                    if !customer.email.isEmpty {
                        Label(customer.email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    if !customer.phone.isEmpty {
                        Label(customer.phone, systemImage: "phone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Component

struct CustomerFilterBarView: View {
    @Environment(\.dismissSearch) private var dismissSearch
    @Binding var searchText: String
    @Binding var selectedFilterStatuses: Set<CustomerStatus>
    
    let allStatuses: [CustomerStatus]
    let isFilterActive: Bool
    
    var body: some View {
        if !allStatuses.isEmpty || isFilterActive {
            HStack(spacing: 0) {
                if isFilterActive {
                    Button {
                        withAnimation {
                            searchText = ""
                            dismissSearch()
                            selectedFilterStatuses.removeAll()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear")
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 10)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    
                    Divider()
                        .frame(height: 20)
                        .padding(.leading, 12)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(allStatuses) { status in
                            let isSelected = selectedFilterStatuses.contains(status)
                            Button {
                                withAnimation {
                                    if isSelected {
                                        selectedFilterStatuses.remove(status)
                                    } else {
                                        selectedFilterStatuses.insert(status)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                    }
                                    Text(status.name)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? colorForStatus(status.name) : Color(uiColor: .secondarySystemBackground))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.leading, isFilterActive ? 12 : 16)
                    .padding(.trailing, 16)
                    .padding(.vertical, 10)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 3)
            .animation(.default, value: isFilterActive)
            .animation(.default, value: selectedFilterStatuses)
        }
    }
    
    private func colorForStatus(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .indigo, .teal]
        let stableHash = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[stableHash % colors.count]
    }
}
