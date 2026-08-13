//
//  CSVEngine.swift
//  Simple Store
//

import Foundation

/// A utility namespace for generating CSV reports asynchronously.
enum CSVEngine {
    
    /// Generates a CSV file containing transaction data and saves it to the temporary directory.
    ///
    /// - Parameters:
    ///   - transactions: An array of `Transaction` records to be included in the report.
    ///   - timeframeLabel: A string describing the time period (e.g., "July 2026", "Q3").
    ///   - storeName: The name of the store. Defaults to "Simple Store".
    /// - Returns: The local `URL` pointing to the generated CSV file in the temporary directory.
    static func generate(
        from transactions: [Transaction],
        timeframeLabel: String,
        storeName: String = "Simple Store"
    ) async throws -> URL {
        
        return try await Task.detached(priority: .userInitiated) {
            
            // MARK: - Local Helpers (Swift 6 Concurrency Safe)
            
            func escapeCSV(_ value: String) -> String {
                let escapedString = value.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escapedString)\""
            }
            
            func buildRow(_ values: [String]) -> String {
                return values.map { escapeCSV($0) }.joined(separator: ",") + "\n"
            }
            
            // MARK: - CSV Generation
            
            let generatedDateString = Date().formatted(date: .abbreviated, time: .shortened)
            
            var csvText = """
            Store Name,\(escapeCSV(storeName))
            Timeframe,\(escapeCSV(timeframeLabel))
            Generated On,\(escapeCSV(generatedDateString))
            
            Transaction ID,Date,Item Name,Quantity,Price Per Unit,Transaction Total,Payment Methods,Customer,Employee,Employee ID\n
            """
            
            for transaction in transactions {
                // Ensure task can be cancelled if processing a massive dataset
                try Task.checkCancellation()
                
                let txId = String(transaction.id.uuidString.prefix(8))
                let date = transaction.date.formatted(date: .abbreviated, time: .shortened)
                let total = String(format: "%.2f", transaction.totalAmount)
                
                let methods = transaction.payments?.compactMap(\.method).joined(separator: " + ") ?? "N/A"
                let employee = transaction.employeeName ?? "N/A"
                let employeeId = transaction.employeeId ?? "N/A"
                let customer = transaction.customer?.fullName ?? "Walk-in"
                
                if let items = transaction.lineItems, !items.isEmpty {
                    for lineItem in items {
                        let item = lineItem.itemName
                        let qty = "\(lineItem.quantity)"
                        let price = String(format: "%.2f", lineItem.pricePerUnit)
                        
                        csvText.append(buildRow([txId, date, item, qty, price, total, methods, customer, employee, employeeId]))
                    }
                } else {
                    csvText.append(buildRow([txId, date, "No Items", "0", "0.00", total, methods, customer, employee, employeeId]))
                }
            }
            
            // Modern string replacing and iOS 16+ URL appending
            let safeLabel = timeframeLabel.replacing(#/\s+/#, with: "")
            let dateString = Date().formatted(.iso8601.year().month().day())
            let fileName = "Sales_Report_\(safeLabel)_\(dateString).csv"
            
            let tempURL = FileManager.default.temporaryDirectory.appending(path: fileName)
            
            try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        }.value
    }
}
