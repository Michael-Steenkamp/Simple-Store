//
//  OrderListView.swift
//  Simple Inventory
//

import SwiftUI
import SwiftData

struct OrderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allItems: [StoreItem]
    
    @State private var searchText = ""
    @State private var isSearchFocused = false
    
    @State private var transactionToRevert: Transaction?
    @State private var isShowingRevertAlert = false
    
    @AppStorage("hasDiscoveredSwipe") private var hasDiscoveredSwipe = false
    
    var filteredTransactions: [Transaction] {
        if searchText.isEmpty {
            return allTransactions
        } else {
            return allTransactions.filter { transaction in
                let customerMatch = transaction.customer?.fullName.localizedCaseInsensitiveContains(searchText) ?? false
                let employeeMatch = transaction.employeeName?.localizedCaseInsensitiveContains(searchText) ?? false
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
                Button(action: { withAnimation { hasDiscoveredSwipe = true } }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
            
        List {
            if filteredTransactions.isEmpty {
                Text(searchText.isEmpty ? "No orders found." : "No results for '\(searchText)'")
                    .foregroundColor(.secondary)
                    .italic()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredTransactions) { transaction in
                    NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                        transactionRow(transaction)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            shareReceipt(for: transaction)
                        } label: {
                            Label("Receipt", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            transactionToRevert = transaction
                            isShowingRevertAlert = true
                        } label: {
                            Label("Revert", systemImage: "arrow.uturn.backward")
                        }
                    }
                    .contextMenu {
                        Button {
                            shareReceipt(for: transaction)
                        } label: {
                            Label("Share Receipt", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive) {
                            transactionToRevert = transaction
                            isShowingRevertAlert = true
                        } label: {
                            Label("Revert Order", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
        }
        .navigationTitle("Order Directory")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search Customer or Employee...")
        // QoL: Impact haptic when order is successfully reverted
        .sensoryFeedback(.success, trigger: allTransactions.count)
        .alert("Revert Order", isPresented: $isShowingRevertAlert, presenting: transactionToRevert) { transaction in
            Button("Cancel", role: .cancel) { }
            
            Button("Revert Order", role: .destructive) {
                withAnimation {
                    revertTransaction(transaction)
                }
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
                    .foregroundColor(.primary)
            }
            
            HStack {
                if let customer = transaction.customer {
                    Text(customer.fullName)
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Walk-in")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                let itemCount = transaction.lineItems?.reduce(0) { $0 + $1.quantity } ?? 0
                Text("\(itemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func revertTransaction(_ transaction: Transaction) {
        if let lineItems = transaction.lineItems {
            for lineItem in lineItems {
                if let storeItem = allItems.first(where: { $0.id.uuidString == lineItem.itemID }) {
                    storeItem.stockCount += lineItem.quantity
                }
            }
        }
        modelContext.delete(transaction)
        try? modelContext.save()
    }
    
    // shareReceipt function remains unchanged...
    private func shareReceipt(for transaction: Transaction) {
        if let email = transaction.customer?.email, !email.trimmingCharacters(in: .whitespaces).isEmpty {
            UIPasteboard.general.string = email
        }
        
        guard let url = ReceiptRenderer.generatePDF(from: transaction) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: window.bounds.midX,
                y: window.bounds.midY,
                width: 0,
                height: 0
            )
            rootVC.present(activityVC, animated: true)
        }
    }
}
