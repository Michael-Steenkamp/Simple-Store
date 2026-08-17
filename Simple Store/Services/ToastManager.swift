//
//  ToastManager.swift
//  Simple Store
//

import SwiftUI

/// Defines the visual semantics of a transient toast notification.
public enum ToastStyle {
    case info, success, warning, error
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

/// A centralized, thread-safe manager for dispatching ephemeral on-screen notifications.
@MainActor
@Observable
public final class ToastManager {
    public static let shared = ToastManager()
    
    public struct Toast: Identifiable, Equatable {
        public let id = UUID()
        public var message: String
        public var style: ToastStyle
    }
    
    public var currentToast: Toast?
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    /// Dispatches a transient UI banner that safely auto-dismisses.
    public func show(message: String, style: ToastStyle = .info, duration: TimeInterval = 3.0) {
        withAnimation(.snappy) {
            currentToast = Toast(message: message, style: style)
        }
        
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) {
                self.currentToast = nil
            }
        }
    }
}

/// A dedicated View layer that renders the active toast in the global environment.
public struct ToastOverlayView: View {
    @State private var toastManager = ToastManager.shared
    
    public var body: some View {
        VStack {
            if let toast = toastManager.currentToast {
                HStack(spacing: 12) {
                    Image(systemName: toast.style.icon)
                        .foregroundStyle(toast.style.color)
                    Text(toast.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
            }
            Spacer()
        }
        .padding(.top, 16)
        .animation(.snappy, value: toastManager.currentToast)
        .allowsHitTesting(false)
    }
}
