//
//  SplashScreenView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-22.
//

import SwiftUI

struct SplashScreenView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var isActive = false
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        if isActive {
            if hasCompletedOnboarding {
                StorefrontView()
            } else {
                OnboardingView()
            }
        } else {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "storefront.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                    
                    Text("Simple Store")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.blue)
                        .opacity(textOpacity)
                }
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        iconScale = 1.0
                        iconOpacity = 1.0
                    }
                    
                    withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                        textOpacity = 1.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isActive = true
                        }
                    }
                }
            }
        }
    }
}
