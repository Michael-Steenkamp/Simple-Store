//
//  ReceiptRenderer.swift
//  Simple Store
//

import SwiftUI
import CoreGraphics

/// A utility namespace for rendering SwiftUI views into PDF documents.
enum ReceiptRenderer {
    
    /// Generates a PDF document from a transaction receipt template.
    ///
    /// This method must be executed on the MainActor as it relies on `ImageRenderer`,
    /// which requires access to the underlying UI context.
    ///
    /// - Parameter transaction: The `Transaction` record to render.
    /// - Returns: A local `URL` pointing to the generated PDF file, or `nil` if the rendering context fails.
    @MainActor
    static func generatePDF(for transaction: Transaction) -> URL? {
        
        let receiptContent = ReceiptTemplateView(transaction: transaction)
            .padding(20)
            .frame(width: 340) // 300 base width + 40 padding margin
            .background(Color.white)
        
        let renderer = ImageRenderer(content: receiptContent)
        
        // Generate a deterministic and traceable file name using the transaction's unique identifier
        let transactionHash = String(transaction.id.uuidString.prefix(8))
        let fileName = "Receipt_\(transactionHash).pdf"
        
        // Modern iOS 16+ URL construction
        let tempURL = FileManager.default.temporaryDirectory.appending(path: fileName)
        
        // Render the SwiftUI view into a CoreGraphics PDF context
        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            
            guard let pdf = CGContext(tempURL as CFURL, mediaBox: &box, nil) else {
                return
            }
            
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        
        return tempURL
    }
}
