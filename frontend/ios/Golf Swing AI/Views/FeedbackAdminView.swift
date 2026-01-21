import SwiftUI

/// Admin view to review CaddieChat feedback from all users (synced via iCloud)
struct FeedbackAdminView: View {
    @StateObject private var feedbackManager = CaddieFeedbackManager.shared
    @State private var selectedTab = 0
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Stats Header
            statsHeader

            // Tab Picker
            Picker("View", selection: $selectedTab) {
                Text("Ratings (\(feedbackManager.ratings.count))").tag(0)
                Text("Unknown (\(feedbackManager.unknownQuestions.count))").tag(1)
                Text("Corrections (\(feedbackManager.pendingCorrections.count))").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            TabView(selection: $selectedTab) {
                ratingsView.tag(0)
                unknownQuestionsView.tag(1)
                correctionsView.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Feedback Admin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { feedbackManager.forceSync() }) {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(action: exportFeedback) {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        let stats = feedbackManager.getStats()

        return VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatBox(
                    title: "Helpful",
                    value: "\(Int(stats.helpfulPercentage))%",
                    color: .green
                )

                StatBox(
                    title: "Total Ratings",
                    value: "\(stats.totalRatings)",
                    color: .blue
                )

                StatBox(
                    title: "Unknown Q's",
                    value: "\(stats.unknownQuestionsCount)",
                    color: .orange
                )
            }

            if let lastSync = feedbackManager.lastSyncDate {
                Text("Last synced: \(lastSync, formatter: relativeDateFormatter)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Ratings View

    private var ratingsView: some View {
        List {
            Section("Unhelpful Responses (Priority)") {
                let unhelpful = feedbackManager.getUnhelpfulRatings()
                if unhelpful.isEmpty {
                    Text("No unhelpful ratings yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(unhelpful.prefix(20)) { rating in
                        RatingRow(rating: rating)
                    }
                }
            }

            Section("Recent Helpful") {
                let helpful = feedbackManager.ratings.filter { $0.helpful }.prefix(10)
                ForEach(Array(helpful)) { rating in
                    RatingRow(rating: rating)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Unknown Questions View

    private var unknownQuestionsView: some View {
        List {
            Section("Most Asked (Add these first!)") {
                let topQuestions = feedbackManager.getTopUnknownQuestions(limit: 20)
                if topQuestions.isEmpty {
                    Text("No unknown questions logged")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(topQuestions) { question in
                        UnknownQuestionRow(question: question) {
                            feedbackManager.clearUnknownQuestion(question)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Corrections View

    private var correctionsView: some View {
        List {
            Section("Pending Corrections") {
                if feedbackManager.pendingCorrections.isEmpty {
                    Text("No corrections submitted")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(feedbackManager.pendingCorrections) { correction in
                        CorrectionRow(correction: correction) {
                            feedbackManager.approveCorrection(correction)
                        }
                    }
                }
            }

            Section("Custom Responses (\(feedbackManager.customResponses.count))") {
                ForEach(feedbackManager.customResponses) { custom in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(custom.triggers.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(custom.response.prefix(100) + "...")
                            .font(.subheadline)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func exportFeedback() {
        if let url = feedbackManager.exportFeedbackData() {
            exportURL = url
            showExportSheet = true
        }
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RatingRow: View {
    let rating: ResponseRating

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: rating.helpful ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                    .foregroundColor(rating.helpful ? .green : .orange)

                Text(rating.question)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Spacer()
            }

            Text(rating.responsePreview)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Text(rating.timestamp, formatter: relativeDateFormatter)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(rating.deviceId.prefix(8)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct UnknownQuestionRow: View {
    let question: UnknownQuestion
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(question.question)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(question.askCount)x")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange))
            }

            HStack {
                Text("First: \(question.firstAsked, formatter: shortDateFormatter)")
                Text("•")
                Text("Last: \(question.lastAsked, formatter: shortDateFormatter)")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onClear()
            } label: {
                Label("Clear", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }
}

struct CorrectionRow: View {
    let correction: CaddieCorrection
    let onApprove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(correction.question)
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(correction.wrongResponse)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(correction.correctAnswer)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }

            HStack {
                Text(correction.submittedAt, formatter: relativeDateFormatter)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Approve") {
                    onApprove()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Formatters

@MainActor
private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
}()

@MainActor
private let shortDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
}()

#Preview {
    NavigationView {
        FeedbackAdminView()
    }
}
