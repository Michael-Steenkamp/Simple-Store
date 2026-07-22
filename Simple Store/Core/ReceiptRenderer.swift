//
//  ReceiptRenderer.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI
import PDFKit

struct ReceiptRenderer {
    
    @MainActor
    static func generatePDF(from transaction: Transaction) -> URL? {
        
        // Use the single source of truth template, wrapped with a clean print margin
        let receiptContent = ReceiptTemplateView(transaction: transaction)
            .padding(20)
            .frame(width: 340) // 300 base width + 40 padding margin
            .background(Color.white)
        
        let renderer = ImageRenderer(content: receiptContent)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Receipt_\(UUID().uuidString).pdf")
        
        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            guard let pdf = CGContext(tempURL as CFURL, mediaBox: &box, nil) else { return }
            
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        
        return tempURL
    }
}
