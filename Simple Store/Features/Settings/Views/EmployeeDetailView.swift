//
//  EmployeeDetailView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

@MainActor
@Observable
final class EmployeeDetailViewModel {
    var editName = ""
    var editEmail = ""
    var editPhone = ""
    
    var isShowingDemoteConfirm = false
    var actionError = ""
    var isEditing = false
    
    func populate(from employee: Employee) {
        editName = employee.name
        editEmail = employee.email ?? ""
        editPhone = employee.phone ?? ""
    }
    
    func saveChanges(employee: Employee, context: ModelContext, session: SessionManager, syncManager: SyncManager) async -> Bool {
        let cleanedEmail = editEmail.trimmingCharacters(in: .whitespaces).lowercased()
        
        if cleanedEmail != employee.email?.lowercased() && !cleanedEmail.isEmpty {
            let emailExists = await session.isEmailRegistered(email: cleanedEmail)
            if emailExists {
                actionError = "This email is already registered to another user."
                return false
            }
        }
        
        employee.name = editName.trimmingCharacters(in: .whitespaces)
        employee.email = cleanedEmail.isEmpty ? nil : cleanedEmail
        employee.phone = editPhone.formattedAsPhoneNumber.isEmpty ? nil : editPhone.formattedAsPhoneNumber
        
        try? context.save()
        syncManager.pushEmployeeToCloud(employee)
        isEditing = false
        return true
    }
    
    func demoteEmployee(
        employee: Employee,
        session: SessionManager,
        context: ModelContext,
        syncManager: SyncManager,
        allTransactions: [Transaction]
    ) async -> Bool {
        actionError = ""
        do {
            let newCustId = try await session.demoteEmployeeToCustomer(employeeName: employee.name)
            
            let custDescriptor = FetchDescriptor<Customer>(predicate: #Predicate { $0.id.uuidString == newCustId })
            let targetCustomer = try context.fetch(custDescriptor).first
            
            let userTxs = allTransactions.filter { $0.buyerEmployeeId == employee.id.uuidString }
            for tx in userTxs {
                tx.customer = targetCustomer
                tx.buyerEmployeeId = nil
                tx.buyerEmployeeName = nil
                syncManager.pushTransactionToCloud(tx)
            }
            
            employee.isActive = false
            try? context.save()
            syncManager.pushEmployeeToCloud(employee)
            
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
}

// MARK: - View

/// An interface for viewing and editing staff contact data, alongside filtering their personal purchase history.
struct EmployeeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    @Query private var allTransactions: [Transaction]
    
    let employee: Employee
    @State private var viewModel = EmployeeDetailViewModel()
    
    @State private var selectedTab: OrderFilterTab = .all
    @State private var orderSearchText = ""
    
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    private var isSelf: Bool {
        employee.name == session.currentUser?.name
    }
    
    var filteredTransactions: [Transaction] {
        var txs = allTransactions.filter { $0.buyerEmployeeId == employee.id.uuidString }
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedTab {
        case .week:
            if let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start {
                txs = txs.filter { $0.date >= start }
            }
        case .month:
            if let start = calendar.dateInterval(of: .month, for: now)?.start {
                txs = txs.filter { $0.date >= start }
            }
        case .year:
            if let start = calendar.dateInterval(of: .year, for: now)?.start {
                txs = txs.filter { $0.date >= start }
            }
        case .all:
            break
        }
        
        if !orderSearchText.isEmpty {
            txs = txs.filter { tx in
                let matchAmount = tx.totalAmount.formatted(.currency(code: "CAD")).contains(orderSearchText)
                let matchDate = tx.date.formatted(date: .abbreviated, time: .shortened).contains(orderSearchText)
                let matchItem = tx.lineItems?.contains { $0.itemName.localizedCaseInsensitiveContains(orderSearchText) } ?? false
                return matchAmount || matchDate || matchItem
            }
        }
        
        return txs.sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        Form {
            if !viewModel.actionError.isEmpty {
                Section {
                    Text(viewModel.actionError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            
            Section(header: Text("Directory Profile")) {
                if viewModel.isEditing {
                    TextField("Full Name", text: $viewModel.editName).textContentType(.name)
                    TextField("Contact Email", text: $viewModel.editEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField("Contact Phone", text: $viewModel.editPhone).keyboardType(.phonePad)
                } else {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(employee.name).foregroundStyle(.secondary)
                    }
                    if let email = employee.email, !email.isEmpty {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email).foregroundStyle(.secondary)
                        }
                    }
                    if let phone = employee.phone, !phone.isEmpty {
                        HStack {
                            Text("Phone")
                            Spacer()
                            Text(phone).foregroundStyle(.secondary)
                        }
                    }
                }
                
                HStack {
                    Text("System ID")
                    Spacer()
                    Text(employee.id.uuidString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            if isAdmin && !isSelf {
                Section(footer: Text("Demoting will move this user to the Customer Directory and revoke their staff access.")) {
                    Button {
                        viewModel.isShowingDemoteConfirm = true
                    } label: {
                        Text("Demote to Customer")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            orderHistorySection
        }
        .navigationTitle(viewModel.isEditing ? "Edit Staff Info" : "Staff Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isEditing)
        .toolbar {
            if isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isEditing {
                        Button("Save") {
                            Task {
                                _ = await viewModel.saveChanges(employee: employee, context: modelContext, session: session, syncManager: syncManager)
                            }
                        }
                        .fontWeight(.bold)
                        .disabled(viewModel.editName.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        Button("Edit") {
                            withAnimation { viewModel.isEditing = true }
                        }
                    }
                }
                if viewModel.isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            withAnimation { viewModel.isEditing = false }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.populate(from: employee)
        }
        .alert("Demote to Customer?", isPresented: $viewModel.isShowingDemoteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Demote", role: .destructive) {
                Task {
                    let success = await viewModel.demoteEmployee(
                        employee: employee,
                        session: session,
                        context: modelContext,
                        syncManager: syncManager,
                        allTransactions: allTransactions
                    )
                    if success { dismiss() }
                }
            }
        } message: {
            Text("Are you sure? They will lose access to the inventory manager, settings, and POS checkout.")
        }
    }
    
    // MARK: - Subviews
    
    private var orderHistorySection: some View {
        Section(header: Text("Order History")) {
            GlassSalesFilterView(selectedTab: $selectedTab, searchText: $orderSearchText)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 16, trailing: 0))
                .listRowSeparator(.hidden)
            
            if filteredTransactions.isEmpty {
                Text("No orders match this criteria.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(filteredTransactions) { transaction in
                    NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                        transactionCard(for: transaction)
                    }
                }
            }
        }
    }
    
    private func transactionCard(for transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    let itemCount = transaction.lineItems?.reduce(0) { $0 + $1.quantity } ?? 0
                    Text("\(itemCount) items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(transaction.totalAmount, format: .currency(code: "CAD"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let payments = transaction.payments {
                        let methods = Set(payments.map { $0.method }).joined(separator: ", ")
                        Text(methods)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
