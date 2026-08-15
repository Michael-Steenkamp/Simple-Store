//
//  ItemProfileView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// Displays granular details for a specific inventory item, including POS cart actions and dynamic, filtered sales history.
struct ItemProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CartManager.self) private var cartManager
    @Environment(SessionManager.self) private var session
    
    let item: StoreItem
    var previousCustomerID: UUID? = nil
    
    @State private var isShowingEditSheet = false
    @State private var isShowingCheckoutSheet = false
    
    var isItemInCart: Bool {
        cartManager.items.keys.contains(where: { $0.id == item.id })
    }
    
    // MARK: - Role-Based Access Control
    
    private var isStaff: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        let role = user.storeRoles[activeStore]
        return user.isSystemAdmin || role == "admin" || role == "employee"
    }
    
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // MARK: - Cloud-Ready Image Loading
                ZStack(alignment: .bottomTrailing) {
                    if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    } else if let urlString = item.imageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            } else if phase.error != nil {
                                ZStack {
                                    Circle().fill(Color.gray.opacity(0.2)).frame(width: 150, height: 150)
                                    Image(systemName: "photo.badge.exclamationmark").font(.system(size: 40)).foregroundStyle(.gray)
                                }
                            } else {
                                ZStack {
                                    Circle().fill(Color.gray.opacity(0.1)).frame(width: 150, height: 150)
                                    ProgressView()
                                }
                            }
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 150, height: 150)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.gray)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
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
                        .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "barcode.viewfinder")
                            Text("No Barcode Assigned")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.gray.opacity(0.6))
                    }
                    
                    Text(item.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    
                    Text(item.salesPrice, format: .currency(code: "CAD"))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    if isAdmin, item.itemCost > 0 {
                        Text("Cost: \(item.itemCost, format: .currency(code: "CAD"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, -4)
                    }
                    
                    if item.stockCount == 0 {
                        Text("Out of Stock")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    } else {
                        Text("\(item.stockCount) In Stock")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                }
                
                if isStaff {
                    if let quantityInCart = cartManager.items[item] {
                        HStack(spacing: 20) {
                            Button {
                                cartManager.remove(item)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                            }
                            
                            VStack(spacing: 2) {
                                Text("\(quantityInCart) in Cart")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("Total: \(Double(quantityInCart) * item.salesPrice, format: .currency(code: "CAD"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minWidth: 100)
                            
                            Button {
                                cartManager.add(item)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(quantityInCart >= item.stockCount ? .gray : .green)
                            }
                            .disabled(quantityInCart >= item.stockCount)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                    } else {
                        Button {
                            cartManager.add(item)
                        } label: {
                            VStack {
                                Image(systemName: "cart.badge.plus")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Add to Cart")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(item.stockCount <= 0)
                        .padding(.horizontal, 100)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    if let desc = item.desc, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(desc)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No notes provided.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                if let tags = item.tags, !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
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
                
                if isStaff {
                    ItemSalesHistorySection(
                        previousCustomerID: previousCustomerID,
                        currentItemID: item.id.uuidString
                    )
                }
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    if isAdmin && !isItemInCart {
                        Button("Edit") {
                            isShowingEditSheet = true
                        }
                    }
                    
                    if isStaff && cartManager.totalItemCount > 0 {
                        Button {
                            isShowingCheckoutSheet = true
                        } label: {
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

/// Evaluates local storage to display a dynamically filtered transaction history utilizing a fluid glass UI.
struct ItemSalesHistorySection: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    
    let previousCustomerID: UUID?
    let currentItemID: String
    
    @State private var selectedTab: OrderFilterTab = .all
    @State private var orderSearchText = ""
    
    var filteredTransactions: [Transaction] {
        var txs = allTransactions.filter { transaction in
            (transaction.lineItems ?? []).contains { $0.itemID == currentItemID }
        }
        
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sales History")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.horizontal)
            
            GlassSalesFilterView(selectedTab: $selectedTab, searchText: $orderSearchText)
                .padding(.horizontal)
            
            if filteredTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No sales match this criteria.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(filteredTransactions) { transaction in
                    transactionCard(for: transaction)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .animation(.default, value: filteredTransactions.count)
    }
    
    private func transactionCard(for transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let customer = transaction.customer {
                        if customer.id == previousCustomerID {
                            Button {
                                dismiss()
                            } label: {
                                Text(customer.fullName)
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: CustomerDetailView(customer: customer)) {
                                Text(customer.fullName)
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
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
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
}
