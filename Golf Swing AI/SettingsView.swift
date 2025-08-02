import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject private var premiumManager = PremiumManager.shared
    @State private var enableNotifications = true
    @State private var enableHapticFeedback = true
    @State private var autoSaveVideos = false
    @State private var showingSubscriptionSheet = false
    
    private var isSubscriptionActive: Bool {
        premiumManager.hasPhysicsEnginePremium
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Appearance Section
                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Appearance")
                                .font(.body)
                            
                            Spacer()
                        }
                        
                        Picker("Appearance Mode", selection: $themeManager.appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                Text(mode.displayName)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: themeManager.appearanceMode) { oldMode, newMode in
                            themeManager.setAppearanceMode(newMode)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Notifications Section
                Section("Notifications") {
                    SettingsToggleRow(
                        icon: "bell.fill",
                        title: "Push Notifications",
                        isOn: $enableNotifications
                    )
                    
                    SettingsToggleRow(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "Haptic Feedback",
                        isOn: $enableHapticFeedback
                    )
                }
                
                // MARK: - Video & Analysis Section
                Section("Video & Analysis") {
                    SettingsToggleRow(
                        icon: "video.fill",
                        title: "Auto-Save Videos",
                        isOn: $autoSaveVideos
                    )
                    
                    NavigationLink(destination: VideoQualitySettingsView()) {
                        SettingsNavigationRow(
                            icon: "camera.fill",
                            title: "Video Quality",
                            value: "High"
                        )
                    }
                }
                
                // MARK: - Subscription Section
                Section("Subscription") {
                    if isSubscriptionActive {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                Text("Premium Active")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text("Active")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        SettingsActionRow(
                            icon: "crown.fill",
                            title: "Upgrade to Premium",
                            action: {
                                showingSubscriptionSheet = true
                            }
                        )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Premium Features:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("• Club face angle tracking")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("• Club head speed analysis")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("• Elite benchmarks")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 4)
                    }
                }
                
                // MARK: - Account Section
                Section("Account") {
                    NavigationLink(destination: ProfileView()) {
                        SettingsNavigationRow(
                            icon: "person.fill",
                            title: "Profile",
                            value: ""
                        )
                    }
                    
                    NavigationLink(destination: ProgressHistoryView()) {
                        SettingsNavigationRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Progress History",
                            value: ""
                        )
                    }
                    
                    SettingsActionRow(
                        icon: "arrow.right.square.fill",
                        title: "Sign Out",
                        action: {
                            authManager.signOut()
                        }
                    )
                }
                
                // MARK: - Privacy Section
                Section("Privacy") {
                    NavigationLink(destination: SimplePrivacyView()) {
                        SettingsNavigationRow(
                            icon: "hand.raised.fill",
                            title: "Privacy & Analytics",
                            value: ""
                        )
                    }
                }
                
                // MARK: - Developer Section (for testing)
                Section("Developer") {
                    SettingsToggleRow(
                        icon: "hammer.fill",
                        title: "Development Mode",
                        isOn: $premiumManager.isDevelopmentMode
                    )
                    .onChange(of: premiumManager.isDevelopmentMode) { oldValue, newValue in
                        premiumManager.setDevelopmentMode(newValue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ Development mode only works in DEBUG builds")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        Text("Development mode enables:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("• Testing premium features without purchase")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• Debugging subscription flows")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("• Does NOT work in release builds")
                            .font(.caption2)
                            .foregroundColor(.red)
                        
                        // Testing buttons
                        HStack(spacing: 16) {
                            Button(action: {
                                premiumManager.resetPremiumAccess()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Reset Premium")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            Button(action: {
                                Task {
                                    await premiumManager.testStoreKitConfiguration()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text("Test StoreKit")
                                }
                                .font(.caption)
                                .foregroundColor(.green)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 4)
                }
                
                // MARK: - Support Section
                Section("Support") {
                    NavigationLink(destination: HelpFAQView()) {
                        SettingsNavigationRow(
                            icon: "questionmark.circle.fill",
                            title: "Help & FAQ",
                            value: ""
                        )
                    }
                    
                    SettingsActionRow(
                        icon: "envelope.fill",
                        title: "Contact Support",
                        action: {
                            openContactSupport()
                        }
                    )
                    
                    SettingsActionRow(
                        icon: "star.fill",
                        title: "Rate App",
                        action: {
                            rateApp()
                        }
                    )
                }
                
                // MARK: - App Info Section
                Section("About") {
                    SettingsInfoRow(title: "Version", value: "1.0.0")
                    SettingsInfoRow(title: "Build", value: "2025.1")
                }
            }
            .background(Color.primaryBackgroundDynamic)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingSubscriptionSheet) {
                PhysicsEnginePremiumView()
            }
        }
    }
    
    // MARK: - Support Helper Functions
    private func openContactSupport() {
        let email = "support@golfswingai.com"
        let subject = "Golf Swing AI - Support Request"
        let body = """
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        App Version: 1.0.0
        
        Please describe your issue below:
        
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                SimpleAnalytics.shared.trackEvent("contact_support", properties: ["method": "email"])
            }
        }
    }
    
    private func rateApp() {
        // Use modern AppStore.requestReview API (iOS 18+)
        if #available(iOS 18.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                
                AppStore.requestReview(in: windowScene)
                SimpleAnalytics.shared.trackEvent("rate_app_requested", properties: [
                    "method": "modern_review"
                ])
            }
        } else {
            // Fallback to legacy SKStoreReviewController for iOS 17 and below
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                
                SKStoreReviewController.requestReview(in: windowScene)
                SimpleAnalytics.shared.trackEvent("rate_app_requested", properties: [
                    "method": "legacy_review"
                ])
            }
        }
        
        // Additional fallback to App Store URL if both methods fail
        if UIApplication.shared.connectedScenes.isEmpty {
            let appStoreURL = "https://apps.apple.com/app/id123456789" // Replace with actual App Store ID
            
            if let url = URL(string: appStoreURL) {
                UIApplication.shared.open(url)
                SimpleAnalytics.shared.trackEvent("rate_app_opened", properties: [
                    "method": "app_store_url"
                ])
            }
        }
    }
}

// MARK: - Settings Row Components
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            if !value.isEmpty {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingsActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

struct SettingsInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Placeholder Views
struct VideoQualitySettingsView: View {
    @State private var selectedQuality: VideoQuality = .hd1080p
    @State private var enableStabilization = true
    @State private var enableAutoFocus = true
    
    var body: some View {
        NavigationView {
            List {
                Section("Video Quality") {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(quality.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text(quality.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedQuality == quality {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedQuality = quality
                            saveVideoQuality()
                        }
                    }
                }
                
                Section("Camera Settings") {
                    Toggle("Video Stabilization", isOn: $enableStabilization)
                        .onChange(of: enableStabilization) { _, newValue in
                            saveCameraSetting("stabilization", value: newValue)
                        }
                    
                    Toggle("Auto Focus", isOn: $enableAutoFocus)
                        .onChange(of: enableAutoFocus) { _, newValue in
                            saveCameraSetting("autoFocus", value: newValue)
                        }
                }
                
                Section("Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quality Guidelines")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• 1080p HD: Best for analysis accuracy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 720p: Good quality, smaller file size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 480p: Basic quality, fastest processing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Video Quality")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private func saveVideoQuality() {
        UserDefaults.standard.set(selectedQuality.rawValue, forKey: "videoQuality")
        SimpleAnalytics.shared.trackEvent("video_quality_changed", properties: [
            "quality": selectedQuality.rawValue
        ])
    }
    
    private func saveCameraSetting(_ setting: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: "camera_\(setting)")
        SimpleAnalytics.shared.trackEvent("camera_setting_changed", properties: [
            "setting": setting,
            "enabled": value
        ])
    }
    
    private func loadSettings() {
        if let qualityRaw = UserDefaults.standard.object(forKey: "videoQuality") as? String,
           let quality = VideoQuality(rawValue: qualityRaw) {
            selectedQuality = quality
        }
        
        enableStabilization = UserDefaults.standard.bool(forKey: "camera_stabilization")
        enableAutoFocus = UserDefaults.standard.bool(forKey: "camera_autoFocus")
    }
}

enum VideoQuality: String, CaseIterable {
    case hd1080p = "1080p"
    case hd720p = "720p"  
    case sd480p = "480p"
    
    var displayName: String {
        switch self {
        case .hd1080p: return "1080p HD"
        case .hd720p: return "720p HD"
        case .sd480p: return "480p SD"
        }
    }
    
    var description: String {
        switch self {
        case .hd1080p: return "High quality, larger files"
        case .hd720p: return "Good quality, balanced size"
        case .sd480p: return "Basic quality, small files"
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingEditSheet = false
    
    var body: some View {
        NavigationView {
            if let user = authManager.currentUser {
                // Track profile view
                let _ = SimpleAnalytics.shared.trackAppUsage(screen: "profile")
                
                ZStack {
                    // Premium background gradient
                    LinearGradient(
                        colors: [
                            Color.primaryBackgroundDynamic,
                            Color.forestGreen.opacity(0.05),
                            Color.primaryBackgroundDynamic
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 32) {
                            // MARK: - Premium Header with Hero Section
                            ZStack {
                                // Background card with subtle gradient
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.cardBackgroundDynamic,
                                                Color.forestGreen.opacity(0.03)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.forestGreen.opacity(0.2),
                                                        Color.clear
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                
                                VStack(spacing: 24) {
                                    // Profile Avatar with premium styling
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.forestGreen, Color.sage],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 120, height: 120)
                                            .shadow(color: Color.forestGreen.opacity(0.3), radius: 15, x: 0, y: 8)
                                        
                                        Text(user.firstName.prefix(1).uppercased())
                                            .font(.system(size: 42, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    
                                    // User info with premium typography
                                    VStack(spacing: 12) {
                                        Text(user.fullName)
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundColor(.primaryTextDynamic)
                                        
                                        Text(user.email)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.secondaryTextDynamic)
                                        
                                        // Premium handicap badge
                                        if let handicap = user.handicap {
                                            HStack(spacing: 8) {
                                                Image(systemName: "target")
                                                    .font(.system(size: 14, weight: .bold))
                                                
                                                Text("Handicap \(String(format: "%.1f", handicap))")
                                                    .font(.system(size: 14, weight: .bold))
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color.forestGreen, Color.sage],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                            )
                                            .shadow(color: Color.forestGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                                        }
                                    }
                                }
                                .padding(32)
                            }
                            .padding(.horizontal, 20)
                            
                            // MARK: - Premium Stats Overview
                            HStack(spacing: 16) {
                                PremiumStatCard(
                                    icon: "video.fill",
                                    title: "Swings",
                                    value: "\(user.profile.totalSwingsAnalyzed)",
                                    color: .blue
                                )
                                
                                PremiumStatCard(
                                    icon: "speedometer",
                                    title: "Best Speed",
                                    value: user.profile.bestSwingSpeed > 0 ? "\(Int(user.profile.bestSwingSpeed))" : "—",
                                    subtitle: user.profile.bestSwingSpeed > 0 ? "mph" : nil,
                                    color: .green
                                )
                                
                                PremiumStatCard(
                                    icon: "chart.bar.fill",
                                    title: "Avg Speed",
                                    value: user.profile.averageSwingSpeed > 0 ? "\(Int(user.profile.averageSwingSpeed))" : "—",
                                    subtitle: user.profile.averageSwingSpeed > 0 ? "mph" : nil,
                                    color: .orange
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            // MARK: - Golf Profile Section
                            VStack(spacing: 20) {
                                HStack {
                                    Text("Golf Profile")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.primaryTextDynamic)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                PremiumInfoCard {
                                    VStack(spacing: 20) {
                                        PremiumInfoRow(
                                            icon: "figure.golf",
                                            title: "Preferred Hand",
                                            value: user.preferredHand.displayName,
                                            iconColor: .forestGreen
                                        )
                                        
                                        PremiumInfoRow(
                                            icon: "chart.line.uptrend.xyaxis",
                                            title: "Experience Level",
                                            value: user.experienceLevel.displayName,
                                            iconColor: .blue
                                        )
                                        
                                        if let homeCourse = user.homeCourse, !homeCourse.isEmpty {
                                            PremiumInfoRow(
                                                icon: "house.lodge.fill",
                                                title: "Home Course",
                                                value: homeCourse,
                                                iconColor: .green
                                            )
                                        }
                                        
                                        if let yearsPlayed = user.yearsPlayed {
                                            PremiumInfoRow(
                                                icon: "calendar.badge.clock",
                                                title: "Years Playing",
                                                value: "\(yearsPlayed) year\(yearsPlayed == 1 ? "" : "s")",
                                                iconColor: .indigo
                                            )
                                        }
                                        
                                        PremiumInfoRow(
                                            icon: "calendar.badge.plus",
                                            title: "Member Since",
                                            value: DateFormatter.monthYear.string(from: user.dateCreated),
                                            iconColor: .purple
                                        )
                                    }
                                }
                            }
                            
                            // MARK: - Edit Profile Button
                            Button(action: {
                                showingEditSheet = true
                                SimpleAnalytics.shared.trackAppUsage(screen: "edit_profile")
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.badge.pencil")
                                        .font(.system(size: 18, weight: .semibold))
                                    
                                    Text("Edit Profile")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    LinearGradient(
                                        colors: [Color.forestGreen, Color.sage],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.forestGreen.opacity(0.3), radius: 12, x: 0, y: 6)
                            }
                            .padding(.horizontal, 20)
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .navigationTitle("")
                .navigationBarHidden(true)
                .sheet(isPresented: $showingEditSheet) {
                    EditProfileSheet(user: user) { updatedUser in
                        authManager.updateUserProfile(updatedUser)
                        showingEditSheet = false
                    }
                }
            } else {
                // Premium not logged in state
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.primaryBackgroundDynamic,
                            Color.forestGreen.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 32) {
                        VStack(spacing: 24) {
                            Image(systemName: "person.crop.circle.dashed")
                                .font(.system(size: 100, weight: .ultraLight))
                                .foregroundColor(.forestGreen.opacity(0.6))
                            
                            VStack(spacing: 12) {
                                Text("Welcome to Golf AI")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primaryTextDynamic)
                                
                                Text("Sign in to view your personalized golf profile and track your progress")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondaryTextDynamic)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(40)
                }
                .navigationTitle("")
                .navigationBarHidden(true)
            }
        }
    }
}

// MARK: - Premium Profile Components
struct PremiumStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let color: Color
    
    init(icon: String, title: String, value: String, subtitle: String? = nil, color: Color) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryTextDynamic)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondaryTextDynamic)
                    }
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondaryTextDynamic)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackgroundDynamic)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct PremiumInfoCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackgroundDynamic)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.forestGreen.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
    }
}

struct PremiumInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondaryTextDynamic)
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryTextDynamic)
            }
            
            Spacer()
        }
    }
}

// MARK: - Legacy Profile Info Row Component (for compatibility)
struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        PremiumInfoRow(icon: icon, title: title, value: value, iconColor: iconColor)
    }
}

// MARK: - Working Edit Profile Sheet
struct EditProfileSheet: View {
    let user: User
    let onSave: (User) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String
    @State private var lastName: String
    @State private var handicapText: String
    @State private var homeCourse: String
    
    init(user: User, onSave: @escaping (User) -> Void) {
        self.user = user
        self.onSave = onSave
        self._firstName = State(initialValue: user.firstName)
        self._lastName = State(initialValue: user.lastName)
        self._handicapText = State(initialValue: user.handicap != nil ? String(format: "%.1f", user.handicap!) : "")
        self._homeCourse = State(initialValue: user.homeCourse ?? "")
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Personal Information") {
                    HStack {
                        Text("First Name")
                            .frame(width: 100, alignment: .leading)
                        TextField("Enter first name", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Last Name")
                            .frame(width: 100, alignment: .leading)
                        TextField("Enter last name", text: $lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section("Golf Information") {
                    HStack {
                        Text("Handicap")
                            .frame(width: 100, alignment: .leading)
                        TextField("e.g. 15.2", text: $handicapText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Home Course")
                            .frame(width: 100, alignment: .leading)
                        TextField("Enter your home course", text: $homeCourse)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section {
                    Button("Save Changes") {
                        saveProfile()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.forestGreen)
                    .cornerRadius(10)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveProfile() {
        var updatedUser = user
        
        // Update basic info
        updatedUser.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedUser.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update handicap
        if handicapText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updatedUser.handicap = nil
        } else {
            updatedUser.handicap = Double(handicapText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // Update home course
        let trimmedCourse = homeCourse.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedUser.homeCourse = trimmedCourse.isEmpty ? nil : trimmedCourse
        
        onSave(updatedUser)
    }
}


// MARK: - Date Formatter Extension
extension DateFormatter {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    static let subscriptionDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

struct ProgressHistoryView: View {
    var body: some View {
        Text("Progress History")
            .golfTitle()
            .navigationTitle("Progress")
    }
}

struct HelpFAQView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Getting Started") {
                    FAQItem(
                        question: "How do I analyze my golf swing?",
                        answer: "Use the Swing Analysis feature from the home screen. Record a video of your swing and our AI will provide detailed feedback on your swing plane and technique."
                    )
                    
                    FAQItem(
                        question: "What video quality should I use?",
                        answer: "For best results, use 1080p HD quality. Ensure good lighting and position the camera at waist height, perpendicular to your swing plane."
                    )
                }
                
                Section("Features") {
                    FAQItem(
                        question: "What is CaddieChat?",
                        answer: "CaddieChat is your AI golf advisor that provides personalized tips, course strategy, and answers to golf-related questions based on professional insights."
                    )
                    
                    FAQItem(
                        question: "How does Ball Tracking work?",
                        answer: "Our advanced computer vision tracks your ball's trajectory and provides detailed flight analysis including distance, speed, and launch angle."
                    )
                    
                    FAQItem(
                        question: "What is the Physics Engine?",
                        answer: "Coming soon! Our Physics Engine will provide deep biomechanical analysis of your swing, including detailed body movement and club path analysis."
                    )
                }
                
                Section("Account & Profile") {
                    FAQItem(
                        question: "How do I update my profile?",
                        answer: "Go to Settings > Profile and tap 'Edit Profile' to update your handicap, home course, and other golf information."
                    )
                    
                    FAQItem(
                        question: "Is my data private?",
                        answer: "Yes! We only collect anonymous analytics data. Your personal information and swing videos stay on your device. Check Settings > Privacy for more details."
                    )
                }
                
                Section("Troubleshooting") {
                    FAQItem(
                        question: "The app is running slowly",
                        answer: "Try lowering your video quality in Settings > Video Quality. Also ensure you have sufficient storage space on your device."
                    )
                    
                    FAQItem(
                        question: "Swing analysis isn't working",
                        answer: "Ensure good lighting, steady camera position, and clear view of your swing. The golfer should be clearly visible throughout the entire swing motion."
                    )
                }
                
                Section("Contact") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Still need help?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Contact our support team at support@golfswingai.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Help & FAQ")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                SimpleAnalytics.shared.trackAppUsage(screen: "help_faq")
            }
        }
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
        .environmentObject(AuthenticationManager())
}