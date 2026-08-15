//
//  OrderListView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

@MainActor
@Observable
final class OrderListViewModel {
    var searchText = ""
    var isSearchFocused = false
    
    var transactionToRevert: Transaction?
    var isShowingRevertAlert = false
    
    func revertTransaction(transaction: Transaction, allItems: [StoreItem], context: ModelContext, syncManager: SyncManager) {
        var restoredItems: [StoreItem] = []
        
        if let lineItems = transaction.lineItems {
            for lineItem in lineItems {
                if let storeItem = allItems.first(where: { $0.id.uuidString == lineItem.itemID }) {
                    storeItem.stockCount += lineItem.quantity
                    restoredItems.append(storeItem)
                }
            }
        }
        
        let txId = transaction.id.uuidString
        context.delete(transaction)
        try? context.save()
        
        syncManager.deleteTransactionFromCloud(txId)
        for item in restoredItems {
            syncManager.pushItemToCloud(item)
        }
    }
    
    func shareReceipt(for transaction: Transaction) {
        if let email = transaction.customer?.email, !email.trimmingCharacters(in: .whitespaces).isEmpty {
            UIPasteboard.general.string = email
        }
        
        guard let url = ReceiptRenderer.generatePDF(for: transaction) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: \.isKeyWindow),
           let rootVC = window.rootViewController {
            
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - View

struct OrderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(SessionManager.self) private var session
    
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allItems: [StoreItem]
    
    @State private var viewModel = OrderListViewModel()
    @AppStorage("hasDiscoveredSwipe") private var hasDiscoveredSwipe = false
    
    /// Securely verifies administrative capabilities via the multi-tenant `AppUser` model.
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    var filteredTransactions: [Transaction] {
        if viewModel.searchText.isEmpty {
            return allTransactions
        } else {
            return allTransactions.filter { transaction in
                let customerMatch = transaction.customer?.fullName.localizedCaseInsensitiveContains(viewModel.searchText) ?? false
                let employeeMatch = transaction.employeeName?.localizedCaseInsensitiveContains(viewModel.searchText) ?? false
                return customerMatch || employeeMatch
            }
        }
    }
    
    var body: some View {
        if !hasDiscoveredSwipe {
            HStack {
                Image(systemName: "hand.draw.fill")
                Text("Swipe items left or right for quick actions.")
                    .font(.footnote)
                Spacer()
                Button {
                    withAnimation { hasDiscoveredSwipe = true }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
            
        List {
            if filteredTransactions.isEmpty {
                Text(viewModel.searchText.isEmpty ? "No orders found." : "No results for '\(viewModel.searchText)'")
                    .foregroundStyle(.secondary)
                    .italic()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredTransactions) { transaction in
                    NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                        transactionRow(transaction)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            viewModel.shareReceipt(for: transaction)
                        } label: {
                            Label("Receipt", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                    .modifier(AdminTransactionActionModifier(
                        isAdmin: isAdmin,
                        transaction: transaction,
                        onShare: { viewModel.shareReceipt(for: transaction) },
                        onRevert: {
                            viewModel.transactionToRevert = transaction
                            viewModel.isShowingRevertAlert = true
                        }
                    ))
                }
            }
        }
        .navigationTitle("Order Directory")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, isPresented: $viewModel.isSearchFocused, prompt: "Search Customer or Employee...")
        .sensoryFeedback(.success, trigger: allTransactions.count)
        .alert("Revert Order", isPresented: $viewModel.isShowingRevertAlert, presenting: viewModel.transactionToRevert) { transaction in
            Button("Cancel", role: .cancel) { }
            Button("Revert Order", role: .destructive) {
                viewModel.revertTransaction(transaction: transaction, allItems: allItems, context: modelContext, syncManager: syncManager)
            }
        } message: { transaction in
            Text("Are you sure you want to revert this order? This will permanently delete the transaction and return the purchased items to your active stock.")
        }
    }
    
    private func transactionRow(_ transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text(transaction.totalAmount, format: .currency(code: "CAD"))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            HStack {
                if let customer = transaction.customer {
                    Text(customer.fullName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Text("Walk-in")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                let itemCount = transaction.lineItems?.reduce(0) { $0 + $1.quantity } ?? 0
                Text("\(itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Admin Helper Modifier

struct AdminTransactionActionModifier: ViewModifier {
    let isAdmin: Bool
    let transaction: Transaction
    let onShare: () -> Void
    let onRevert: () -> Void
    
    func body(content: Content) -> some View {
        if isAdmin {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { onRevert() } label: {
                        Label("Revert", systemImage: "arrow.uturn.backward")
                    }
                }
                .contextMenu {
                    Button { onShare() } label: {
                        Label("Share Receipt", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { onRevert() } label: {
                        Label("Revert Order", systemImage: "arrow.uturn.backward")
                    }
                }
        } else {
            content
                .contextMenu {
                    Button { onShare() } label: {
                        Label("Share Receipt", systemImage: "square.and.arrow.up")
                    }
                }
        }
    }
}
