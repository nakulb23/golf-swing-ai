import SwiftUI

struct SwingFeedbackView: View {
    let feedback: SwingFeedback
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Overall Score Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Swing Analysis")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Complete breakdown of your swing")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Overall Score Circle
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0, to: feedback.overallScore / 100)
                                .stroke(
                                    scoreColor(feedback.overallScore),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 2) {
                                Text("\(Int(feedback.overallScore))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(scoreColor(feedback.overallScore))
                                
                                Text("/ 100")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Score Description
                    Text(scoreDescription(feedback.overallScore))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .background(Color(UIColor.secondarySystemBackground))
                
                // Tab Selector
                HStack(spacing: 0) {
                    FeedbackTabButton(title: "Issues", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    FeedbackTabButton(title: "Strengths", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    FeedbackTabButton(title: "Compare", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                    FeedbackTabButton(title: "Practice", isSelected: selectedTab == 3) {
                        selectedTab = 3
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(UIColor.systemBackground))
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    ImprovementsView(improvements: feedback.improvements)
                        .tag(0)
                    
                    StrengthsView(strengths: feedback.strengths)
                        .tag(1)
                    
                    ComparisonView(comparisons: feedback.eliteBenchmarks)
                        .tag(2)
                    
                    PracticeView(recommendations: feedback.practiceRecommendations)
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareResults) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60...79: return .orange
        default: return .red
        }
    }
    
    private func scoreDescription(_ score: Double) -> String {
        switch score {
        case 90...100: return "Excellent swing mechanics! You're performing at a high level."
        case 80...89: return "Very good swing with room for minor improvements."
        case 70...79: return "Good foundation with some areas needing attention."
        case 60...69: return "Average swing with several improvement opportunities."
        case 50...59: return "Below average - focus on fundamental improvements."
        default: return "Significant work needed on basic swing mechanics."
        }
    }
    
    private func shareResults() {
        // Implementation for sharing results
    }
}

// MARK: - Tab Button

struct FeedbackTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? .blue : Color.clear)
                )
        }
    }
}

// MARK: - Improvements View

struct ImprovementsView: View {
    let improvements: [ImprovementRecommendation]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if improvements.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("No Major Issues Found!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Your swing mechanics look great. Keep practicing to maintain consistency.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 50)
                } else {
                    ForEach(improvements.indices, id: \.self) { index in
                        ImprovementCard(improvement: improvements[index])
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

struct ImprovementCard: View {
    let improvement: ImprovementRecommendation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: improvement.area.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(improvement.priority.color)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(improvement.priority.color.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(improvement.area.rawValue)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(improvement.priority.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(improvement.priority.color))
                        }
                        
                        if let impact = improvement.impactOnDistance {
                            Text("+\(Int(impact)) yards potential")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Issue Description
            Text(improvement.issue)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.primary)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Solution
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Solution")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(improvement.solution)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    // Drills
                    if !improvement.drills.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Practice Drills")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            ForEach(improvement.drills.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.blue)
                                    
                                    Text(improvement.drills[index])
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Strengths View

struct StrengthsView: View {
    let strengths: [StrengthArea]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if strengths.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.golf")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Keep Working!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Focus on the improvement areas to develop your strengths.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 50)
                } else {
                    ForEach(strengths.indices, id: \.self) { index in
                        StrengthCard(strength: strengths[index])
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

struct StrengthCard: View {
    let strength: StrengthArea
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: strength.area.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.green)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(strength.area.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(strength.professionalLevel))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Text(strength.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Comparison View

struct ComparisonView: View {
    let comparisons: [EliteBenchmark]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Text("vs. Elite Player Average")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                ForEach(comparisons.indices, id: \.self) { index in
                    ComparisonCard(comparison: comparisons[index])
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}

struct ComparisonCard: View {
    let comparison: EliteBenchmark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(comparison.metric)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Value")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", comparison.userValue)) \(comparison.unit)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Pro Average")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", comparison.eliteAverage)) \(comparison.unit)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            // Percentile bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Percentile")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(comparison.percentile))th")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(percentileColor(comparison.percentile))
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(percentileColor(comparison.percentile))
                            .frame(width: geometry.size.width * (comparison.percentile / 100), height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    private func percentileColor(_ percentile: Double) -> Color {
        switch percentile {
        case 75...100: return .green
        case 50...74: return .orange
        default: return .red
        }
    }
}

// MARK: - Practice View

struct PracticeView: View {
    let recommendations: [PracticeRecommendation]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Text("Recommended Practice Plan")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                ForEach(recommendations.indices, id: \.self) { index in
                    PracticeCard(recommendation: recommendations[index])
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}

struct PracticeCard: View {
    let recommendation: PracticeRecommendation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Label(recommendation.duration, systemImage: "clock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Label(recommendation.frequency, systemImage: "calendar")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(recommendation.difficulty.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(recommendation.difficulty.color))
                    
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(recommendation.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
            
            if isExpanded && !recommendation.equipment.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Equipment Needed")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(recommendation.equipment, id: \.self) { equipment in
                        HStack(spacing: 8) {
                            Text("•")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.blue)
                            
                            Text(equipment)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

#Preview {
    SwingFeedbackView(feedback: SwingFeedback(
        overallScore: 75,
        improvements: [],
        strengths: [],
        eliteBenchmarks: [],
        practiceRecommendations: [],
        timestamp: Date()
    ))
}