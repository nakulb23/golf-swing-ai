import SwiftUI

struct AllToolsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingSwingAnalysis = false
    @State private var showingBallTracker = false
    @State private var showingPhysicsEngine = false
    @State private var showingCaddieChat = false
    @State private var showingPremiumPaywall = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Golf Tools")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Comprehensive analysis tools for every aspect of your golf game")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Tools Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        
                        // Swing Analysis Tool
                        ToolCard(
                            title: "Swing Analysis",
                            subtitle: "AI-powered swing breakdown",
                            icon: "figure.golf",
                            gradient: [Color.blue, Color.blue.opacity(0.7)],
                            isPremium: false
                        ) {
                            showingSwingAnalysis = true
                        }
                        
                        // Ball Tracker Tool
                        ToolCard(
                            title: "Ball Tracker",
                            subtitle: "Track ball trajectory",
                            icon: "target",
                            gradient: [Color.green, Color.green.opacity(0.7)],
                            isPremium: false
                        ) {
                            showingBallTracker = true
                        }
                        
                        // Physics Engine (Premium)
                        ToolCard(
                            title: "Physics Engine",
                            subtitle: "Advanced biomechanics",
                            icon: "atom",
                            gradient: [Color.purple, Color.purple.opacity(0.7)],
                            isPremium: true
                        ) {
                            if premiumManager.hasPhysicsEnginePremium {
                                showingPhysicsEngine = true
                            } else {
                                showingPremiumPaywall = true
                            }
                        }
                        
                        // Caddie Chat (Premium)
                        ToolCard(
                            title: "AI Caddie",
                            subtitle: "Golf strategy assistant",
                            icon: "message.fill",
                            gradient: [Color.orange, Color.orange.opacity(0.7)],
                            isPremium: true
                        ) {
                            if premiumManager.hasPhysicsEnginePremium {
                                showingCaddieChat = true
                            } else {
                                showingPremiumPaywall = true
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Coming Soon Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Coming Soon")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            ComingSoonCard(
                                title: "Course Strategy",
                                subtitle: "AI-powered course management",
                                icon: "map.fill"
                            )
                            
                            ComingSoonCard(
                                title: "Equipment Fitting",
                                subtitle: "Personalized club recommendations",
                                icon: "hammer.fill"
                            )
                            
                            ComingSoonCard(
                                title: "Practice Planner",
                                subtitle: "Customized training programs",
                                icon: "calendar"
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSwingAnalysis) {
            SwingAnalysisView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingBallTracker) {
            BallTrackingView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingPhysicsEngine) {
            PhysicsEngineView()
                .environmentObject(authManager)
                .environmentObject(premiumManager)
        }
        .sheet(isPresented: $showingCaddieChat) {
            CaddieChatView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            PhysicsEnginePremiumView()
                .environmentObject(premiumManager)
        }
    }
}

struct ToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let isPremium: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: gradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Content
                VStack(spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if isPremium {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ComingSoonCard: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.gray)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Soon")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.gray)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    AllToolsView()
        .environmentObject(AuthenticationManager())
}