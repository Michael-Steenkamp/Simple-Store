//
//  ItemProfileView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-18.
//

import SwiftUI
import SwiftData

struct ItemProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CartManager.self) private var cartManager
    
    let item: StoreItem
    var previousCustomerID: UUID? = nil
    
    @State private var isShowingEditSheet = false
    @State private var isShowingCheckoutSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                ZStack(alignment: .bottomTrailing) {
                    if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 150, height: 150)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                            .shadow(radius: 5)
                    }
                }
                .padding(.top, 20)
                
                VStack(spacing: 8) {
                    if let barcode = item.barcode, !barcode.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "barcode")
                            Text(barcode)
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "barcode.viewfinder")
                            Text("No Barcode Assigned")
                        }
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.6))
                    }
                    
                    Text(item.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    
                    Text(item.salesPrice, format: .currency(code: "CAD"))
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    if item.stockCount == 0 {
                        Text("Out of Stock")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .clipShape(Capsule())
                    } else {
                        Text("\(item.stockCount) In Stock")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                
                if let quantityInCart = cartManager.items[item] {
                    HStack(spacing: 20) {
                        Button(action: { cartManager.remove(item) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                        
                        VStack(spacing: 2) {
                            Text("\(quantityInCart) in Cart")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Total: \(Double(quantityInCart) * item.salesPrice, format: .currency(code: "CAD"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(minWidth: 100)
                        
                        Button(action: { cartManager.add(item) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(quantityInCart >= item.stockCount ? .gray : .green)
                        }
                        .disabled(quantityInCart >= item.stockCount)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                } else {
                    Button(action: {
                        cartManager.add(item)
                    }) {
                        VStack {
                            Image(systemName: "cart.badge.plus")
                                .font(.title)
                            Text("Add to Cart")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(item.stockCount <= 0)
                    .padding(.horizontal, 100)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let desc = item.desc, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(desc)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No notes provided.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                if let tags = item.tags, !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags) { tag in
                                    TagPillView(name: tag.name)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                ItemSalesHistorySection(
                    previousCustomerID: previousCustomerID,
                    currentItemID: item.id.uuidString
                )
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button("Edit") {
                        isShowingEditSheet = true
                    }
                    
                    if cartManager.totalItemCount > 0 {
                        Button(action: {
                            isShowingCheckoutSheet = true
                        }) {
                            Image(systemName: "cart.fill")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            EditItemView(item: item) {
                dismiss()
            }
        }
        .sheet(isPresented: $isShowingCheckoutSheet) {
            CartCheckoutView()
        }
    }
}

// MARK: - Smart Sales History Sub-View

struct ItemSalesHistorySection: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    
    let previousCustomerID: UUID?
    let currentItemID: String
    
    var itemTransactions: [Transaction] {
        allTransactions.filter { transaction in
            (transaction.lineItems ?? []).contains { $0.itemID == currentItemID }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sales")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if itemTransactions.isEmpty {
                Text("No sales history yet.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.horizontal)
            } else {
                ForEach(itemTransactions.prefix(5)) { transaction in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if let customer = transaction.customer {
                                if customer.id == previousCustomerID {
                                    Button(action: {
                                        dismiss()
                                    }) {
                                        Text(customer.fullName)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink(destination: CustomerDetailView(customer: customer)) {
                                        Text(customer.fullName)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Text("Walk-in Customer")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if let payments = transaction.payments {
                                let methods = Set(payments.map { $0.method }).joined(separator: ", ")
                                Text(methods)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
