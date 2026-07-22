//
//  ReceiptCustomizationView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI

struct ReceiptCustomizationView: View {
    @AppStorage("receiptThankYou") private var receiptThankYou: String = ""
    @AppStorage("receiptReturnPolicy") private var receiptReturnPolicy: String = ""
    
    @AppStorage("showLogoOnReceipt") private var showLogoOnReceipt: Bool = true
    @AppStorage("showAddressOnReceipt") private var showAddressOnReceipt: Bool = true
    @AppStorage("showWebsiteOnReceipt") private var showWebsiteOnReceipt: Bool = true
    @AppStorage("showCashierOnReceipt") private var showEmployeeOnReceipt: Bool = true
    
    var body: some View {
        Form {
            Section(
                header: Text("Custom Messaging"),
                footer: Text("This text will appear at the top and bottom of your generated PDF receipts.")
            ) {
                VStack(alignment: .leading) {
                    Text("Header Message")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. Thank you for your business!", text: $receiptThankYou, axis: .vertical)
                }
                
                VStack(alignment: .leading) {
                    Text("Footer / Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. No returns on opened items.", text: $receiptReturnPolicy, axis: .vertical)
                }
            }
            
            Section(
                header: Text("Layout & Visibility"),
                footer: Text("Toggle which parts of your Store Profile are included on the receipt.")
            ) {
                Toggle("Show Store Logo", isOn: $showLogoOnReceipt)
                Toggle("Show Physical Address", isOn: $showAddressOnReceipt)
                Toggle("Show Website Link", isOn: $showWebsiteOnReceipt)
                Toggle("Show \"Served By\" Name", isOn: $showEmployeeOnReceipt)
            }
        }
        .navigationTitle("Receipt Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
