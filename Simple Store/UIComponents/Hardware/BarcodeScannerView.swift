//
// BarcodeScannerView.swift
// Simple Store
//

import SwiftUI
import VisionKit

/// A reusable, standalone barcode scanner view that leverages VisionKit for high-performance scanning.
/// This view automatically handles camera permissions, UI overlays, and gracefully falls back on unsupported devices.
@MainActor
public struct BarcodeScannerView: View {
    @Binding public var scannedCode: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var refocusTrigger = false
    @State private var focusLocation: CGPoint? = nil
    @State private var isShowingFocus = false
    
    public init(scannedCode: Binding<String>) {
        self._scannedCode = scannedCode
    }
    
    public var body: some View {
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
    
    /// The primary scanning interface featuring a visual reticle and tap-to-focus capabilities.
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
            
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                isShowingFocus = false
            }
        }
    }
    
    /// A fallback view presented when VisionKit or camera hardware is unavailable on the current device.
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

/// A thread-safe, concurrency-compliant bridge integrating `DataScannerViewController` into the SwiftUI environment.
@MainActor
public struct DataScannerBridge: UIViewControllerRepresentable {
    @Binding public var scannedCode: String
    @Binding public var refocusTrigger: Bool
    public var onRecognized: () -> Void
    
    public func makeUIViewController(context: Context) -> DataScannerViewController {
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
    
    public func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if context.coordinator.lastRefocusTrigger != refocusTrigger {
            context.coordinator.lastRefocusTrigger = refocusTrigger
            uiViewController.stopScanning()
            
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                try? uiViewController.startScanning()
            }
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// The delegate coordinator responsible for managing VisionKit callbacks and safely crossing Swift 6 actor boundaries.
    public class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerBridge
        var lastRefocusTrigger: Bool = false
        
        init(_ parent: DataScannerBridge) {
            self.parent = parent
        }
        
        @MainActor
        public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            if let firstItem = addedItems.first,
               case .barcode(let barcode) = firstItem,
               let codeString = barcode.payloadStringValue {
                
                Task { @MainActor in
                    self.parent.scannedCode = codeString
                    self.parent.onRecognized()
                }
            }
        }
    }
}
