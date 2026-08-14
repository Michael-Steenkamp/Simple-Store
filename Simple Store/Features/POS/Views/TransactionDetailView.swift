//
//  TransactionDetailView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// Displays a comprehensive overview of a completed transaction with cart reordering and receipt sharing capabilities.
struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CartManager.self) private var cartManager
    @Query private var allItems: [StoreItem]
    
    let transaction: Transaction
    @State private var isShowingCheckout = false
    
    var canReorder: Bool {
        guard let items = transaction.lineItems else { return false }
        return items.contains { lineItem in
            if let liveItem = allItems.first(where: { $0.id.uuidString == lineItem.itemID }) {
                return liveItem.isActive && !liveItem.name.hasSuffix("(Deleted)") && liveItem.stockCount > 0
            }
            return false
        }
    }
    
    var body: some View {
        List {
            Section("Transaction Summary") {
                LabeledContent("Date", value: transaction.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Total", value: transaction.totalAmount.formatted(.currency(code: "CAD")))
                
                if let customer = transaction.customer {
                    LabeledContent("Customer", value: customer.fullName)
                }
                
                if let employee = transaction.employeeName {
                    LabeledContent("Employee", value: employee)
                }
            }
            
            Section("Items Purchased") {
                if let items = transaction.lineItems {
                    ForEach(items) { lineItem in
                        let matchedItem = allItems.first(where: { $0.id.uuidString == lineItem.itemID })
                        
                        HStack {
                            Text("\(lineItem.quantity)x")
                                .foregroundStyle(.secondary)
                            Text(lineItem.itemName)
                            Spacer()
                            Text((Double(lineItem.quantity) * lineItem.pricePerUnit), format: .currency(code: "CAD"))
                        }
                        .swipeActions(edge: .trailing) {
                            if let liveItem = matchedItem,
                               liveItem.stockCount > 0,
                               liveItem.isActive,
                               !liveItem.name.hasSuffix("(Deleted)") {
                                
                                Button {
                                    cartManager.add(liveItem)
                                } label: {
                                    Label("Add to Cart", systemImage: "cart.badge.plus")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Order Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if canReorder {
                    Button("Order Again") {
                        reorderEntireTransaction()
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCheckout) {
            CartCheckoutView()
        }
        .overlay(alignment: .bottom) {
            Button {
                shareReceipt(for: transaction)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                    Text("Receipt")
                        .font(.headline)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Actions
    
    private func reorderEntireTransaction() {
        cartManager.clearCart()
                
        if let items = transaction.lineItems {
            for lineItem in items {
                if let liveItem = allItems.first(where: { $0.id.uuidString == lineItem.itemID }),
                   liveItem.isActive,
                   !liveItem.name.hasSuffix("(Deleted)"),
                   liveItem.stockCount >= lineItem.quantity {
                    
                    for _ in 0..<lineItem.quantity {
                        cartManager.add(liveItem)
                    }
                }
            }
        }
        
        cartManager.selectedCustomer = transaction.customer
        isShowingCheckout = true
    }
    
    /// Presents a native system share sheet to distribute the transaction receipt.
    @MainActor
    private func shareReceipt(for transaction: Transaction) {
        if let email = transaction.customer?.email, !email.trimmingCharacters(in: .whitespaces).isEmpty {
            UIPasteboard.general.string = email
        }
        
        guard let url = ReceiptRenderer.generatePDF(for: transaction) else { return }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: \.isKeyWindow),
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
