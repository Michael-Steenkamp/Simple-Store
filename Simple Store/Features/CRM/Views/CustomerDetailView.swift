//
//  CustomerDetailView.swift
//  Simple Store
//

import SwiftUI
import SwiftData
import UIKit

/// Displays a comprehensive overview of a specific customer, including their history, lifetime value, and related metadata.
struct CustomerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let customer: Customer
    
    @Query private var allItems: [StoreItem]
    @State private var isShowingEditSheet = false
    
    @State private var selectedTab: OrderFilterTab = .all
    @State private var orderSearchText = ""
    
    var filteredTransactions: [Transaction] {
        var txs = customer.transactions ?? []
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
    
    var totalLifetimeValue: Double {
        filteredTransactions.reduce(0) { $0 + $1.totalAmount }
    }
    
    var body: some View {
        List {
            overviewSection
            contactSection
            notesSection
            orderHistorySection
        }
        .navigationTitle(customer.fullName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button("Edit") {
                isShowingEditSheet = true
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            EditCustomerView(customer: customer) {
                dismiss()
            }
        }
    }
    
    // MARK: - Sections
    
    private var overviewSection: some View {
        Section("Account Overview") {
            if let status = customer.status {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(status.name)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.15))
                        .foregroundStyle(.indigo)
                        .clipShape(Capsule())
                }
            }
            
            HStack {
                Text("Total Lifetime Value")
                Spacer()
                Text("$\(totalLifetimeValue, specifier: "%.2f")")
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            
            HStack {
                Text("Customer Since")
                Spacer()
                Text(customer.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var contactSection: some View {
        Section(header: Text("Contact Information")) {
            if !customer.email.isEmpty {
                CopyableContactRow(icon: "envelope.fill", value: customer.email)
            }
            if !customer.phone.isEmpty {
                CopyableContactRow(icon: "phone.fill", value: customer.phone)
            }
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        if !customer.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section("Notes") {
                Text(customer.notes)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
    }
    
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
    
    // MARK: - Row Components
    
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
            
            if let employee = transaction.employeeName {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("Processed by \(employee)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, -4)
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
