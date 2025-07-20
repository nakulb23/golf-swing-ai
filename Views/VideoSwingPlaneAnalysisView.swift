import SwiftUI
import AVFoundation
import UIKit

struct VideoSwingPlaneAnalysisView: View {
    let result: SwingAnalysisResponse
    @Environment(\.dismiss) private var dismiss
    @State private var showPlaneOverlay = true
    @State private var showIdealPlane = true
    @State private var showUserPlane = true
    @State private var animateSwing = false
    @State private var pulseOpacity = 0.3
    @State private var showShareSheet = false
    @State private var showExportOptions = false
    @State private var includeAnalysisOverlay = true
    @State private var exportQuality: ExportQuality = .high
    @State private var isExporting = false
    @State private var exportedVideoURL: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Premium Header with glassmorphism
                    VStack(spacing: 20) {
                        ZStack {
                            // Glassmorphism background
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                            
                            // Animated golf icon
                            Image(systemName: "figure.golf")
                                .font(.system(size: 50, weight: .ultraLight))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan, .indigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(animateSwing ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateSwing)
                        }
                        
                        VStack(spacing: 12) {
                            Text("SWING PLANE ANALYSIS")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.primary, .primary.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .tracking(2)
                            
                            Text("PRECISION GOLF MECHANICS")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .tracking(4)
                                .foregroundColor(.secondary)
                                .opacity(0.8)
                        }
                        
                        Text("Visual comparison of your swing plane vs. optimal trajectory")
                            .font(.system(size: 16, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(.top, 20)
                    .onAppear {
                        animateSwing = true
                    }
                    
                    // Premium Video Analysis Studio
                    VStack(spacing: 24) {
                        // Studio Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ANALYSIS STUDIO")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .tracking(1)
                                
                                Text("Interactive Swing Visualization")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Confidence Badge
                            HStack(spacing: 8) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("\(Int(result.confidence * 100))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [colorForLabel(result.predicted_label), colorForLabel(result.predicted_label).opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: colorForLabel(result.predicted_label).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        // Premium Video Visualization
                        ZStack {
                            // Main container with glassmorphism
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .frame(height: 320)
                                .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.3), .clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                            
                            // Dynamic background gradient
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            colorForLabel(result.predicted_label).opacity(0.1),
                                            .black.opacity(0.7),
                                            .black.opacity(0.9)
                                        ],
                                        center: .center,
                                        startRadius: 50,
                                        endRadius: 200
                                    )
                                )
                                .frame(height: 320)
                                .opacity(pulseOpacity)
                                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: pulseOpacity)
                                .onAppear {
                                    pulseOpacity = 0.7
                                }
                            
                            // Golf Course Environment
                            VStack {
                                Spacer()
                                
                                // Golfer and Swing Analysis
                                HStack {
                                    Spacer()
                                    
                                    ZStack {
                                        // Golfer silhouette with premium styling
                                        VStack(spacing: 8) {
                                            // Head with glow
                                            Circle()
                                                .fill(
                                                    RadialGradient(
                                                        colors: [.white, .white.opacity(0.8)],
                                                        center: .center,
                                                        startRadius: 5,
                                                        endRadius: 15
                                                    )
                                                )
                                                .frame(width: 24, height: 24)
                                                .shadow(color: .white.opacity(0.5), radius: 8, x: 0, y: 0)
                                            
                                            // Body with sophisticated styling
                                            ZStack {
                                                // Main body
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [.white.opacity(0.9), .white.opacity(0.7)],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                                    .frame(width: 18, height: 70)
                                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                                                
                                                // Premium swing plane lines
                                                Group {
                                                    // User's swing plane with dynamic styling
                                                    if showUserPlane {
                                                        RoundedRectangle(cornerRadius: 2)
                                                            .fill(
                                                                LinearGradient(
                                                                    colors: [
                                                                        colorForLabel(result.predicted_label),
                                                                        colorForLabel(result.predicted_label).opacity(0.7)
                                                                    ],
                                                                    startPoint: .top,
                                                                    endPoint: .bottom
                                                                )
                                                            )
                                                            .frame(width: 4, height: 140)
                                                            .rotationEffect(.degrees(result.physics_insights.avg_plane_angle - 90))
                                                            .shadow(color: colorForLabel(result.predicted_label).opacity(0.6), radius: 8, x: 0, y: 0)
                                                            .animation(.spring(response: 1.2, dampingFraction: 0.8), value: showUserPlane)
                                                    }
                                                    
                                                    // Ideal plane with premium styling
                                                    if showIdealPlane {
                                                        RoundedRectangle(cornerRadius: 1.5)
                                                            .fill(
                                                                LinearGradient(
                                                                    colors: [.green, .mint],
                                                                    startPoint: .top,
                                                                    endPoint: .bottom
                                                                )
                                                            )
                                                            .frame(width: 3, height: 120)
                                                            .rotationEffect(.degrees(45 - 90))
                                                            .opacity(0.9)
                                                            .shadow(color: .green.opacity(0.5), radius: 6, x: 0, y: 0)
                                                            .animation(.spring(response: 1.0, dampingFraction: 0.7), value: showIdealPlane)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Angle arc visualization
                                        if showUserPlane && showIdealPlane {
                                            Arc(
                                                startAngle: .degrees(45 - 90),
                                                endAngle: .degrees(result.physics_insights.avg_plane_angle - 90),
                                                clockwise: result.physics_insights.avg_plane_angle > 45
                                            )
                                            .stroke(
                                                colorForLabel(result.predicted_label).opacity(0.4),
                                                style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                                            )
                                            .frame(width: 80, height: 80)
                                            .animation(.easeInOut(duration: 1.5), value: showUserPlane)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Premium ground with texture
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.brown.opacity(0.8), .brown.opacity(0.6), .brown.opacity(0.4)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: 12)
                                    .overlay(
                                        Rectangle()
                                            .fill(.green.opacity(0.3))
                                            .frame(height: 2)
                                            .offset(y: -5)
                                    )
                            }
                            
                            // Sophisticated play button
                            VStack {
                                HStack {
                                    Spacer()
                                    
                                    Button(action: {
                                        // Add haptic feedback
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 70, height: 70)
                                                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
                                            
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.white.opacity(0.4), .clear],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                                .frame(width: 70, height: 70)
                                            
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 28, weight: .medium))
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [.white, .white.opacity(0.8)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .offset(x: 2)
                                        }
                                    }
                                    .scaleEffect(animateSwing ? 1.05 : 1.0)
                                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateSwing)
                                    
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(.top, 30)
                        }
                            
                        // Premium Metrics Panel
                        VStack(spacing: 20) {
                            HStack {
                                HStack(spacing: 12) {
                                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    Text("PLANE METRICS")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .tracking(1)
                                }
                                Spacer()
                            }
                            
                            VStack(spacing: 16) {
                                // Ideal Plane Metric
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.green, .mint],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 16, height: 16)
                                            .shadow(color: .green.opacity(0.4), radius: 4, x: 0, y: 2)
                                        
                                        Circle()
                                            .stroke(.white.opacity(0.6), lineWidth: 1)
                                            .frame(width: 16, height: 16)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("IDEAL RANGE")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .tracking(0.5)
                                        
                                        Text("35° - 55° (Optimal: 45°)")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.green)
                                }
                                
                                // User Plane Metric
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [colorForLabel(result.predicted_label), colorForLabel(result.predicted_label).opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 16, height: 16)
                                            .shadow(color: colorForLabel(result.predicted_label).opacity(0.4), radius: 4, x: 0, y: 2)
                                        
                                        Circle()
                                            .stroke(.white.opacity(0.6), lineWidth: 1)
                                            .frame(width: 16, height: 16)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("YOUR PLANE")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .tracking(0.5)
                                        
                                        Text("\(String(format: "%.1f°", result.physics_insights.avg_plane_angle)) (\(result.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized))")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: result.predicted_label.lowercased() == "on_plane" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(result.predicted_label.lowercased() == "on_plane" ? .green : colorForLabel(result.predicted_label))
                                }
                                
                                // Difference Metric
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.gray, .gray.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 16, height: 16)
                                            .shadow(color: .gray.opacity(0.4), radius: 4, x: 0, y: 2)
                                        
                                        Circle()
                                            .stroke(.white.opacity(0.6), lineWidth: 1)
                                            .frame(width: 16, height: 16)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("DEVIATION")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .tracking(0.5)
                                        
                                        Text("\(String(format: "%.1f°", abs(result.physics_insights.avg_plane_angle - 45))) from optimal")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "ruler")
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Premium Controls Panel
                    VStack(spacing: 24) {
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "slider.horizontal.below.square.filled.and.square")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text("OVERLAY CONTROLS")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .tracking(1)
                            }
                            Spacer()
                        }
                        
                        VStack(spacing: 20) {
                            // Ideal Plane Toggle
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("IDEAL PLANE")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .tracking(0.5)
                                    
                                    Text("Show optimal swing trajectory")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $showIdealPlane)
                                    .toggleStyle(PremiumToggleStyle(color: .green))
                            }
                            
                            Divider()
                                .background(.tertiary)
                            
                            // User Plane Toggle
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("YOUR PLANE")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .tracking(0.5)
                                    
                                    Text("Display your swing analysis")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $showUserPlane)
                                    .toggleStyle(PremiumToggleStyle(color: colorForLabel(result.predicted_label)))
                            }
                            
                            Divider()
                                .background(.tertiary)
                            
                            // All Overlays Toggle
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ALL OVERLAYS")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .tracking(0.5)
                                    
                                    Text("Toggle all visual elements")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $showPlaneOverlay)
                                    .toggleStyle(PremiumToggleStyle(color: .blue))
                                    .onChange(of: showPlaneOverlay) { _, newValue in
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            showIdealPlane = newValue
                                            showUserPlane = newValue
                                        }
                                    }
                            }
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                    )
                    .padding(.horizontal, 20)
                    
                    // Premium Analysis Breakdown
                    VStack(spacing: 24) {
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "brain.head.profile.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text("TECHNICAL ANALYSIS")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .tracking(1)
                            }
                            Spacer()
                        }
                        
                        VStack(spacing: 20) {
                            PremiumAnalysisCard(
                                icon: "target",
                                title: "CURRENT PLANE",
                                subtitle: "\(String(format: "%.1f°", result.physics_insights.avg_plane_angle)) - \(planeDescription())",
                                color: colorForLabel(result.predicted_label),
                                isHighlighted: true
                            )
                            
                            PremiumAnalysisCard(
                                icon: "basketball",
                                title: "BALL FLIGHT IMPACT",
                                subtitle: ballFlightImpact(),
                                color: .orange,
                                isHighlighted: false
                            )
                            
                            PremiumAnalysisCard(
                                icon: "arrow.triangle.turn.up.right.circle",
                                title: "CORRECTION NEEDED",
                                subtitle: correctionNeeded(),
                                color: .blue,
                                isHighlighted: false
                            )
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                    )
                    .padding(.horizontal, 20)
                    
                    // Premium Quick Fixes
                    VStack(spacing: 24) {
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "lightbulb.max.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text("QUICK FIXES")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .tracking(1)
                            }
                            Spacer()
                        }
                        
                        VStack(spacing: 16) {
                            ForEach(Array(quickFixes().enumerated()), id: \.offset) { index, tip in
                                HStack(alignment: .top, spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.green, .mint],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 32, height: 32)
                                            .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
                                        
                                        Text("\(index + 1)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tip)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .lineSpacing(2)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                
                                if index < quickFixes().count - 1 {
                                    Divider()
                                        .background(.tertiary)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                    )
                    .padding(.horizontal, 20)
                    
                    // Quick Share Button
                    Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showExportOptions = true
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 48)
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SHARE ANALYSIS")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .tracking(0.5)
                                
                                Text("Export video with overlays and share to social media")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showExportOptions = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showExportOptions) {
            ExportOptionsView(
                result: result,
                includeAnalysisOverlay: $includeAnalysisOverlay,
                exportQuality: $exportQuality,
                isExporting: $isExporting,
                onExport: { url in
                    exportedVideoURL = url
                    showShareSheet = true
                },
                onDismiss: {
                    showExportOptions = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            if let videoURL = exportedVideoURL {
                ShareSheet(items: [videoURL])
            }
        }
    }
    
    private func colorForLabel(_ label: String) -> Color {
        switch label.lowercased() {
        case "on_plane", "on plane":
            return .green
        case "too_steep", "too steep":
            return .red
        case "too_flat", "too flat":
            return .yellow
        default:
            return .blue
        }
    }
    
    private func planeDescription() -> String {
        switch result.predicted_label.lowercased() {
        case "on_plane", "on plane":
            return "Within optimal range"
        case "too_steep", "too steep":
            return "Too vertical, need to flatten"
        case "too_flat", "too flat":
            return "Too horizontal, need to steepen"
        default:
            return "Analysis complete"
        }
    }
    
    private func ballFlightImpact() -> String {
        switch result.predicted_label.lowercased() {
        case "on_plane", "on plane":
            return "Promotes straight, consistent ball flight with good distance"
        case "too_steep", "too steep":
            return "Likely causes slices, fat shots, and reduced distance"
        case "too_flat", "too flat":
            return "Often leads to hooks, thin shots, and timing issues"
        default:
            return "Variable ball flight patterns"
        }
    }
    
    private func correctionNeeded() -> String {
        let difference = abs(result.physics_insights.avg_plane_angle - 45)
        switch result.predicted_label.lowercased() {
        case "on_plane", "on plane":
            return "Maintain current swing plane - excellent technique!"
        case "too_steep", "too steep":
            return "Flatten swing plane by \(String(format: "%.1f°", difference)) - focus on shallow takeaway"
        case "too_flat", "too flat":
            return "Steepen swing plane by \(String(format: "%.1f°", difference)) - focus on upright backswing"
        default:
            return "Work on consistent swing plane mechanics"
        }
    }
    
    private func quickFixes() -> [String] {
        switch result.predicted_label.lowercased() {
        case "on_plane", "on plane":
            return [
                "Keep your current setup and posture",
                "Maintain consistent tempo and rhythm",
                "Continue practicing with alignment aids"
            ]
        case "too_steep", "too steep":
            return [
                "Start takeaway lower and wider",
                "Feel like you're swinging more around your body",
                "Practice with a towel under your right arm",
                "Focus on shoulder rotation vs. lifting"
            ]
        case "too_flat", "too flat":
            return [
                "Start backswing more upright",
                "Feel like you're lifting the club higher earlier",
                "Practice against an upslope or wall",
                "Focus on proper wrist hinge"
            ]
        default:
            return [
                "Work on consistent setup position",
                "Practice with video feedback",
                "Focus on tempo and balance"
            ]
        }
    }
}

// MARK: - Premium Custom Components

struct PremiumToggleStyle: ToggleStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 20)
                .fill(configuration.isOn ? color : Color.gray.opacity(0.3))
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: configuration.isOn)
                )
                .onTapGesture {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    configuration.isOn.toggle()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: configuration.isOn)
        }
    }
}

struct PremiumAnalysisCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isHighlighted: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(0.5)
                
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            
            Spacer()
            
            if isHighlighted {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let clockwise: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        
        return path
    }
}

struct AnalysisPoint: View {
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Export & Share Components

enum ExportQuality: String, CaseIterable {
    case standard = "Standard (720p)"
    case high = "High (1080p)"
    case ultra = "Ultra (4K)"
    
    var resolution: CGSize {
        switch self {
        case .standard: return CGSize(width: 1280, height: 720)
        case .high: return CGSize(width: 1920, height: 1080)
        case .ultra: return CGSize(width: 3840, height: 2160)
        }
    }
}

struct ExportOptionsView: View {
    let result: SwingAnalysisResponse
    @Binding var includeAnalysisOverlay: Bool
    @Binding var exportQuality: ExportQuality
    @Binding var isExporting: Bool
    let onExport: (URL) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                        
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Text("EXPORT & SHARE")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .tracking(1)
                        
                        Text("Create shareable swing analysis video")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                
                VStack(spacing: 24) {
                    // Export Options
                    VStack(spacing: 20) {
                        HStack {
                            Text("EXPORT OPTIONS")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .tracking(1)
                            Spacer()
                        }
                        
                        VStack(spacing: 16) {
                            // Analysis Overlay Toggle
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("INCLUDE ANALYSIS")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .tracking(0.5)
                                    
                                    Text("Add swing plane overlay and metrics")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $includeAnalysisOverlay)
                                    .toggleStyle(PremiumToggleStyle(color: .purple))
                            }
                            
                            Divider()
                                .background(.tertiary)
                            
                            // Quality Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("VIDEO QUALITY")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .tracking(0.5)
                                
                                VStack(spacing: 8) {
                                    ForEach(ExportQuality.allCases, id: \.self) { quality in
                                        HStack {
                                            Button {
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                impactFeedback.impactOccurred()
                                                exportQuality = quality
                                            } label: {
                                                HStack(spacing: 12) {
                                                    ZStack {
                                                        Circle()
                                                            .stroke(exportQuality == quality ? .purple : .gray.opacity(0.5), lineWidth: 2)
                                                            .frame(width: 20, height: 20)
                                                        
                                                        if exportQuality == quality {
                                                            Circle()
                                                                .fill(.purple)
                                                                .frame(width: 10, height: 10)
                                                        }
                                                    }
                                                    
                                                    Text(quality.rawValue)
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    
                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                    
                    // Social Media Platforms Preview
                    VStack(spacing: 16) {
                        HStack {
                            Text("SHARE TO")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .tracking(1)
                            Spacer()
                        }
                        
                        HStack(spacing: 20) {
                            SocialPlatformButton(
                                platform: "Instagram",
                                icon: "camera.circle.fill",
                                color: .pink,
                                gradient: [.pink, .purple]
                            )
                            
                            SocialPlatformButton(
                                platform: "Facebook",
                                icon: "person.2.circle.fill",
                                color: .blue,
                                gradient: [.blue, .cyan]
                            )
                            
                            SocialPlatformButton(
                                platform: "Bluesky",
                                icon: "cloud.circle.fill",
                                color: .indigo,
                                gradient: [.indigo, .blue]
                            )
                            
                            SocialPlatformButton(
                                platform: "More",
                                icon: "square.and.arrow.up.circle.fill",
                                color: .gray,
                                gradient: [.gray, .secondary]
                            )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Export Button
                Button {
                    exportVideo()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 56)
                            .shadow(color: .purple.opacity(0.3), radius: 12, x: 0, y: 6)
                        
                        HStack(spacing: 12) {
                            if isExporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                
                                Text("EXPORTING VIDEO...")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .tracking(1)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("EXPORT & SHARE")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .tracking(1)
                            }
                        }
                    }
                }
                .disabled(isExporting)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func exportVideo() {
        isExporting = true
        
        let exportManager = VideoExportManager()
        
        exportManager.exportSwingAnalysisVideo(
            result: result,
            includeOverlay: includeAnalysisOverlay,
            quality: exportQuality
        ) { result in
            DispatchQueue.main.async {
                isExporting = false
                
                switch result {
                case .success(let url):
                    onExport(url)
                    onDismiss()
                case .failure(let error):
                    print("Export failed: \(error.localizedDescription)")
                    // In a real app, show error alert
                }
            }
        }
    }
}

struct SocialPlatformButton: View {
    let platform: String
    let icon: String
    let color: Color
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text(platform)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.5)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Customize for specific platforms
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Video Export Manager

class VideoExportManager: ObservableObject {
    
    func exportSwingAnalysisVideo(
        result: SwingAnalysisResponse,
        includeOverlay: Bool,
        quality: ExportQuality,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // In a real implementation, this would:
        // 1. Load the original video
        // 2. Create overlay graphics with swing analysis
        // 3. Composite video with overlays
        // 4. Export at specified quality
        // 5. Save to camera roll or temp directory
        
        // For now, simulate the process
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) {
            
            // Create a mock video file
            let timestamp = Date().timeIntervalSince1970
            let fileName = "golf_swing_analysis_\(Int(timestamp))"
            let overlayText = includeOverlay ? "_with_overlay" : "_clean"
            let qualityText = "_\(quality.rawValue.lowercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: ""))"
            
            let finalFileName = "\(fileName)\(overlayText)\(qualityText).mp4"
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoURL = documentsPath.appendingPathComponent(finalFileName)
            
            // Create a minimal video file (in real implementation, this would be the actual processed video)
            self.createMockVideoFile(at: videoURL, result: result, includeOverlay: includeOverlay) { success in
                if success {
                    completion(.success(videoURL))
                } else {
                    completion(.failure(VideoExportError.exportFailed))
                }
            }
        }
    }
    
    private func createMockVideoFile(
        at url: URL,
        result: SwingAnalysisResponse,
        includeOverlay: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        // In a real app, this would use AVFoundation to:
        // 1. Load source video
        // 2. Create CALayer with swing analysis overlay
        // 3. Use AVVideoComposition to composite layers
        // 4. Export using AVAssetExportSession
        
        // For demo purposes, create a small data file
        let metadata = """
        Golf Swing Analysis Export
        ========================
        
        Swing Plane: \(String(format: "%.1f°", result.physics_insights.avg_plane_angle))
        Classification: \(result.predicted_label.replacingOccurrences(of: "_", with: " ").capitalized)
        Confidence: \(Int(result.confidence * 100))%
        
        Analysis Overlay: \(includeOverlay ? "Included" : "Not Included")
        
        Exported: \(Date())
        """
        
        do {
            try metadata.write(to: url, atomically: true, encoding: String.Encoding.utf8)
            completion(true)
        } catch {
            completion(false)
        }
    }
}

enum VideoExportError: LocalizedError {
    case exportFailed
    case invalidVideo
    case overlayCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Failed to export video"
        case .invalidVideo:
            return "Invalid source video"
        case .overlayCreationFailed:
            return "Failed to create analysis overlay"
        }
    }
}

#Preview {
    VideoSwingPlaneAnalysisView(
        result: SwingAnalysisResponse(
            predicted_label: "too_steep",
            confidence: 0.85,
            confidence_gap: 0.32,
            all_probabilities: [
                "too_steep": 0.85,
                "on_plane": 0.12,
                "too_flat": 0.03
            ],
            camera_angle: "side_on",
            angle_confidence: 0.92,
            feature_reliability: [
                "swing_plane": 1.0,
                "body_rotation": 0.8,
                "balance": 0.9,
                "tempo": 1.0,
                "club_path": 0.7
            ],
            physics_insights: "Your swing plane is too steep (confidence: 85%). This can lead to fat shots, loss of distance, and inconsistent ball striking.",
            angle_insights: "Side-on view provides optimal swing plane analysis.",
            recommendations: [
                "Work on a more shallow backswing takeaway",
                "Practice the 'one-piece' takeaway drill"
            ],
            extraction_status: "success",
            analysis_type: "multi_angle",
            model_version: "2.0_multi_angle"
        )
    )
}