//
//  BackofficeItemDetailView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI
import SwiftData
import UIKit

struct BackofficeItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let item: StoreItem
    
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    
    @State private var isShowingEditSheet = false
    @State private var isShowingRestockAlert = false
    @State private var restockAmount = ""
    
    // Filter transactions that contain this specific item ID
    var itemTransactions: [Transaction] {
        let itemIdString = item.id.uuidString
        return allTransactions.filter { transaction in
            (transaction.lineItems ?? []).contains { $0.itemID == itemIdString }
        }
    }
    
    var lifetimeUnitsSold: Int {
        itemTransactions.reduce(0) { sum, transaction in
            let itemQty = (transaction.lineItems ?? [])
                .filter { $0.itemID == item.id.uuidString }
                .reduce(0) { $0 + $1.quantity }
            return sum + itemQty
        }
    }
    
    var lifetimeRevenue: Double {
        itemTransactions.reduce(0) { sum, transaction in
            let itemRev = (transaction.lineItems ?? [])
                .filter { $0.itemID == item.id.uuidString }
                .reduce(0.0) { $0 + (Double($1.quantity) * $1.pricePerUnit) }
            return sum + itemRev
        }
    }
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    if let data = item.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .grayscale(item.isActive ? 0 : 0.99)
                            .opacity(item.isActive ? 1.0 : 0.6)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(Image(systemName: "photo").foregroundColor(.gray))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(item.isActive ? .primary : .secondary)
                        
                        if let barcode = item.barcode, !barcode.isEmpty {
                            Text(barcode)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        if !item.isActive {
                            Text("Archived")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Current Status")) {
                HStack {
                    Text("Stock Level")
                    Spacer()
                    Text("\(item.stockCount)")
                        .fontWeight(.bold)
                        .foregroundColor(item.stockCount > 0 ? .primary : .red)
                }
                
                HStack {
                    Text("Retail Price")
                    Spacer()
                    Text(item.salesPrice, format: .currency(code: "CAD"))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Wholesale Cost")
                    Spacer()
                    Text(item.itemCost, format: .currency(code: "CAD"))
                        .foregroundColor(.secondary)
                }
                
                if item.isActive {
                    Button(action: {
                        restockAmount = ""
                        isShowingRestockAlert = true
                    }) {
                        Text("Receive Inventory (Restock)")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
            }
            
            Section(header: Text("Lifetime Performance")) {
                HStack {
                    Text("Total Units Sold")
                    Spacer()
                    Text("\(lifetimeUnitsSold)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Gross Revenue")
                    Spacer()
                    Text(lifetimeRevenue, format: .currency(code: "CAD"))
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            Section(header: Text("Transaction Log")) {
                if itemTransactions.isEmpty {
                    Text("No sales data available.")
                        .italic()
                        .foregroundColor(.secondary)
                } else {
                    ForEach(itemTransactions) { transaction in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(transaction.totalAmount, format: .currency(code: "CAD"))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                let matchingLineItems = (transaction.lineItems ?? []).filter { $0.itemID == item.id.uuidString }
                                let totalQty = matchingLineItems.reduce(0) { $0 + $1.quantity }
                                let methods = Set((transaction.payments ?? []).map { $0.method }).joined(separator: ", ")
                                
                                Text("\(totalQty) unit(s) • \(methods)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(transaction.customer?.fullName ?? "Walk-in")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                shareReceipt(for: transaction)
                            } label: {
                                Label("Receipt", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") {
                isShowingEditSheet = true
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            EditItemView(item: item) {
                dismiss()
            }
        }
        .alert("Restock Item", isPresented: $isShowingRestockAlert) {
            TextField("Quantity received", text: $restockAmount)
                .keyboardType(.numberPad)
            
            Button("Cancel", role: .cancel) { }
            
            Button("Add to Stock") {
                if let amount = Int(restockAmount), amount > 0 {
                    item.stockCount += amount
                    item.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Enter the number of new units received for \(item.name).")
        }
    }
    
    private func shareReceipt(for transaction: Transaction) {
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
