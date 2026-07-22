//
//  CSVEngine.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import Foundation

struct CSVEngine {
    
    static func generate(from transactions: [Transaction], timeframeLabel: String, storeName: String = "Simple Inventory") async throws -> URL {
        return try await Task.detached(priority: .userInitiated) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            let generatedDateString = dateFormatter.string(from: Date())
            
            var csvText = """
            Store Name,\(storeName)
            Timeframe,\(timeframeLabel)
            Generated On,\(generatedDateString)
            
            Transaction ID,Date,Item Name,Quantity,Price Per Unit,Transaction Total,Payment Methods,Customer,Employee,Employee ID\n
            """
            
            for transaction in transactions {
                let txId = transaction.id.uuidString.prefix(8)
                let date = dateFormatter.string(from: transaction.date)
                let total = String(format: "%.2f", transaction.totalAmount)
                
                let methods = transaction.payments?.compactMap { $0.method }.joined(separator: " + ") ?? "N/A"
                
                let employee = transaction.employeeName?.replacingOccurrences(of: "\"", with: "\"\"") ?? "N/A"
                let employeeId = transaction.employeeId?.replacingOccurrences(of: "\"", with: "\"\"") ?? "N/A"
                let customer = transaction.customer?.fullName.replacingOccurrences(of: "\"", with: "\"\"") ?? "Walk-in"
                
                if let items = transaction.lineItems, !items.isEmpty {
                    for lineItem in items {
                        let item = lineItem.itemName.replacingOccurrences(of: "\"", with: "\"\"")
                        let qty = "\(lineItem.quantity)"
                        let price = String(format: "%.2f", lineItem.pricePerUnit)
                        
                        let row = "\"\(txId)\",\"\(date)\",\"\(item)\",\(qty),\(price),\(total),\"\(methods)\",\"\(customer)\",\"\(employee)\",\"\(employeeId)\"\n"
                        csvText.append(row)
                    }
                } else {
                    let row = "\"\(txId)\",\"\(date)\",\"No Items\",0,0.00,\(total),\"\(methods)\",\"\(customer)\",\"\(employee)\",\"\(employeeId)\"\n"
                    csvText.append(row)
                }
            }
            
            let safeLabel = timeframeLabel.replacingOccurrences(of: " ", with: "")
            let dateFormatterFile = DateFormatter()
            dateFormatterFile.dateFormat = "yyyy-MM-dd"
            
            let fileName = "Sales_Report_\(safeLabel)_\(dateFormatterFile.string(from: Date())).csv"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        }.value
    }
}
