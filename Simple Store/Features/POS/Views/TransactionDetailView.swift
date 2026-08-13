//
//  TransactionDetailView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-21.
//

import SwiftUI
import SwiftData

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
                                .foregroundColor(.secondary)
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
            Button(action: {
                shareReceipt(for: transaction)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                    Text("Receipt")
                        .font(.headline)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .padding(.bottom, 24)
        }
    }
    
    private func reorderEntireTransaction() {
        cartManager.clearCart()
                
        if let items = transaction.lineItems {
            for lineItem in items {
                // Verify the item is active and not scrubbed
                if let liveItem = allItems.first(where: { $0.id.uuidString == lineItem.itemID }),
                   liveItem.isActive,
                   !liveItem.name.hasSuffix("(Deleted)"),
                   liveItem.stockCount >= lineItem.quantity {
                    
                    // Add the historical quantity to the cart
                    for _ in 0..<lineItem.quantity {
                        cartManager.add(liveItem)
                    }
                }
            }
        }
        
        cartManager.selectedCustomer = transaction.customer
        isShowingCheckout = true
    }
    
    // MARK: - Actions
        
    private func shareReceipt(for transaction: Transaction) {
        // Copies the email to clipboard if it exists
        if let email = transaction.customer?.email, !email.trimmingCharacters(in: .whitespaces).isEmpty {
            UIPasteboard.general.string = email
        }
        
        // Generates the PDF using your renderer
        guard let url = ReceiptRenderer.generatePDF(from: transaction) else { return }
        
        // Presents the native iOS share sheet
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
