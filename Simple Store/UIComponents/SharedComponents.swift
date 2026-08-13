//
//  SharedComponents.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI

// MARK: - Tags & Labels

struct TagPillView: View {
    let name: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag.fill")
                .font(.system(size: 10))
            Text(name)
                .font(.caption2.weight(.semibold))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(colorForTag.opacity(0.15))
        .foregroundColor(colorForTag)
        .clipShape(Capsule())
    }
    
    private var colorForTag: Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .indigo, .teal]
        let stableHash = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[stableHash % colors.count]
    }
}

struct FormTagRow: View {
    let tags: [ItemTag]
    
    var body: some View {
        if tags.isEmpty {
            Text("No tags selected")
                .foregroundColor(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags) { tag in
                        TagPillView(name: tag.name)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Interactive Filter Elements

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(UIColor.secondarySystemFill))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.blue.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CRM & Contact Elements

struct CopyableContactRow: View {
    let icon: String
    let value: String
    
    @State private var showCopiedIndicator = false
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = value
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            withAnimation { showCopiedIndicator = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopiedIndicator = false }
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(value)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if showCopiedIndicator {
                    Text("Copied!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Text Fields

struct ModernTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack {
                TextField(placeholder, text: $text)
                    .font(.body)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct ModernCurrencyField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack {
                Text("$")
                    .foregroundColor(.secondary)
                
                TextField("0.00", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.body)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Inventory Form Elements

struct ItemPhotoSelectionButton: View {
    let imageData: Data?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let data = imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "photo.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color(UIColor.systemGray4))
                }
                
                Text(imageData == nil ? "Add Photo" : "Edit")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.secondarySystemFill))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
            }
        }
    }
}

struct ItemStockStepper<Field: Hashable>: View {
    @Binding var stockCount: Int
    var focusedField: FocusState<Field?>.Binding
    var equals: Field
    
    var body: some View {
        HStack {
            Text("Stock")
                .font(.headline)
            Spacer()
            HStack(spacing: 12) {
                Button(action: { if stockCount > 0 { stockCount -= 1 } }) {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                TextField("0", value: $stockCount, format: .number)
                    .keyboardType(.numberPad)
                    .focused(focusedField, equals: equals) // Safely applies the enum match
                    .multilineTextAlignment(.center)
                    .font(.title2.weight(.bold))
                    .frame(width: 60)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(8)
                
                Button(action: { stockCount += 1 }) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
