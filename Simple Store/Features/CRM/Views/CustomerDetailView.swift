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
    
    var sortedTransactions: [Transaction] {
        customer.transactions?.sorted(by: { $0.date > $1.date }) ?? []
    }
    
    var totalLifetimeValue: Double {
        sortedTransactions.reduce(0) { $0 + $1.totalAmount }
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
        Section("Order History") {
            if sortedTransactions.isEmpty {
                Text("No past purchases.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(sortedTransactions) { transaction in
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
            HStack {
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text(transaction.totalAmount, format: .currency(code: "CAD"))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Divider()
            
            if let items = transaction.lineItems {
                ForEach(items) { lineItem in
                    lineItemRow(lineItem)
                }
            }
            
            if let payments = transaction.payments, !payments.isEmpty {
                HStack {
                    Text("Paid via:")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    let methods = Set(payments.map { $0.method }).joined(separator: ", ")
                    Text(methods)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Capsule())
                        
                    Spacer()
                    
                    if let employee = transaction.employeeName {
                        Text("by \(employee)")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func lineItemRow(_ lineItem: LineItem) -> some View {
        HStack {
            Text("\(lineItem.quantity)x")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            
            Text(lineItem.itemName)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text((Double(lineItem.quantity) * lineItem.pricePerUnit), format: .currency(code: "CAD"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Export
    
    /// Presents a native system share sheet to distribute the transaction receipt.
    @MainActor
    private func shareReceipt(for transaction: Transaction) {
        // Corrected argument label from 'from:' to 'for:'
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
