import SwiftUI
import Charts

struct UserProgressView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTimeframe: ProgressTimeframe = .week
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // User Summary Card
                    if let user = authManager.currentUser {
                        UserSummaryCard(user: user)
                            .padding(.horizontal, 20)
                    }
                    
                    // Timeframe Selector
                    TimeframePicker(selectedTimeframe: $selectedTimeframe)
                        .padding(.horizontal, 20)
                    
                    // Progress Charts
                    VStack(spacing: 20) {
                        SwingSpeedChart(timeframe: selectedTimeframe)
                        AccuracyChart(timeframe: selectedTimeframe)
                        ConsistencyChart(timeframe: selectedTimeframe)
                    }
                    .padding(.horizontal, 20)
                    
                    // Goals Section
                    if let user = authManager.currentUser, !user.profile.goals.isEmpty {
                        GoalsSection(goals: user.profile.goals)
                            .padding(.horizontal, 20)
                    }
                    
                    // Achievements Section
                    if let user = authManager.currentUser, !user.profile.achievements.isEmpty {
                        AchievementsSection(achievements: user.profile.achievements)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
            }
            .background(Color.primaryBackgroundDynamic)
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - User Summary Card
struct UserSummaryCard: View {
    let user: User
    
    var body: some View {
        GolfCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back, \(user.firstName)!")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let handicap = user.handicap {
                            Text("Handicap: \(String(format: "%.1f", handicap))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                }
                
                Divider()
                
                HStack {
                    ProgressStatItem(
                        title: "Total Swings",
                        value: "\(user.profile.totalSwingsAnalyzed)",
                        icon: "figure.golf"
                    )
                    
                    Spacer()
                    
                    ProgressStatItem(
                        title: "Best Speed",
                        value: String(format: "%.0f mph", user.profile.bestSwingSpeed),
                        icon: "speedometer"
                    )
                    
                    Spacer()
                    
                    ProgressStatItem(
                        title: "Sessions",
                        value: "\(user.profile.totalPlayingSessions)",
                        icon: "calendar"
                    )
                }
            }
        }
    }
}

struct ProgressStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Timeframe Picker
enum ProgressTimeframe: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case quarter = "3 Months"
    case year = "Year"
}

struct TimeframePicker: View {
    @Binding var selectedTimeframe: ProgressTimeframe
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ProgressTimeframe.allCases, id: \.self) { timeframe in
                Button(timeframe.rawValue) {
                    selectedTimeframe = timeframe
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedTimeframe == timeframe ? Color.forestGreen : Color.gray.opacity(0.2))
                )
                .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                .font(.caption)
            }
        }
    }
}

// MARK: - Progress Charts
struct SwingSpeedChart: View {
    let timeframe: ProgressTimeframe
    
    var body: some View {
        GolfCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Swing Speed Trend")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "speedometer")
                        .foregroundColor(.green)
                }
                
                // Chart placeholder - will be populated with actual data
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentDynamic.opacity(0.1))
                    .frame(height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Swing Speed Chart")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Record swings to see data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

struct AccuracyChart: View {
    let timeframe: ProgressTimeframe
    
    var body: some View {
        GolfCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Accuracy Improvement")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "target")
                        .foregroundColor(.green)
                }
                
                // Chart placeholder - will be populated with actual data
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentDynamic.opacity(0.1))
                    .frame(height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: "target")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Accuracy Chart")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Record swings to see data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

struct ConsistencyChart: View {
    let timeframe: ProgressTimeframe
    
    var body: some View {
        GolfCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Consistency Score")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                }
                
                // Chart placeholder - will be populated with actual data
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentDynamic.opacity(0.1))
                    .frame(height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Consistency Chart")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Record swings to see data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

// MARK: - Goals Section
struct GoalsSection: View {
    let goals: [UserGoal]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Goals")
                .font(.title)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(goals) { goal in
                    GoalProgressCard(goal: goal)
                }
            }
        }
    }
}

struct GoalProgressCard: View {
    let goal: UserGoal
    
    var body: some View {
        GolfCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if goal.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.success)
                    }
                }
                
                Text(goal.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: goal.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                
                HStack {
                    Text("\(String(format: "%.1f", goal.currentValue)) / \(String(format: "%.1f", goal.targetValue)) \(goal.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.0f", goal.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
}

// MARK: - Achievements Section
struct AchievementsSection: View {
    let achievements: [Achievement]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Achievements")
                .font(.title)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(achievements.prefix(5)) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: achievement.iconName)
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text(achievement.title)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(achievement.dateEarned, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 120, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackgroundDynamic)
                .golfCardShadow()
        )
    }
}

#Preview {
    UserProgressView()
        .environmentObject(AuthenticationManager())
}