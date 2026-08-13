//
//  ImagePicker.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI
import PhotosUI

// MARK: - Global Picker Wrapper
struct ImagePicker: View {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: Data?
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputImage: UIImage? = nil
    @State private var isShowingCropView = false
    
    var body: some View {
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

// MARK: - Native Image Picker
struct NativeImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var inputImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: NativeImagePicker
        
        init(_ parent: NativeImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.inputImage = image
            } else {
                parent.dismiss()
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Image Crop View with Circular Guide Overlay
struct ImageCropView: View {
    let image: UIImage
    @Binding var croppedData: Data?
    var onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
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
    
    var cropCanvas: some View {
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
    
    @MainActor
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
