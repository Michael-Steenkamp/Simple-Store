//
//  CustomerDetailView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-19.
//

import SwiftUI
import SwiftData
import UIKit

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
                            .foregroundColor(.indigo)
                            .clipShape(Capsule())
                    }
                }
                
                HStack {
                    Text("Total Lifetime Value")
                    Spacer()
                    Text("$\(totalLifetimeValue, specifier: "%.2f")")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Customer Since")
                    Spacer()
                    Text(customer.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Contact Information")) {
                if !customer.email.isEmpty {
                    CopyableContactRow(icon: "envelope.fill", value: customer.email)
                }
                if !customer.phone.isEmpty {
                    CopyableContactRow(icon: "phone.fill", value: customer.phone)
                }
            }
            
            if !customer.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Notes") {
                    Text(customer.notes)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            Section("Order History") {
                if sortedTransactions.isEmpty {
                    Text("No past purchases.")
                        .foregroundColor(.secondary)
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
    
    private func transactionCard(for transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text(transaction.totalAmount, format: .currency(code: "CAD"))
                    .font(.headline)
                    .foregroundColor(.primary)
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
                        .foregroundColor(.gray)
                    
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
                            .foregroundColor(.gray)
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
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            
            Text(lineItem.itemName)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text((Double(lineItem.quantity) * lineItem.pricePerUnit), format: .currency(code: "CAD"))
                .font(.subheadline)
                .foregroundColor(.secondary)
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
