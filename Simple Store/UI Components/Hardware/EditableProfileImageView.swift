//
//  EditableProfileImageView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI
import PhotosUI

struct EditableProfileImageView: View {
    @Binding var imageData: Data?
    
    @State private var isShowingMenu = false
    @State private var isShowingCamera = false
    @State private var isShowingLibrary = false
    @State private var isShowingFiles = false
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var inputImage: UIImage? = nil
    @State private var isShowingCropView = false
    
    var body: some View {
        HStack {
            Spacer()
            
            ZStack(alignment: .topTrailing) {
                Button(action: { isShowingMenu = true }) {
                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    } else {
                        VStack {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            Text("Add Photo")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .frame(width: 120, height: 120)
                    }
                }
                .buttonStyle(.plain)
                
                if imageData != nil {
                    Button(action: {
                        withAnimation { imageData = nil }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                            .background(Circle().fill(Color.white))
                            .shadow(radius: 2)
                    }
                    .offset(x: 4, y: -4)
                    .buttonStyle(.borderless)
                }
            }
            
            Spacer()
        }
        .confirmationDialog("Choose Photo Source", isPresented: $isShowingMenu) {
            Button("Take Picture") { isShowingCamera = true }
            Button("Photo Library") { isShowingLibrary = true }
            Button("Choose from Files") { isShowingFiles = true }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $isShowingLibrary, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                if let loadedData = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: loadedData) {
                    inputImage = uiImage
                }
            }
        }
        .fileImporter(isPresented: $isShowingFiles, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result, url.startAccessingSecurityScopedResource() {
                if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                    inputImage = uiImage
                }
                url.stopAccessingSecurityScopedResource()
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraBridge(inputImage: $inputImage)
                .ignoresSafeArea()
        }
        .onChange(of: inputImage) { oldValue, newValue in
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isShowingCropView = true
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingCropView) {
            if let inputImage {
                ImageCropView(image: inputImage, croppedData: $imageData, parentInputImage: $inputImage)
            }
        }
    }
}

// MARK: - Crop Engine

struct ImageCropView: View {
    let image: UIImage
    @Binding var croppedData: Data?
    @Binding var parentInputImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                cropCanvas
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
                    Button("Cancel") { cleanupAndDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveCrop() }
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
        let circularView = cropCanvas
            .mask(Circle())
            .frame(width: 300, height: 300)
        
        let renderer = ImageRenderer(content: circularView)
        renderer.scale = 2.0
        
        if let croppedUIImage = renderer.uiImage {
            croppedData = croppedUIImage.pngData()
        }
        cleanupAndDismiss()
    }
    
    private func cleanupAndDismiss() {
        parentInputImage = nil
        dismiss()
    }
}

// MARK: - Camera Bridge

struct CameraBridge: UIViewControllerRepresentable {
    @Binding var inputImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraBridge
        init(_ parent: CameraBridge) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.inputImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
