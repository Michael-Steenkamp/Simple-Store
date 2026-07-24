//
//  CartCheckoutView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-21.
//

import SwiftUI
import SwiftData

struct CartCheckoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CartManager.self) private var cartManager
    
    @FocusState private var focusedSplitID: UUID?
    
    @State private var isShowingCustomerSelection = false
    @State private var isShowingEmployeeSelection = false
    
    @State private var assignedItemToSplit: [String: UUID] = [:]
    
    let availableMethods = ["Card", "Cash", "E-Transfer"]
    
    @State private var isCheckoutComplete = false
    @State private var completedTransaction: Transaction? = nil
    @State private var receiptURL: URL? = nil
    
    var remainingBalance: Double {
        let paid = cartManager.paymentSplits.reduce(0) { $0 + ($1.amount ?? 0) }
        return cartManager.totalAmount - paid
    }
    
    var canCheckout: Bool {
        abs(remainingBalance) < 0.01 && cartManager.totalItemCount > 0
    }
    
    var body: some View {
        Group {
            if isCheckoutComplete, let transaction = completedTransaction {
                successScreen(for: transaction)
            } else {
                checkoutForm
            }
        }
        .onAppear {
            // Evaluates the current splits vs the total when the sheet opens
            let currentSplitsTotal = cartManager.paymentSplits.reduce(0) { $0 + ($1.amount ?? 0) }
            syncPaymentSplits(with: cartManager.totalAmount, oldTotal: currentSplitsTotal)
        }
        .onChange(of: cartManager.totalAmount) { oldValue, newValue in
            // Evaluates the total dynamically if items are swipe-deleted while inside the sheet
            syncPaymentSplits(with: newValue, oldTotal: oldValue)
        }
    }
    
    private var checkoutForm: some View {
        Form {
            Section(header: Text("Cart Items")) {
                let sortedItems = cartManager.items.keys.sorted(by: { $0.name < $1.name })
                
                ForEach(sortedItems) { item in
                    if let qty = cartManager.items[item] {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).fontWeight(.semibold)
                                Text("\(qty)x @ \(item.salesPrice, format: .currency(code: "CAD"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(Double(qty) * item.salesPrice, format: .currency(code: "CAD"))
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                cartManager.completelyRemove(item)
                                // onChange now automatically balances the splits
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                
                HStack {
                    Text("Total Amount")
                        .fontWeight(.bold)
                    Spacer()
                    Text(cartManager.totalAmount, format: .currency(code: "CAD"))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            
            Section(header: Text("People (Optional)")) {
                Button(action: { isShowingCustomerSelection = true }) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(cartManager.selectedCustomer == nil ? .gray : .blue)
                            .frame(width: 24)
                        Text(cartManager.selectedCustomer?.fullName ?? "Walk-in Customer")
                            .foregroundColor(cartManager.selectedCustomer == nil ? .secondary : .primary)
                    }
                }
                
                Button(action: { isShowingEmployeeSelection = true }) {
                    HStack {
                        Image(systemName: "lanyardcard.fill")
                            .foregroundColor(cartManager.selectedEmployee == nil ? .gray : .indigo)
                            .frame(width: 24)
                        Text(cartManager.selectedEmployee?.name ?? "Select Employee")
                            .foregroundColor(cartManager.selectedEmployee == nil ? .secondary : .primary)
                    }
                }
            }
            
            Section(
                header: Text("Payment"),
                footer: Text(abs(remainingBalance) > 0.01 ? "Remaining balance to allocate: \(remainingBalance, format: .currency(code: "CAD"))" : "")
                    .foregroundColor(remainingBalance < 0 ? .red : .orange)
            ) {
                
                ForEach(cartManager.paymentSplits) { split in
                    PaymentSplitRowView(
                        split: split,
                        cartManager: cartManager,
                        availableMethods: availableMethods,
                        focusedSplitID: $focusedSplitID
                    )
                }
                
                if cartManager.paymentSplits.count < availableMethods.count {
                    Button(action: {
                        let amountToAdd = remainingBalance > 0.01 ? remainingBalance : nil
                        
                        let usedMethods = Set(cartManager.paymentSplits.map { $0.method })
                        let firstAvailableMethod = availableMethods.first(where: { !usedMethods.contains($0) }) ?? "Cash"
                        
                        cartManager.paymentSplits.append(PaymentSplitDraft(method: firstAvailableMethod, amount: amountToAdd))
                    }) {
                        Label("Add Split Payment", systemImage: "plus.circle")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
            }
            
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
            if focusedSplitID != nil {
                VStack(spacing: 0) {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Quick Price Reference")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            // 1. Smart Clear Button
                            let currentSplitAssignments = assignedItemToSplit.filter { $0.value == focusedSplitID }
                            if !currentSplitAssignments.isEmpty {
                                Button(action: {
                                    for key in currentSplitAssignments.keys {
                                        assignedItemToSplit.removeValue(forKey: key)
                                    }
                                    if let focusedID = focusedSplitID,
                                       let split = cartManager.paymentSplits.first(where: { $0.id == focusedID }) {
                                        split.amount = nil
                                    }
                                }) {
                                    Text("Clear")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.15))
                                        .foregroundColor(.red)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Spacer()
                            
                            Button("Done") {
                                focusedSplitID = nil
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // 2. Only show items NOT currently assigned to this specific split
                                let availableItems = cartManager.items.keys
                                    .filter { assignedItemToSplit[$0.id.uuidString] != focusedSplitID }
                                    .sorted(by: { $0.name < $1.name })
                                
                                if availableItems.isEmpty && !cartManager.items.isEmpty {
                                    Text("All items added to this split.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 4)
                                } else {
                                    ForEach(availableItems) { item in
                                        if let qty = cartManager.items[item] {
                                            Button(action: {
                                                let itemID = item.id.uuidString
                                                let itemTotal = Double(qty) * item.salesPrice
                                                
                                                if let focusedID = focusedSplitID {
                                                    // A: Subtract from previous split if it was assigned elsewhere
                                                    if let oldSplitID = assignedItemToSplit[itemID],
                                                       let oldSplit = cartManager.paymentSplits.first(where: { $0.id == oldSplitID }) {
                                                        let oldAmount = oldSplit.amount ?? 0
                                                        oldSplit.amount = max(0, oldAmount - itemTotal)
                                                    }
                                                    
                                                    // B: Assign item to the new split in memory
                                                    assignedItemToSplit[itemID] = focusedID
                                                    
                                                    // C: Add the value to the currently focused split
                                                    if let split = cartManager.paymentSplits.first(where: { $0.id == focusedID }) {
                                                        let currentAmount = split.amount ?? 0
                                                        split.amount = currentAmount + itemTotal
                                                    }
                                                }
                                            }) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.name).font(.caption).fontWeight(.bold)
                                                    Text("\(qty)x @ \(item.salesPrice, format: .currency(code: "CAD"))").font(.caption2).foregroundColor(.secondary)
                                                    Text(Double(qty) * item.salesPrice, format: .currency(code: "CAD")).font(.caption.bold()).foregroundColor(.blue)
                                                }
                                                .padding(10)
                                                .background(Color(UIColor.systemBackground))
                                                .cornerRadius(8)
                                                .shadow(color: .black.opacity(0.05), radius: 2)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.top, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 12) {
                    Button(action: processTransaction) {
                        Text("Complete Sale • \(cartManager.totalAmount, format: .currency(code: "CAD"))")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(canCheckout ? Color.green : Color.gray)
                            .cornerRadius(12)
                            .shadow(color: canCheckout ? Color.green.opacity(0.3) : Color.clear, radius: 5, y: 3)
                    }
                    .disabled(!canCheckout)
                    
                    Button(action: {
                        cartManager.clearCart()
                        dismiss()
                    }) {
                        Text("Discard Cart")
                            .frame(maxWidth: .infinity)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.vertical, 14)
                            .foregroundColor(.red)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focusedSplitID != nil)
        .sheet(isPresented: $isShowingCustomerSelection) {
            CustomerSelectionView(selectedCustomer: Bindable(cartManager).selectedCustomer)
        }
        .sheet(isPresented: $isShowingEmployeeSelection) {
            EmployeeSelectionView(selectedEmployee: Bindable(cartManager).selectedEmployee)
        }
    }
    
    // MARK: - Auto-Balancing Logic
    private func syncPaymentSplits(with newTotal: Double, oldTotal: Double) {
        let difference = newTotal - oldTotal
        
        if cartManager.paymentSplits.isEmpty {
            if newTotal > 0 {
                cartManager.paymentSplits.append(PaymentSplitDraft(method: "Card", amount: newTotal))
            }
        } else if abs(difference) > 0.01 {
            // Stacks the difference on top of the very first payment option
            let firstAmount = cartManager.paymentSplits[0].amount ?? 0
            cartManager.paymentSplits[0].amount = max(0, firstAmount + difference)
        }
    }
    
    private func successScreen(for transaction: Transaction) -> some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 120, height: 120)
                Image(systemName: "checkmark").font(.system(size: 50, weight: .bold)).foregroundColor(.green)
            }
            VStack(spacing: 8) {
                Text("Sale Complete!").font(.largeTitle).fontWeight(.bold)
                Text(transaction.totalAmount, format: .currency(code: "CAD")).font(.title2).foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 16) {
                if let url = receiptURL {
                    ShareLink(item: url) {
                        HStack {
                            Image(systemName: "square.and.arrow.up").font(.title3)
                            Text("Share / Print Receipt").font(.headline)
                        }
                        .frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
                    }
                }
                Button(action: { dismiss() }) {
                    Text("Done").font(.headline).frame(maxWidth: .infinity).padding().background(Color(UIColor.secondarySystemBackground)).foregroundColor(.primary).cornerRadius(12)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 40)
        }
        .navigationBarHidden(true)
    }
    
    private func processTransaction() {
        let newTransaction = Transaction(
            totalAmount: cartManager.totalAmount,
            employeeName: cartManager.selectedEmployee?.name,
            employeeId: cartManager.selectedEmployee?.id.uuidString,
            customer: cartManager.selectedCustomer
        )
        
        modelContext.insert(newTransaction)
        
        var createdLineItems: [LineItem] = []
        for (item, quantity) in cartManager.items {
            let lineItem = LineItem(
                itemName: item.name,
                itemID: item.id.uuidString,
                quantity: quantity,
                pricePerUnit: item.salesPrice
            )
            modelContext.insert(lineItem)
            lineItem.transaction = newTransaction
            createdLineItems.append(lineItem)
            
            item.stockCount -= quantity
        }
        newTransaction.lineItems = createdLineItems
        
        var createdSplits: [PaymentSplit] = []
        for draft in cartManager.paymentSplits {
            let safeAmount = draft.amount ?? 0
            if safeAmount > 0 {
                let split = PaymentSplit(method: draft.method, amount: safeAmount)
                modelContext.insert(split)
                split.transaction = newTransaction
                createdSplits.append(split)
            }
        }
        newTransaction.payments = createdSplits
        
        try? modelContext.save()
        
        if let email = cartManager.selectedCustomer?.email, !email.trimmingCharacters(in: .whitespaces).isEmpty {
            UIPasteboard.general.string = email
        }
        
        if let url = ReceiptRenderer.generatePDF(from: newTransaction) {
            self.receiptURL = url
        }
        
        self.completedTransaction = newTransaction
        cartManager.clearCart()
        
        withAnimation(.spring()) {
            isCheckoutComplete = true
        }
    }
}

// MARK: - Dedicated Subview for Absolute Isolation
struct PaymentSplitRowView: View {
    @Bindable var split: PaymentSplitDraft
    var cartManager: CartManager
    let availableMethods: [String]
    var focusedSplitID: FocusState<UUID?>.Binding
    
    var validMethods: [String] {
        let usedMethods = Set(cartManager.paymentSplits.map { $0.method })
        return availableMethods.filter { $0 == split.method || !usedMethods.contains($0) }
    }
    
    // Maps the payment string to a clean SF Symbol icon
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
                // Renders as a static label when there are no other options to choose from, eliminating the chevron entirely
                Label(split.method, systemImage: icon(for: split.method))
                    .frame(maxWidth: 140, alignment: .leading)
                    .foregroundColor(.primary)
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
                .foregroundColor((split.amount ?? 0) == 0 ? .red : .primary)
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
            
            // Swipe-to-delete subtle visual hint (only shows if deletion is possible)
            if cartManager.paymentSplits.count > 1 {
                Image(systemName: "chevron.left.2")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.4))
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

@Observable
class PaymentSplitDraft: Identifiable {
    let id = UUID()
    var method: String
    var amount: Double?
    
    init(method: String, amount: Double? = nil) {
        self.method = method
        self.amount = amount
    }
}
