//
//  BackofficeItemDetailView.swift
//  Simple Store
//

import SwiftUI
import SwiftData
import UIKit

/// An administrative interface displaying deep analytics, lifetime performance, and granular transaction history for a single item.
struct BackofficeItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    let item: StoreItem
    
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    
    @State private var isShowingEditSheet = false
    @State private var isShowingRestockAlert = false
    @State private var restockAmount = ""
    
    @State private var selectedTab: OrderFilterTab = .all
    @State private var orderSearchText = ""
    
    /// Filters the global transaction array for any entries containing this specific item.
    var itemTransactions: [Transaction] {
        let itemIdString = item.id.uuidString
        return allTransactions.filter { transaction in
            (transaction.lineItems ?? []).contains { $0.itemID == itemIdString }
        }
    }
    
    var filteredTransactions: [Transaction] {
        var txs = itemTransactions
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
                let matchCustomer = tx.customer?.fullName.localizedCaseInsensitiveContains(orderSearchText) ?? false
                let matchWalkIn = "Walk-in".localizedCaseInsensitiveContains(orderSearchText) && tx.customer == nil
                return matchAmount || matchDate || matchCustomer || matchWalkIn
            }
        }
        
        return txs.sorted(by: { $0.date > $1.date })
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
            headerSection
            statusSection
            performanceSection
            salesHistorySection
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
                    
                    // Dispatch Persistent Audit Log
                    if let storeId = session.currentUser?.activeStoreId {
                        let log = ActivityLog(
                            storeId: storeId,
                            title: "Restocked \(amount) units of \(item.name)",
                            category: "Inventory",
                            isRead: true,
                            targetRoles: ["admin", "employee", "customer"]
                        )
                        modelContext.insert(log)
                        syncManager.pushActivityToCloud(log)
                    }
                    
                    try? modelContext.save()
                    
                    // Dispatch Ephemeral UI Toast
                    ToastManager.shared.show(message: "Inventory updated", style: .success)
                }
            }
        } message: {
            Text("Enter the number of new units received for \(item.name).")
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
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
                        .overlay(Image(systemName: "photo").foregroundStyle(.gray))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(item.isActive ? .primary : .secondary)
                    
                    if let barcode = item.barcode, !barcode.isEmpty {
                        Text(barcode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                    if !item.isActive {
                        Text("Archived")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var statusSection: some View {
        Section(header: Text("Current Status")) {
            HStack {
                Text("Stock Level")
                Spacer()
                Text("\(item.stockCount)")
                    .fontWeight(.bold)
                    .foregroundStyle(item.stockCount > 0 ? Color.primary : Color.red)
            }
            
            HStack {
                Text("Retail Price")
                Spacer()
                Text(item.salesPrice, format: .currency(code: "CAD"))
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Wholesale Cost")
                Spacer()
                Text(item.itemCost, format: .currency(code: "CAD"))
                    .foregroundStyle(.secondary)
            }
            
            if item.isActive {
                Button {
                    restockAmount = ""
                    isShowingRestockAlert = true
                } label: {
                    Text("Receive Inventory (Restock)")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    private var performanceSection: some View {
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
                    .foregroundStyle(.green)
            }
        }
    }
    
    private var salesHistorySection: some View {
        Section(header: Text("Sales History")) {
            GlassSalesFilterView(selectedTab: $selectedTab, searchText: $orderSearchText)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 16, trailing: 0))
                .listRowSeparator(.hidden)
            
            if filteredTransactions.isEmpty {
                Text("No sales data available.")
                    .italic()
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredTransactions) { transaction in
                    transactionCard(for: transaction)
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
    
    private func transactionCard(for transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let customer = transaction.customer {
                        Text(customer.fullName)
                            .font(.headline)
                            .foregroundStyle(.blue)
                    } else if let buyerName = transaction.buyerEmployeeName {
                        Text(buyerName)
                            .font(.headline)
                            .foregroundStyle(.purple)
                    } else {
                        Text("Walk-in Customer")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    
                    Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(transaction.totalAmount, format: .currency(code: "CAD"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    let matchingLineItems = (transaction.lineItems ?? []).filter { $0.itemID == item.id.uuidString }
                    let totalQty = matchingLineItems.reduce(0) { $0 + $1.quantity }
                    
                    Text("\(totalQty) unit(s)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Export
    
    @MainActor
    private func shareReceipt(for transaction: Transaction) {
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
