import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var apiService = APIService.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @State private var showingLogin = false
    @State private var showingSettings = false
    @State private var animateContent = false
    @State private var showingPhysicsEnginePaywall = false
    @State private var navigateToProfile = false
    @State private var navigateToAllTools = false
    
    // Helper function to calculate membership duration
    private func membershipDuration(from date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date, to: Date())
        
        if let months = components.month, months > 0 {
            return "\(months)mo"
        } else if let days = components.day, days > 0 {
            return "\(days)d"
        } else {
            return "New"
        }
    }
    
    // Helper computed property for connection status text
    private var connectionStatusText: String {
        return "Local AI Active" // Always active since it's local-only
    }
    
    // Helper function for time ago formatting
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header with Clean Navigation
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Golf Swing AI")
                                .font(.system(size: 24, weight: .medium, design: .serif))
                                .foregroundColor(.primary)
                            
                            // API Connection Status
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green) // Always green since local AI is always available
                                    .frame(width: 6, height: 6)
                                
                                Text(connectionStatusText)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("• Ready")
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            if !authManager.isAuthenticated {
                                Button("Sign up") {
                                    showingLogin = true
                                }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black)
                                .clipShape(Capsule())
                            }
                            
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "line.horizontal.3")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // Analytical Header with Metrics
                    VStack(spacing: 20) {
                        // Welcome Section
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Golf Analytics")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Performance insights & data")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Profile Avatar
                            Button(action: {
                                navigateToProfile = true
                            }) {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.blue)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // Show analytics for logged-in users, tools preview for guests
                        if authManager.isAuthenticated {
                            // Real User Analytics or Getting Started Message
                            if let user = authManager.currentUser, user.profile.totalSwingsAnalyzed > 0 {
                                // Show real analytics for users with data
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        AnalyticsCard(
                                            icon: "chart.line.uptrend.xyaxis",
                                            title: "Best Speed",
                                            value: user.profile.bestSwingSpeed > 0 ? "\(Int(user.profile.bestSwingSpeed)) mph" : "—",
                                            color: .blue
                                        )
                                        
                                        AnalyticsCard(
                                            icon: "video.fill",
                                            title: "Swings",
                                            value: "\(user.profile.totalSwingsAnalyzed)",
                                            color: .green
                                        )
                                    }
                                    
                                    HStack(spacing: 12) {
                                        AnalyticsCard(
                                            icon: "chart.bar.fill",
                                            title: "Avg Speed",
                                            value: user.profile.averageSwingSpeed > 0 ? "\(Int(user.profile.averageSwingSpeed)) mph" : "—",
                                            color: .orange
                                        )
                                        
                                        AnalyticsCard(
                                            icon: "calendar.badge.clock",
                                            title: "Member",
                                            value: membershipDuration(from: user.dateCreated),
                                            color: .purple
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                            } else {
                                // Getting started message for new users
                                VStack(spacing: 16) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 40, weight: .light))
                                            .foregroundColor(.blue)
                                        
                                        Text("Ready to analyze your swing?")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Upload your first swing video to get personalized insights and start tracking your progress.")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                    }
                                    
                                    NavigationLink(destination: SwingAnalysisView()) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "video.circle.fill")
                                                .font(.system(size: 16, weight: .medium))
                                            Text("Analyze Your First Swing")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                                .padding(.horizontal, 24)
                            }
                        } else {
                            // Guest Tools Preview
                            VStack(spacing: 16) {
                                Text("What You Can Do")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(spacing: 12) {
                                    NavigationLink(destination: SwingAnalysisView()) {
                                        GuestToolPreview(
                                            icon: "waveform.path.ecg",
                                            title: "Swing Analysis",
                                            description: "Upload your swing videos for AI-powered motion tracking and biomechanical analysis",
                                            color: .blue
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    NavigationLink(destination: CaddieChatView()) {
                                        GuestToolPreview(
                                            icon: "message.circle.fill",
                                            title: "CaddieChat",
                                            description: "Your AI golf expert with tournament insights - ask anything about golf strategy, tips, and techniques",
                                            color: .green
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    NavigationLink(destination: BallTrackingView()) {
                                        GuestToolPreview(
                                            icon: "dot.radiowaves.up.forward",
                                            title: "Ball Flight Tracking",
                                            description: "Track ball trajectory and analyze impact physics in 3D space",
                                            color: .orange
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if premiumManager.validatePremiumAccess() {
                                        NavigationLink(destination: PhysicsEngineView()) {
                                            GuestToolPreview(
                                                icon: "function",
                                                title: "Physics Engine",
                                                description: "Premium: Professional biomechanics analysis with video upload, real-time force vectors, and energy calculations",
                                                color: .purple,
                                                isComingSoon: false
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    } else {
                                        Button(action: {
                                            showingPhysicsEnginePaywall = true
                                        }) {
                                            GuestToolPreview(
                                                icon: "function",
                                                title: "Physics Engine",
                                                description: "Premium: Professional biomechanics analysis with video upload, real-time force vectors, and energy calculations",
                                                color: .purple,
                                                isComingSoon: false
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // User Performance Analytics (only show if user has swing data)
                        if authManager.isAuthenticated, 
                           let user = authManager.currentUser, 
                           user.profile.totalSwingsAnalyzed > 0 {
                            UserPerformanceSection(user: user)
                        }
                        
                        // Analysis Tools Section
                        VStack(spacing: 20) {
                            HStack {
                                Text("Analysis Tools")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button("See all") {
                                    navigateToAllTools = true
                                }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 24)
                            
                            // Tool Cards
                            VStack(spacing: 12) {
                                NavigationLink(destination: SwingAnalysisView()) {
                                    AnalyticalToolCard(
                                        icon: "waveform.path.ecg",
                                        title: "Swing Analysis",
                                        subtitle: "Motion tracking & biomechanics",
                                        metrics: "12 data points",
                                        color: .blue
                                    )
                                }
                                .buttonStyle(ElegantButtonStyle())
                                
                                HStack(spacing: 12) {
                                    NavigationLink(destination: CaddieChatView()) {
                                        CompactAnalyticalCard(
                                            icon: "message.circle.fill",
                                            title: "CaddieChat",
                                            value: "AI Expert",
                                            color: .green
                                        )
                                    }
                                    .buttonStyle(ElegantButtonStyle())
                                    
                                    NavigationLink(destination: BallTrackingView()) {
                                        CompactAnalyticalCard(
                                            icon: "dot.radiowaves.up.forward",
                                            title: "Ball Flight",
                                            value: "3D tracking",
                                            color: .orange
                                        )
                                    }
                                    .buttonStyle(ElegantButtonStyle())
                                }
                                
                                if premiumManager.validatePremiumAccess() {
                                    NavigationLink(destination: PhysicsEngineView()) {
                                        AnalyticalToolCard(
                                            icon: "function",
                                            title: "Physics Engine",
                                            subtitle: "Force vectors & impact analysis",
                                            metrics: "Premium offering",
                                            color: .purple,
                                            isComingSoon: false
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    Button(action: {
                                        print("🔘 Showing premium paywall for Physics Engine")
                                        showingPhysicsEnginePaywall = true
                                    }) {
                                        AnalyticalToolCard(
                                            icon: "function",
                                            title: "Physics Engine",
                                            subtitle: "Force vectors & impact analysis",
                                            metrics: "Premium offering",
                                            color: .purple,
                                            isComingSoon: false
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 40)
                        
                        Spacer(minLength: 60)
                    }
                    .opacity(animateContent ? 1.0 : 0.0)
                    .offset(y: animateContent ? 0 : 30)
                    .animation(.easeOut(duration: 1.0).delay(0.2), value: animateContent)
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
            .onAppear {
                animateContent = true
            }
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .navigationDestination(isPresented: $navigateToProfile) {
            ProfileView()
        }
        .navigationDestination(isPresented: $navigateToAllTools) {
            AllToolsView()
        }
        .sheet(isPresented: $showingPhysicsEnginePaywall) {
            PhysicsEnginePremiumView()
                .environmentObject(premiumManager)
        }
    }
}

// MARK: - Compact User Stats

struct CompactUserStats: View {
    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("24")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundColor(.primary)
                Text("Sessions")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("102.4")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundColor(.primary)
                Text("Avg Speed")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Compact Welcome

struct CompactWelcome: View {
    var body: some View {
        Text("Get started with professional swing analysis.")
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var isComingSoon: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(.primary)
                    
                    if isComingSoon {
                        Text("SOON")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.orange))
                    }
                    
                    Spacer()
                }
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Compact Tool Card

struct CompactToolCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Elegant Button Style

struct ElegantButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Analytics Card

struct AnalyticsCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Analytical Tool Card

struct AnalyticalToolCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let metrics: String
    let color: Color
    var isComingSoon: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with data visualization background
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isComingSoon {
                        Text("BETA")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(color))
                    }
                    
                    Spacer()
                }
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                
                Text(metrics)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Arrow indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Compact Analytical Card

struct CompactAnalyticalCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            
            Spacer()
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - User Performance Section

struct UserPerformanceSection: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Progress")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("All time")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Real Performance Metrics
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    UserStatCard(
                        icon: "video.fill",
                        title: "Total Swings",
                        value: "\(user.profile.totalSwingsAnalyzed)",
                        subtitle: "analyzed",
                        color: .blue,
                        trend: .stable
                    )
                    
                    UserStatCard(
                        icon: "star.fill",
                        title: "Best Speed",
                        value: user.profile.bestSwingSpeed > 0 ? "\(Int(user.profile.bestSwingSpeed)) mph" : "—",
                        subtitle: "personal record",
                        color: .purple,
                        trend: .stable
                    )
                }
                
                HStack(spacing: 12) {
                    UserStatCard(
                        icon: "chart.bar.fill",
                        title: "Avg Speed",
                        value: user.profile.averageSwingSpeed > 0 ? "\(Int(user.profile.averageSwingSpeed)) mph" : "—",
                        subtitle: "swing speed",
                        color: .green,
                        trend: .stable
                    )
                    
                    UserStatCard(
                        icon: "calendar.badge.clock",
                        title: "Joined",
                        value: DateFormatter.monthYear.string(from: user.dateCreated),
                        subtitle: "member since",
                        color: .orange,
                        trend: .stable
                    )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - User Stat Card

struct UserStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let trend: TrendDirection
    
    enum TrendDirection {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .secondary
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(trend.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Guest Tool Preview

struct GuestToolPreview: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var isComingSoon: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isComingSoon {
                        Text("SOON")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(color))
                    }
                    
                    Spacer()
                }
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - All Tools View

struct AllToolsView: View {
    @EnvironmentObject var premiumManager: PremiumManager
    @State private var showingPhysicsEnginePaywall = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.blue)
                        
                        Text("Analysis Tools")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Complete suite of AI-powered golf analysis tools")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Tools Grid
                    VStack(spacing: 16) {
                        // Swing Analysis
                        NavigationLink(destination: SwingAnalysisView()) {
                            AllToolCard(
                                icon: "waveform.path.ecg",
                                title: "Swing Analysis",
                                description: "AI-powered motion tracking and biomechanical analysis with detailed swing breakdown",
                                features: ["Motion Tracking", "Biomechanics", "Form Analysis", "Improvement Tips"],
                                color: .blue,
                                isPremium: false
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // CaddieChat
                        NavigationLink(destination: CaddieChatView()) {
                            AllToolCard(
                                icon: "message.circle.fill",
                                title: "CaddieChat",
                                description: "Your AI golf expert with tournament insights and personalized coaching",
                                features: ["Course Strategy", "Club Selection", "Mental Game", "Rules & Etiquette"],
                                color: .green,
                                isPremium: false
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Ball Flight Tracking
                        NavigationLink(destination: BallTrackingView()) {
                            AllToolCard(
                                icon: "dot.radiowaves.up.forward",
                                title: "Ball Flight Tracking",
                                description: "3D trajectory analysis with launch angle and spin rate calculations",
                                features: ["3D Tracking", "Launch Analysis", "Spin Rate", "Distance Calculation"],
                                color: .orange,
                                isPremium: false
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Physics Engine (Premium)
                        if PremiumManager.shared.isDevelopmentMode || PremiumManager.shared.canAccessPhysicsEngine {
                            NavigationLink(destination: PhysicsEngineView()) {
                                AllToolCard(
                                    icon: "function",
                                    title: "Physics Engine",
                                    description: "Professional biomechanics analysis with force vectors and energy calculations",
                                    features: ["Club Head Speed", "Club Face Angle", "Force Vectors", "Elite Benchmarks"],
                                    color: .purple,
                                    isPremium: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Button(action: {
                                print("🔘 Showing premium paywall from AllTools")
                                showingPhysicsEnginePaywall = true
                            }) {
                                AllToolCard(
                                    icon: "function",
                                    title: "Physics Engine",
                                    description: "Professional biomechanics analysis with force vectors and energy calculations",
                                    features: ["Club Head Speed", "Club Face Angle", "Force Vectors", "Elite Benchmarks"],
                                    color: .purple,
                                    isPremium: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("All Tools")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingPhysicsEnginePaywall) {
            PhysicsEnginePremiumView()
                .environmentObject(PremiumManager.shared)
        }
    }
}

// MARK: - All Tool Card

struct AllToolCard: View {
    let icon: String
    let title: String
    let description: String
    let features: [String]
    let color: Color
    let isPremium: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if isPremium {
                            Text("PREMIUM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                    
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Features
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(color)
                        
                        Text(feature)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
            
            // Action indicator
            HStack {
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationManager())
        .environmentObject(ThemeManager())
}
