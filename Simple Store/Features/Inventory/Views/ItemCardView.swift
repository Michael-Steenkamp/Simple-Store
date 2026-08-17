//
//  ItemCardView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// A compact, stylized visual representation of an inventory item.
/// Actively bypasses transient caches, intercepting remote URLs to populate permanent local binary storage for offline POS continuity.
struct ItemCardView: View {
    let item: StoreItem
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                
                // MARK: - Cloud-Ready Image Loading
                if let data = item.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 110)
                        .clipped()
                } else if let urlString = item.imageURL, URL(string: urlString) != nil, urlString != "OFFLINE_CACHE" {
                    Color(uiColor: .secondarySystemBackground)
                        .frame(height: 110)
                        .overlay(ProgressView())
                        .clipped()
                        .task(id: urlString) {
                            await cacheImage(from: urlString)
                        }
                } else {
                    Color(uiColor: .secondarySystemBackground)
                        .frame(height: 110)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.gray.opacity(0.5))
                        )
                        .clipped()
                }
                
                if item.stockCount <= 0 {
                    Text("Out of Stock")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.85))
                        .foregroundStyle(.white)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(item.salesPrice, format: .currency(code: "CAD"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                
                Text("\(item.stockCount) In Stock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fontWeight(.light)
            }
            .padding(8)
            .frame(height: 55, alignment: .top)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
    
    /// Converts a remote storage URL into local SwiftData binary storage and securely persists the context.
    private func cacheImage(from urlString: String) async {
        guard item.imageData == nil, let url = URL(string: urlString) else { return }
        
        do {
            let request = URLRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if UIImage(data: data) != nil {
                    await MainActor.run {
                        item.imageData = data
                        try? item.modelContext?.save()
                    }
                }
            }
        } catch {
            // Degrades gracefully, allowing the user to try again on the next view instantiation.
        }
    }
}
