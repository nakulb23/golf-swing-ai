//
//  MinimalLaunchScreen.swift
//  Golf Swing AI
//
//  Created on 6/9/25.
//

import SwiftUI

struct MinimalLaunchScreen: View {
    @State private var isActive = false
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var progressValue: Double = 0.0
    @State private var showProgress = false
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        if isActive {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
        } else {
            ZStack {
                // Clean background that adapts to theme
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Logo Section
                    VStack(spacing: 24) {
                        // Golf icon
                        Image(systemName: "figure.golf")
                            .font(.system(size: 64, weight: .ultraLight))
                            .foregroundColor(.primary)
                            .opacity(logoOpacity)
                        
                        // App name
                        VStack(spacing: 8) {
                            Text("AI Golf")
                                .font(.system(size: 32, weight: .light, design: .rounded))
                                .foregroundColor(.primary)
                                .opacity(textOpacity)
                            
                            Text("Intelligent Golf Analysis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .opacity(textOpacity)
                        }
                    }
                    
                    Spacer()
                    
                    // Loading Section
                    VStack(spacing: 16) {
                        if showProgress {
                            // Progress Bar
                            ZStack(alignment: .leading) {
                                // Background track
                                Capsule()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 200, height: 3)
                                
                                // Progress fill
                                Capsule()
                                    .fill(Color.primary)
                                    .frame(width: 200 * progressValue, height: 3)
                                    .animation(.easeInOut(duration: 0.3), value: progressValue)
                            }
                            
                            // Loading text
                            Text("Loading...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .opacity(textOpacity)
                        }
                    }
                    .padding(.bottom, 80)
                }
                .padding(.horizontal, 40)
            }
            .onAppear {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        // Logo fade in
        withAnimation(.easeOut(duration: 0.8)) {
            logoOpacity = 1.0
        }
        
        // Text fade in
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            textOpacity = 1.0
        }
        
        // Show progress bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showProgress = true
            }
            
            // Animate progress
            animateProgress()
        }
        
        // Navigate to main app
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.6)) {
                isActive = true
            }
        }
    }
    
    private func animateProgress() {
        // Simulate loading progress with realistic timing
        let progressSteps = [0.3, 0.6, 0.85, 1.0]
        let delays = [0.2, 0.5, 0.8, 1.2]
        
        for (index, step) in progressSteps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delays[index]) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    progressValue = step
                }
            }
        }
    }
}

#Preview {
    MinimalLaunchScreen()
        .environmentObject(AuthenticationManager())
        .environmentObject(ThemeManager())
}