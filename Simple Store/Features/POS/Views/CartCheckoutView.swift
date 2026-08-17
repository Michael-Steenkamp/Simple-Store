//
//  CartCheckoutView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - Models

/// Represents an ephemeral, in-progress split payment before it is committed to SwiftData.
@MainActor
@Observable
public final class PaymentSplitDraft: Identifiable {
    public let id = UUID()
    public var method: String
    public var amount: Double?
    
    public init(method: String, amount: Double? = nil) {
        self.method = method
        self.amount = amount
    }
}

// MARK: - View Model

/// Orchestrates the point-of-sale transaction finalization, database insertion, and Firebase syncing.
@MainActor
@Observable
final class CartCheckoutViewModel {
    enum BuyerType { case customer, employee }
    
    var buyerType: BuyerType = .customer
    var isShowingCustomerSelection = false
    var isShowingEmployeeSelection = false
    var isShowingEmployeeBuyerSelection = false
    
    var selectedEmployeeBuyer: Employee? = nil
    var assignedItemToSplit: [String: UUID] = [:]
    
    let availableMethods = ["Card", "Cash", "E-Transfer"]
    
    var isCheckoutComplete = false
    var completedTransaction: Transaction? = nil
    var receiptURL: URL? = nil
    
    func remainingBalance(for cartManager: CartManager) -> Double {
        let paid = cartManager.paymentSplits.reduce(0) { $0 + ($1.amount ?? 0) }
        return cartManager.totalAmount - paid
    }
    
    func canCheckout(for cartManager: CartManager) -> Bool {
        abs(remainingBalance(for: cartManager)) < 0.01 && cartManager.totalItemCount > 0
    }
    
    func syncPaymentSplits(cartManager: CartManager, newTotal: Double, oldTotal: Double) {
        let difference = newTotal - oldTotal
        if cartManager.paymentSplits.isEmpty {
            if newTotal > 0 { cartManager.paymentSplits.append(PaymentSplitDraft(method: "Card", amount: newTotal)) }
        } else if abs(difference) > 0.01 {
            let firstAmount = cartManager.paymentSplits[0].amount ?? 0
            cartManager.paymentSplits[0].amount = max(0, firstAmount + difference)
        }
    }
    
    func processTransaction(
        context: ModelContext,
        session: SessionManager,
        syncManager: SyncManager,
        cartManager: CartManager
    ) {
        let finalCustomer = buyerType == .customer ? cartManager.selectedCustomer : nil
        let internalBuyerName = buyerType == .employee ? selectedEmployeeBuyer?.name : nil
        let internalBuyerId = buyerType == .employee ? selectedEmployeeBuyer?.id.uuidString : nil
        
        let storeId = session.currentUser?.activeStoreId ?? ""
        
        let newTransaction = Transaction(
            id: UUID(),
            storeId: storeId,
            totalAmount: cartManager.totalAmount,
            employeeName: cartManager.selectedEmployee?.name,
            employeeId: cartManager.selectedEmployee?.id.uuidString,
            customer: finalCustomer,
            buyerEmployeeName: internalBuyerName,
            buyerEmployeeId: internalBuyerId
        )
        newTransaction.date = Date()
        
        context.insert(newTransaction)
        
        var createdLineItems: [LineItem] = []
        
        for (item, quantity) in cartManager.items {
            let lineItem = LineItem(id: UUID(), itemName: item.name, itemID: item.id.uuidString, quantity: quantity, pricePerUnit: item.salesPrice)
            context.insert(lineItem)
            lineItem.transaction = newTransaction
            createdLineItems.append(lineItem)
            item.stockCount -= quantity
        }
        newTransaction.lineItems = createdLineItems
        
        var createdSplits: [PaymentSplit] = []
        for draft in cartManager.paymentSplits {
            let safeAmount = draft.amount ?? 0
            if safeAmount > 0 {
                let split = PaymentSplit(id: UUID(), method: draft.method, amount: safeAmount)
                context.insert(split)
                split.transaction = newTransaction
                createdSplits.append(split)
            }
        }
        newTransaction.payments = createdSplits
        
        try? context.save()
        
        for (item, quantity) in cartManager.items {
            syncManager.updateStockInCloud(itemId: item.id.uuidString, quantityDelta: -quantity)
        }
        syncManager.pushTransactionToCloud(newTransaction)
        
        if let email = cartManager.selectedCustomer?.email, !email.trimmingCharacters(in: .whitespaces).isEmpty {
            UIPasteboard.general.string = email
        }
        
        if let url = ReceiptRenderer.generatePDF(for: newTransaction) { self.receiptURL = url }
        
        self.completedTransaction = newTransaction
        cartManager.clearCart()
        
        withAnimation(.spring(.bouncy)) { isCheckoutComplete = true }
    }
}

// MARK: - View

/// The master interface for reviewing cart items, allocating split payments, and committing point-of-sale transactions.
struct CartCheckoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CartManager.self) private var cartManager
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    @State private var viewModel = CartCheckoutViewModel()
    @FocusState private var focusedSplitID: UUID?
    
    var body: some View {
        Group {
            if viewModel.isCheckoutComplete, let transaction = viewModel.completedTransaction {
                successScreen(for: transaction)
            } else {
                checkoutForm
            }
        }
        .onAppear {
            let currentSplitsTotal = cartManager.paymentSplits.reduce(0) { $0 + ($1.amount ?? 0) }
            viewModel.syncPaymentSplits(cartManager: cartManager, newTotal: cartManager.totalAmount, oldTotal: currentSplitsTotal)
        }
        .onChange(of: cartManager.totalAmount) { oldValue, newValue in
            viewModel.syncPaymentSplits(cartManager: cartManager, newTotal: newValue, oldTotal: oldValue)
        }
    }
    
    // MARK: - Core Forms
    
    private var checkoutForm: some View {
        Form {
            cartItemsSection
            assignmentSection
            paymentSection
            
            Color.clear.frame(height: 100).listRowBackground(Color.clear)
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionArea
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focusedSplitID != nil)
        .sheet(isPresented: $viewModel.isShowingCustomerSelection) { CustomerSelectionView(selectedCustomer: Bindable(cartManager).selectedCustomer) }
        .sheet(isPresented: $viewModel.isShowingEmployeeSelection) { EmployeeSelectionView(selectedEmployee: Bindable(cartManager).selectedEmployee) }
        .sheet(isPresented: $viewModel.isShowingEmployeeBuyerSelection) { EmployeeSelectionView(selectedEmployee: $viewModel.selectedEmployeeBuyer) }
    }
    
    // MARK: - Sections
    
    private var cartItemsSection: some View {
        Section(header: Text("Cart Items")) {
            let sortedItems = cartManager.items.keys.sorted(by: { $0.name < $1.name })
            
            ForEach(sortedItems) { item in
                if let qty = cartManager.items[item] {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).fontWeight(.semibold)
                            Text("\(qty)x @ \(item.salesPrice, format: .currency(code: "CAD"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Double(qty) * item.salesPrice, format: .currency(code: "CAD"))
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            cartManager.completelyRemove(item)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            
            HStack {
                Text("Total Amount").fontWeight(.bold)
                Spacer()
                Text(cartManager.totalAmount, format: .currency(code: "CAD"))
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private var assignmentSection: some View {
        Section(header: Text("Assign Roles")) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Server (Required)").font(.caption).foregroundStyle(.secondary)
                Button {
                    viewModel.isShowingEmployeeSelection = true
                } label: {
                    HStack {
                        Image(systemName: "lanyardcard.fill")
                            .foregroundStyle(cartManager.selectedEmployee == nil ? .gray : .indigo)
                            .frame(width: 24)
                        Text(cartManager.selectedEmployee?.name ?? "Select Server")
                            .foregroundStyle(cartManager.selectedEmployee == nil ? .secondary : .primary)
                    }
                }
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Buyer (Optional)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Picker("Buyer Type", selection: $viewModel.buyerType) {
                        Text("Customer").tag(CartCheckoutViewModel.BuyerType.customer)
                        Text("Staff").tag(CartCheckoutViewModel.BuyerType.employee)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 160)
                }
                
                if viewModel.buyerType == .customer {
                    Button {
                        viewModel.isShowingCustomerSelection = true
                    } label: {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(cartManager.selectedCustomer == nil ? .gray : .blue)
                                .frame(width: 24)
                            Text(cartManager.selectedCustomer?.fullName ?? "Walk-in Customer")
                                .foregroundStyle(cartManager.selectedCustomer == nil ? .secondary : .primary)
                        }
                    }
                } else {
                    Button {
                        viewModel.isShowingEmployeeBuyerSelection = true
                    } label: {
                        HStack {
                            Image(systemName: "bag.fill")
                                .foregroundStyle(viewModel.selectedEmployeeBuyer == nil ? .gray : .orange)
                                .frame(width: 24)
                            Text(viewModel.selectedEmployeeBuyer?.name ?? "Select Staff Buyer")
                                .foregroundStyle(viewModel.selectedEmployeeBuyer == nil ? .secondary : .primary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var paymentSection: some View {
        Section(
            header: Text("Payment"),
            footer: Text(abs(viewModel.remainingBalance(for: cartManager)) > 0.01 ? "Remaining balance to allocate: \(viewModel.remainingBalance(for: cartManager), format: .currency(code: "CAD"))" : "")
                .foregroundStyle(viewModel.remainingBalance(for: cartManager) < 0 ? .red : .orange)
        ) {
            ForEach(cartManager.paymentSplits) { split in
                PaymentSplitRowView(split: split, cartManager: cartManager, availableMethods: viewModel.availableMethods, focusedSplitID: $focusedSplitID)
            }
            
            if cartManager.paymentSplits.count < viewModel.availableMethods.count {
                Button {
                    let amountToAdd = viewModel.remainingBalance(for: cartManager) > 0.01 ? viewModel.remainingBalance(for: cartManager) : nil
                    let usedMethods = Set(cartManager.paymentSplits.map { $0.method })
                    let firstAvailableMethod = viewModel.availableMethods.first(where: { !usedMethods.contains($0) }) ?? "Cash"
                    cartManager.paymentSplits.append(PaymentSplitDraft(method: firstAvailableMethod, amount: amountToAdd))
                } label: {
                    Label("Add Split Payment", systemImage: "plus.circle")
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    @ViewBuilder
    private var bottomActionArea: some View {
        if focusedSplitID != nil {
            VStack(spacing: 0) {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quick Price Reference").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                        let currentSplitAssignments = viewModel.assignedItemToSplit.filter { $0.value == focusedSplitID }
                        if !currentSplitAssignments.isEmpty {
                            Button {
                                for key in currentSplitAssignments.keys { viewModel.assignedItemToSplit.removeValue(forKey: key) }
                                if let focusedID = focusedSplitID, let split = cartManager.paymentSplits.first(where: { $0.id == focusedID }) { split.amount = nil }
                            } label: {
                                Text("Clear").font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.red.opacity(0.15)).foregroundStyle(.red).clipShape(Capsule())
                            }
                        }
                        Spacer()
                        Button("Done") { focusedSplitID = nil }.font(.subheadline).fontWeight(.bold).foregroundStyle(.blue)
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            let availableItems = cartManager.items.keys.filter { viewModel.assignedItemToSplit[$0.id.uuidString] != focusedSplitID }.sorted(by: { $0.name < $1.name })
                            if availableItems.isEmpty && !cartManager.items.isEmpty {
                                Text("All items added to this split.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 10).padding(.horizontal, 4)
                            } else {
                                ForEach(availableItems) { item in
                                    if let qty = cartManager.items[item] {
                                        Button {
                                            let itemID = item.id.uuidString
                                            let itemTotal = Double(qty) * item.salesPrice
                                            if let focusedID = focusedSplitID {
                                                if let oldSplitID = viewModel.assignedItemToSplit[itemID], let oldSplit = cartManager.paymentSplits.first(where: { $0.id == oldSplitID }) {
                                                    oldSplit.amount = max(0, (oldSplit.amount ?? 0) - itemTotal)
                                                }
                                                viewModel.assignedItemToSplit[itemID] = focusedID
                                                if let split = cartManager.paymentSplits.first(where: { $0.id == focusedID }) {
                                                    split.amount = (split.amount ?? 0) + itemTotal
                                                }
                                            }
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name).font(.caption).fontWeight(.bold)
                                                Text("\(qty)x @ \(item.salesPrice, format: .currency(code: "CAD"))").font(.caption2).foregroundStyle(.secondary)
                                                Text(Double(qty) * item.salesPrice, format: .currency(code: "CAD")).font(.caption.bold()).foregroundStyle(.blue)
                                            }
                                            .padding(10)
                                            .background(Color(uiColor: .systemBackground))
                                            .cornerRadius(8)
                                            .shadow(color: .black.opacity(0.05), radius: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal).padding(.bottom, 8)
                    }
                }
                .padding(.top, 12).background(Color(uiColor: .secondarySystemBackground))
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            VStack(spacing: 12) {
                Button {
                    viewModel.processTransaction(context: modelContext, session: session, syncManager: syncManager, cartManager: cartManager)
                } label: {
                    Text("Complete Sale • \(cartManager.totalAmount, format: .currency(code: "CAD"))")
                        .frame(maxWidth: .infinity).font(.headline).padding(.vertical, 14).foregroundStyle(.white)
                        .background(viewModel.canCheckout(for: cartManager) ? Color.green : Color.gray).cornerRadius(12)
                        .shadow(color: viewModel.canCheckout(for: cartManager) ? Color.green.opacity(0.3) : Color.clear, radius: 5, y: 3)
                }
                .disabled(!viewModel.canCheckout(for: cartManager))
                
                Button {
                    cartManager.clearCart()
                    dismiss()
                } label: {
                    Text("Discard Cart")
                        .frame(maxWidth: .infinity).font(.subheadline).fontWeight(.semibold).padding(.vertical, 14)
                        .foregroundStyle(.red).background(Color.red.opacity(0.1)).cornerRadius(12)
                }
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8).background(.regularMaterial)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func successScreen(for transaction: Transaction) -> some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 120, height: 120)
                Image(systemName: "checkmark").font(.system(size: 50, weight: .bold)).foregroundStyle(.green)
            }
            VStack(spacing: 8) {
                Text("Sale Complete!").font(.largeTitle).fontWeight(.bold)
                Text(transaction.totalAmount, format: .currency(code: "CAD")).font(.title2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 16) {
                if let url = viewModel.receiptURL {
                    ShareLink(item: url) {
                        HStack {
                            Image(systemName: "square.and.arrow.up").font(.title3)
                            Text("Share / Print Receipt").font(.headline)
                        }
                        .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundStyle(.white).cornerRadius(12)
                    }
                }
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 40)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Row Component

struct PaymentSplitRowView: View {
    @Bindable var split: PaymentSplitDraft
    var cartManager: CartManager
    let availableMethods: [String]
    var focusedSplitID: FocusState<UUID?>.Binding
    
    var validMethods: [String] {
        let usedMethods = Set(cartManager.paymentSplits.map { $0.method })
        return availableMethods.filter { $0 == split.method || !usedMethods.contains($0) }
    }
    
    private func icon(for method: String) -> String {
        switch method {
        case "Card": return "creditcard"
        case "Cash": return "banknote"
        case "E-Transfer": return "arrow.right.arrow.left"
        default: return "dollarsign.circle"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if validMethods.count == 1 {
                Label(split.method, systemImage: icon(for: split.method))
                    .frame(maxWidth: 140, alignment: .leading)
                    .foregroundStyle(.primary)
            } else {
                Picker("", selection: $split.method) {
                    ForEach(validMethods, id: \.self) { method in
                        Label(method, systemImage: icon(for: method)).tag(method)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 140, alignment: .leading)
            }
            
            Spacer()
            
            TextField("Amount", value: $split.amount, format: .currency(code: "CAD"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle((split.amount ?? 0) == 0 ? .red : .primary)
                .focused(focusedSplitID, equals: split.id)
                .onChange(of: split.amount) { oldValue, newValue in
                    if cartManager.paymentSplits.count == 2, focusedSplitID.wrappedValue == split.id {
                        if let otherSplit = cartManager.paymentSplits.first(where: { $0.id != split.id }) {
                            let currentTyped = newValue ?? 0
                            if currentTyped <= cartManager.totalAmount {
                                let desiredOther = max(0, cartManager.totalAmount - currentTyped)
                                if otherSplit.amount != desiredOther {
                                    otherSplit.amount = desiredOther
                                }
                            }
                        }
                    }
                }
            
            if cartManager.paymentSplits.count > 1 {
                Image(systemName: "chevron.left.2")
                    .font(.caption2)
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .padding(.leading, 4)
            }
        }
        .swipeActions(edge: .trailing) {
            if cartManager.paymentSplits.count > 1 {
                Button(role: .destructive) {
                    cartManager.paymentSplits.removeAll { $0.id == split.id }
                    if cartManager.paymentSplits.count == 1 {
                        cartManager.paymentSplits[0].amount = cartManager.totalAmount
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }
}
