//
//  ItemCardView.swift
//  Simple Store
//

import SwiftUI

/// A compact, stylized visual representation of an inventory item.
/// Supports asynchronous image loading from Firebase Storage when local caching is unavailable.
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
                } else if let urlString = item.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 110)
                                .clipped()
                        } else if phase.error != nil {
                            Color(uiColor: .secondarySystemBackground)
                                .frame(height: 110)
                                .overlay(
                                    Image(systemName: "photo.badge.exclamationmark")
                                        .foregroundStyle(.gray.opacity(0.5))
                                )
                                .clipped()
                        } else {
                            Color(uiColor: .secondarySystemBackground)
                                .frame(height: 110)
                                .overlay(ProgressView())
                                .clipped()
                        }
                    }
                } else {
                    Color(uiColor: .secondarySystemBackground)
                        .frame(height: 110)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.gray.opacity(0.5))
                        )
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
}
