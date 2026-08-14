//
//  SplashScreenView.swift
//  Simple Store
//

import SwiftUI

/// A transient launch screen that displays the app's branding with a coordinated entrance animation.
///
/// `SplashScreenView` is typically presented during initial app load and data hydration.
/// The parent router is responsible for dismissing this view by toggling the `isPresented` binding.
struct SplashScreenView: View {
    
    /// Controls the visibility of the splash screen. Managed by the parent router.
    @Binding var isPresented: Bool
    
    // MARK: - Animation State
    
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "storefront.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 10, y: 5)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                
                Text("Simple Store")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .opacity(textOpacity)
            }
        }
        .task {
            await animateEntrance()
        }
    }
    
    // MARK: - Animations
    
    /// Triggers the staggered entrance animations for the splash screen assets.
    @MainActor
    private func animateEntrance() async {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Suspend the execution context safely to stagger the text fade-in
        try? await Task.sleep(for: .milliseconds(300))
        
        withAnimation(.easeOut(duration: 0.5)) {
            textOpacity = 1.0
        }
    }
}
