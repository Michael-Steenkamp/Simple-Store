//
// ImagePicker.swift
// Simple Store
//

import SwiftUI
import PhotosUI

/// A modular, concurrency-safe wrapper that seamlessly transitions between native image selection and a custom cropping interface.
@MainActor
public struct ImagePicker: View {
    public var sourceType: UIImagePickerController.SourceType
    @Binding public var selectedImage: Data?
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputImage: UIImage? = nil
    @State private var isShowingCropView = false
    
    public init(sourceType: UIImagePickerController.SourceType, selectedImage: Binding<Data?>) {
        self.sourceType = sourceType
        self._selectedImage = selectedImage
    }
    
    public var body: some View {
        ZStack {
            if isShowingCropView, let inputImage = inputImage {
                ImageCropView(
                    image: inputImage,
                    croppedData: $selectedImage,
                    onDismiss: { dismiss() }
                )
                .transition(.opacity)
            } else {
                NativeImagePicker(sourceType: sourceType, inputImage: $inputImage)
                    .ignoresSafeArea()
                    .onChange(of: inputImage) { _, newValue in
                        if newValue != nil {
                            withAnimation {
                                isShowingCropView = true
                            }
                        }
                    }
            }
        }
    }
}

/// A thread-safe bridge to UIKit's `UIImagePickerController`, fully isolated to the main actor to prevent data races during image selection.
@MainActor
public struct NativeImagePicker: UIViewControllerRepresentable {
    public var sourceType: UIImagePickerController.SourceType
    @Binding public var inputImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    public init(sourceType: UIImagePickerController.SourceType, inputImage: Binding<UIImage?>) {
        self.sourceType = sourceType
        self._inputImage = inputImage
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// The delegate coordinator responsible for handling media selection lifecycle events and safely propagating the data back to SwiftUI.
    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: NativeImagePicker
        
        init(_ parent: NativeImagePicker) {
            self.parent = parent
        }
        
        @MainActor
        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.inputImage = image
            } else {
                parent.dismiss()
            }
        }
        
        @MainActor
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// A hardware-accelerated interactive view for precise image cropping and scaling, leveraging `@MainActor` bound `ImageRenderer` for deterministic exports.
@MainActor
public struct ImageCropView: View {
    public let image: UIImage
    @Binding public var croppedData: Data?
    public var onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    public init(image: UIImage, croppedData: Binding<Data?>, onDismiss: @escaping () -> Void) {
        self.image = image
        self._croppedData = croppedData
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                cropCanvas
                    // Circular guide overlay for preview framing
                    .mask(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                    .shadow(radius: 10)
                
                Spacer()
                
                Text("Pinch to zoom, drag to pan.")
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Move and Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveCrop() }
                        .fontWeight(.bold)
                }
            }
        }
    }
    
    /// The interactive image canvas utilizing modern gesture modifiers for smooth pan and zoom operations.
    private var cropCanvas: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 300, height: 300)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        offset = CGSize(width: lastOffset.width + val.translation.width,
                                        height: lastOffset.height + val.translation.height)
                    }
                    .onEnded { _ in lastOffset = offset }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { val in scale = max(1.0, lastScale * val) }
                    .onEnded { _ in lastScale = scale }
            )
            .clipped()
    }
    
    private func saveCrop() {
        // Renders the 300x300 square content so item cards display cleanly
        let squareView = cropCanvas
            .frame(width: 300, height: 300)
        
        let renderer = ImageRenderer(content: squareView)
        renderer.scale = 3.0
        
        if let croppedUIImage = renderer.uiImage {
            croppedData = croppedUIImage.jpegData(compressionQuality: 0.8) ?? croppedUIImage.pngData()
        }
        
        onDismiss()
    }
}
