//
//  SharedComponents.swift
//  Simple Store
//

import SwiftUI
import UIKit

// MARK: - Tagging & Categorization

/// A highly reusable visual tag component that generates a consistent, deterministic background color based on the provided string.
@MainActor
public struct TagPillView: View {
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
    
    public var body: some View {
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

/// A horizontal scrolling row of tags, completely decoupled from the data layer.
@MainActor
public struct FormTagRow: View {
    public let tagNames: [String]
    
    public init(tagNames: [String]) {
        self.tagNames = tagNames
    }
    
    public var body: some View {
        if tagNames.isEmpty {
            Text("No tags selected")
                .foregroundColor(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tagNames, id: \.self) { name in
                        TagPillView(name: name)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Actionable UI Elements

/// A selectable filter pill used primarily in horizontal scroll views for scoping list data.
@MainActor
public struct FilterPill: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void
    
    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
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

/// A contact row that copies its value to the clipboard and provides modern haptic and visual feedback.
@MainActor
public struct CopyableContactRow: View {
    public let icon: String
    public let value: String
    
    @State private var showCopiedIndicator = false
    
    public init(icon: String, value: String) {
        self.icon = icon
        self.value = value
    }
    
    public var body: some View {
        Button(action: {
            UIPasteboard.general.string = value
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            withAnimation { showCopiedIndicator = true }
            
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation {
                    showCopiedIndicator = false
                }
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

/// A circular photo selection button utilized heavily in data creation and editing forms.
@MainActor
public struct ItemPhotoSelectionButton: View {
    public let imageData: Data?
    public let action: () -> Void
    
    public init(imageData: Data?, action: @escaping () -> Void) {
        self.imageData = imageData
        self.action = action
    }
    
    public var body: some View {
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

// MARK: - Custom Input Fields

/// A modern, reusable text field with a prominent title and an integrated clear button.
@MainActor
public struct ModernTextField: View {
    public let title: String
    public let placeholder: String
    @Binding public var text: String
    
    public init(title: String, placeholder: String, text: Binding<String>) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
    }
    
    public var body: some View {
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

/// A modern, reusable currency field with a prominent title, currency symbol, and integrated clear button.
@MainActor
public struct ModernCurrencyField: View {
    public let title: String
    @Binding public var text: String
    
    public init(title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack {
                Text(Locale.current.currencySymbol ?? "$")
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

/// A highly customized stepper view optimized for fast, accurate inventory stock adjustments.
@MainActor
public struct ItemStockStepper<Field: Hashable>: View {
    @Binding public var stockCount: Int
    public var focusedField: FocusState<Field?>.Binding
    public var equals: Field
    
    public init(stockCount: Binding<Int>, focusedField: FocusState<Field?>.Binding, equals: Field) {
        self._stockCount = stockCount
        self.focusedField = focusedField
        self.equals = equals
    }
    
    public var body: some View {
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
                    .focused(focusedField, equals: equals)
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

// MARK: - Advanced Analytics UI Components

public enum OrderFilterTab: String, CaseIterable, Identifiable {
    case all = "All Time"
    case year = "This Year"
    case month = "This Month"
    case week = "This Week"
    public var id: String { self.rawValue }
}

/// A shared, fluid filter bar utilizing Apple's glassmorphism aesthetics and matched geometry effects.
@MainActor
public struct GlassSalesFilterView: View {
    @Binding public var selectedTab: OrderFilterTab
    @Binding public var searchText: String
    
    @Namespace private var animation
    
    public init(selectedTab: Binding<OrderFilterTab>, searchText: Binding<String>) {
        self._selectedTab = selectedTab
        self._searchText = searchText
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                TextField("Search name, date, amount...", text: $searchText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                
                if !searchText.isEmpty {
                    Button {
                        withAnimation(.snappy) { searchText = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 16))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
            
            // Fluid Tab Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OrderFilterTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        } label: {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .bold : .medium)
                                .foregroundStyle(selectedTab == tab ? Color(uiColor: .systemBackground) : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background {
                                    if selectedTab == tab {
                                        Capsule()
                                            .fill(Color.primary)
                                            .matchedGeometryEffect(id: "TAB", in: animation)
                                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                    } else {
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                Capsule().stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                            )
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }
}
