//
//  ReceiptTemplateView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI

struct ReceiptTemplateView: View {
    let transaction: Transaction
    
    @AppStorage("storeName") private var storeName: String = "Simple Inventory"
    @AppStorage("storeAddress") private var storeAddress: String = ""
    @AppStorage("storeWebsite") private var storeWebsite: String = ""
    @AppStorage("storeLogo") private var logoData: Data?
    
    @AppStorage("receiptThankYou") private var receiptThankYou: String = "Thank you for your business!"
    @AppStorage("receiptReturnPolicy") private var receiptReturnPolicy: String = "Returns accepted within 30 days with original receipt."
    
    @AppStorage("showLogoOnReceipt") private var showLogoOnReceipt: Bool = true
    @AppStorage("showAddressOnReceipt") private var showAddressOnReceipt: Bool = true
    @AppStorage("showWebsiteOnReceipt") private var showWebsiteOnReceipt: Bool = true
    @AppStorage("showCashierOnReceipt") private var showCashierOnReceipt: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // MARK: - Header
            VStack(spacing: 4) {
                if showLogoOnReceipt {
                    if let data = logoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                            .clipShape(Circle())
                            .padding(.bottom, 8)
                    } else {
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 24))
                            .padding(.bottom, 4)
                    }
                }
                
                Text(storeName)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                
                if showAddressOnReceipt && !storeAddress.isEmpty {
                    Text(storeAddress)
                        .font(.system(size: 10, design: .monospaced))
                        .multilineTextAlignment(.center)
                }
                
                if showWebsiteOnReceipt && !storeWebsite.isEmpty {
                    Text(storeWebsite)
                        .font(.system(size: 10, design: .monospaced))
                }
                
                Text("Receipt of Sale")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10, design: .monospaced))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 10)
            
            Divider()
            
            // MARK: - Customer Info
            if let customer = transaction.customer {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Customer: \(customer.fullName)")
                    if !customer.email.isEmpty {
                        Text(customer.email)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(.bottom, 5)
                Divider()
            }
            
            // MARK: - Line Items
            HStack {
                Text("Item")
                Spacer()
                Text("Qty")
                    .frame(width: 30, alignment: .center)
                Text("Price")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            
            if let items = transaction.lineItems {
                ForEach(items) { lineItem in
                    HStack(alignment: .top) {
                        Text(lineItem.itemName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(lineItem.quantity)")
                            .frame(width: 30, alignment: .center)
                        Text((Double(lineItem.quantity) * lineItem.pricePerUnit), format: .currency(code: "CAD"))
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.system(size: 12, design: .monospaced))
                }
            }
            
            Divider()
            
            // MARK: - Totals & Payment
            HStack {
                Text("Total")
                    .fontWeight(.bold)
                Spacer()
                Text(transaction.totalAmount, format: .currency(code: "CAD"))
                    .fontWeight(.bold)
            }
            .font(.system(size: 14, design: .monospaced))
            
            if let payments = transaction.payments, !payments.isEmpty {
                VStack(spacing: 2) {
                    ForEach(payments) { payment in
                        HStack {
                            Text(payment.method)
                            Spacer()
                            Text(payment.amount, format: .currency(code: "CAD"))
                        }
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(.top, 4)
            }
            
            if showCashierOnReceipt, let employee = transaction.employeeName, !employee.isEmpty {
                HStack {
                    Text("Served by")
                    Spacer()
                    Text(employee)
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(.top, 4)
            }
            
            Divider()
            
            // MARK: - Footer
            VStack(spacing: 6) {
                if !receiptThankYou.isEmpty {
                    Text(receiptThankYou)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                }
                
                if !receiptReturnPolicy.isEmpty {
                    Text(receiptReturnPolicy)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 10)
        }
        .padding(24)
        .frame(width: 300)
        .background(Color.white)
        .foregroundColor(.black)
    }
}
