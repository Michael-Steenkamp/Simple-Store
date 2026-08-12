//
//  OfflineBannerModifier.swift
//  Simple Store
//

import SwiftUI

struct OfflineBannerModifier: ViewModifier {
    @Environment(NetworkMonitor.self) private var networkMonitor
    
    enum BannerState {
        case hidden
        case offline
        case online
    }
    
    @State private var bannerState: BannerState = .hidden
    
    // Tracks if we've actually dropped connection during this session,
    // so we don't accidentally show "Back Online" the second the app launches.
    @State private var hasBeenOffline = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if bannerState != .hidden {
                    HStack(spacing: 8) {
                        Image(systemName: bannerState == .offline ? "wifi.slash" : "wifi")
                        
                        Text(bannerState == .offline
                             ? "Offline Mode: Changes will sync when reconnected"
                             : "Back Online: Queue syncing...")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        if bannerState == .offline {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial)
                    .background(bannerState == .offline ? Color.orange.opacity(0.8) : Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    // MARK: - Tap to Dismiss (Offline Only)
                    .onTapGesture {
                        if bannerState == .offline {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                bannerState = .hidden
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: bannerState)
            // MARK: - Network State Listener
            .onChange(of: networkMonitor.isConnected) { _, isConnected in
                if !isConnected {
                    hasBeenOffline = true
                    withAnimation {
                        bannerState = .offline
                    }
                } else if isConnected && hasBeenOffline {
                    // Transition to green success banner
                    withAnimation {
                        bannerState = .online
                    }
                    
                    // Auto-dismiss the success banner after 2.5 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(2.5))
                        // Make sure we didn't drop connection again while waiting!
                        if networkMonitor.isConnected {
                            withAnimation {
                                bannerState = .hidden
                            }
                        }
                    }
                }
            }
    }
}

extension View {
    /// Attaches a dynamic, hybrid-dismissible offline/online warning banner to the top of the view.
    func withOfflineBanner() -> some View {
        self.modifier(OfflineBannerModifier())
    }
}
