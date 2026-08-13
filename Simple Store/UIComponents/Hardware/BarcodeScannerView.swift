//
//  BarcodeScannerView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI
import VisionKit

struct BarcodeScannerView: View {
    @Binding var scannedCode: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var refocusTrigger = false
    @State private var focusLocation: CGPoint? = nil
    @State private var isShowingFocus = false
    
    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    scannerInterface
                } else {
                    unsupportedDeviceView
                }
            }
            .navigationTitle("Scan Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Interfaces
    
    private var scannerInterface: some View {
        ZStack {
            DataScannerBridge(scannedCode: $scannedCode, refocusTrigger: $refocusTrigger) {
                dismiss()
            }
            .ignoresSafeArea()
            
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .mask(
                    ZStack {
                        Color.white
                        RoundedRectangle(cornerRadius: 16)
                            .frame(width: 280, height: 160)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
            
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 280, height: 160)
                .overlay(
                    Image(systemName: "viewfinder")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.green)
                )
            
            Text("Center the barcode in the frame.\nTap anywhere to refocus.")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .offset(y: 140)
                .shadow(radius: 2)
            
            if isShowingFocus, let location = focusLocation {
                Rectangle()
                    .stroke(Color.yellow, lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .position(location)
                    .animation(.easeInOut(duration: 0.2), value: isShowingFocus)
            }
        }
        .onTapGesture(coordinateSpace: .global) { location in
            focusLocation = location
            isShowingFocus = true
            refocusTrigger.toggle()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isShowingFocus = false
            }
        }
    }
    
    private var unsupportedDeviceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("Scanner Unavailable")
                .font(.title2)
                .fontWeight(.bold)
            Text("This device does not support the barcode scanner. Please enter the barcode manually.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - VisionKit Bridge

struct DataScannerBridge: UIViewControllerRepresentable {
    @Binding var scannedCode: String
    @Binding var refocusTrigger: Bool
    var onRecognized: () -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let viewController = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        viewController.delegate = context.coordinator
        context.coordinator.lastRefocusTrigger = refocusTrigger
        
        try? viewController.startScanning()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if context.coordinator.lastRefocusTrigger != refocusTrigger {
            context.coordinator.lastRefocusTrigger = refocusTrigger
            uiViewController.stopScanning()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                try? uiViewController.startScanning()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerBridge
        var lastRefocusTrigger: Bool = false
        
        init(_ parent: DataScannerBridge) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            if let firstItem = addedItems.first,
               case .barcode(let barcode) = firstItem,
               let codeString = barcode.payloadStringValue {
                DispatchQueue.main.async {
                    self.parent.scannedCode = codeString
                    self.parent.onRecognized()
                }
            }
        }
    }
}
