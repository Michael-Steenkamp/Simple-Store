//
//  LaunchRouterView.swift
//  Simple Store
//

import SwiftUI

/// The root routing component responsible for directing the user to the appropriate screen.
///
/// `LaunchRouterView` monitors the `SessionManager`'s authentication and multi-tenant workspace state
/// to seamlessly transition between the authentication flow, tenant selection, and the active storefront.
struct LaunchRouterView: View {
    
    // MARK: - Environment
    
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    // MARK: - State
    
    /// Controls the global visibility of the splash screen (only `true` on the initial cold boot).
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            ToastOverlayView()
                .zIndex(10)
            
            // MARK: - Main Application Content
            if let user = session.currentUser {
                if user.activeStoreId == nil {
                    if user.storeIds.isEmpty {
                        StoreSelectionView(isPresentedModally: false)
                    } else {
                        MyStoresView(isPresentedFromProfile: false)
                    }
                } else {
                    StorefrontView()
                        .id(user.activeStoreId)
                        .transition(.opacity)
                }
            } else {
                AuthenticationView()
            }
            
            // MARK: - Global Splash Screen Overlay
            if showSplash {
                SplashScreenView(isPresented: $showSplash)
                    .zIndex(2)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: session.currentUser?.activeStoreId)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.isLoading || showSplash ? "Loading Application" : "Simple Store Application")
        .task {
            // Initial App Launch Sequence
            try? await Task.sleep(for: .seconds(1.5))
            
            // Enforce a strict 3-second timeout to prevent the splash screen from hanging indefinitely during offline boots.
            let startTime = Date()
            while session.isLoading {
                if Date().timeIntervalSince(startTime) > 3.0 { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                showSplash = false
            }
        }
    }
}
