import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditProfile = false
    @State private var showingAnalysisHistory = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile Image
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(.blue)
                            )
                        
                        // User Info
                        if let user = authManager.currentUser {
                            VStack(spacing: 8) {
                                Text("\(user.firstName) \(user.lastName)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Experience Level Badge
                                Text(user.experienceLevel.rawValue.capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.top)
                    
                    // Golf Stats Section
                    if let user = authManager.currentUser {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Golf Profile")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                ProfileStatsRow(
                                    icon: "gamecontroller.fill",
                                    title: "Experience Level",
                                    value: user.experienceLevel.rawValue.capitalized
                                )
                                
                                if let handicap = user.handicap {
                                    ProfileStatsRow(
                                        icon: "target",
                                        title: "Handicap",
                                        value: String(format: "%.1f", handicap)
                                    )
                                }
                                
                                ProfileStatsRow(
                                    icon: "figure.golf",
                                    title: "Preferred Hand",
                                    value: user.preferredHand.rawValue.capitalized
                                )
                                
                                if let yearsPlayed = user.yearsPlayed {
                                    ProfileStatsRow(
                                        icon: "calendar",
                                        title: "Years Playing",
                                        value: "\(yearsPlayed) years"
                                    )
                                }
                                
                                if let homeCourse = user.homeCourse {
                                    ProfileStatsRow(
                                        icon: "location.fill",
                                        title: "Home Course",
                                        value: homeCourse
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Analysis Stats Section
                    if let user = authManager.currentUser {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Analysis Statistics")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                ProfileStatsRow(
                                    icon: "chart.line.uptrend.xyaxis",
                                    title: "Total Swings Analyzed",
                                    value: "\(user.profile.totalSwingsAnalyzed)"
                                )
                                
                                if user.profile.bestSwingSpeed > 0 {
                                    ProfileStatsRow(
                                        icon: "speedometer",
                                        title: "Best Swing Speed",
                                        value: "\(Int(user.profile.bestSwingSpeed)) mph"
                                    )
                                }
                                
                                if user.profile.averageSwingSpeed > 0 {
                                    ProfileStatsRow(
                                        icon: "chart.bar.fill",
                                        title: "Average Swing Speed",
                                        value: "\(Int(user.profile.averageSwingSpeed)) mph"
                                    )
                                }
                                
                                if !user.profile.swingHistory.isEmpty {
                                    ProfileStatsRow(
                                        icon: "clock.fill",
                                        title: "Last Analysis",
                                        value: timeAgo(from: user.profile.swingHistory.last?.date ?? Date())
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button("Edit Profile") {
                            showingEditProfile = true
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        if let user = authManager.currentUser, !user.profile.swingHistory.isEmpty {
                            Button("View Analysis History") {
                                showingAnalysisHistory = true
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button("Sign Out") {
                            authManager.signOut()
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingAnalysisHistory) {
            AnalysisHistoryView()
                .environmentObject(authManager)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

struct ProfileStatsRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var handicap: String = ""
    @State private var experienceLevel: ExperienceLevel = .beginner
    @State private var preferredHand: PreferredHand = .right
    @State private var yearsPlayed: String = ""
    @State private var homeCourse: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
                
                Section("Golf Profile") {
                    Picker("Experience Level", selection: $experienceLevel) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    
                    Picker("Preferred Hand", selection: $preferredHand) {
                        ForEach(PreferredHand.allCases, id: \.self) { hand in
                            Text(hand.rawValue.capitalized).tag(hand)
                        }
                    }
                    
                    TextField("Handicap", text: $handicap)
                        .keyboardType(.decimalPad)
                    
                    TextField("Years Playing", text: $yearsPlayed)
                        .keyboardType(.numberPad)
                    
                    TextField("Home Course", text: $homeCourse)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    private func loadCurrentProfile() {
        guard let user = authManager.currentUser else { return }
        firstName = user.firstName
        lastName = user.lastName
        handicap = user.handicap != nil ? String(user.handicap!) : ""
        experienceLevel = user.experienceLevel
        preferredHand = user.preferredHand
        yearsPlayed = user.yearsPlayed != nil ? String(user.yearsPlayed!) : ""
        homeCourse = user.homeCourse ?? ""
    }
    
    private func saveProfile() {
        guard var user = authManager.currentUser else { return }
        
        user.firstName = firstName
        user.lastName = lastName
        user.handicap = Double(handicap)
        user.experienceLevel = experienceLevel
        user.preferredHand = preferredHand
        user.yearsPlayed = Int(yearsPlayed)
        user.homeCourse = homeCourse.isEmpty ? nil : homeCourse
        
        authManager.updateUserProfile(user)
        dismiss()
    }
}

struct AnalysisHistoryView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if let user = authManager.currentUser {
                    ForEach(user.profile.swingHistory.reversed(), id: \.date) { analysis in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(analysis.swingType.capitalized)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(timeAgo(from: analysis.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                if analysis.swingSpeed > 0 {
                                    Label("\(Int(analysis.swingSpeed)) mph", systemImage: "speedometer")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                Label(String(format: "%.1f", analysis.accuracy), systemImage: "target")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    ContentUnavailableView(
                        "No Analysis History",
                        systemImage: "chart.bar",
                        description: Text("Your swing analysis history will appear here.")
                    )
                }
            }
            .navigationTitle("Analysis History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
}