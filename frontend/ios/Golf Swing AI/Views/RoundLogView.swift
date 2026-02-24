import SwiftUI

// MARK: - Round Log View (Main Tab)

struct RoundLogView: View {
    @StateObject private var logManager = RoundLogManager.shared
    @State private var showingNewRound = false
    @State private var selectedRound: GolfRound?
    @State private var showingActiveRound: GolfRound?
    @State private var showingDeleteAlert = false
    @State private var roundToDelete: GolfRound?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Round Log")
                                .font(.system(size: 24, weight: .medium, design: .serif))
                                .foregroundColor(.primary)
                            Text("On-course scoring & notes")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { showingNewRound = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("New Round")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.forestGreen)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                    // MARK: Stats Summary (if rounds exist)
                    if !logManager.rounds.isEmpty {
                        RoundLogStatsBar(logManager: logManager)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }

                    // MARK: In-Progress Round Banner
                    if let inProgress = logManager.inProgressRound {
                        InProgressRoundBanner(round: inProgress) {
                            showingActiveRound = inProgress
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }

                    // MARK: Round List
                    if logManager.rounds.isEmpty {
                        RoundLogEmptyState {
                            showingNewRound = true
                        }
                    } else {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Your Rounds")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(logManager.rounds.count) round\(logManager.rounds.count == 1 ? "" : "s")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)

                            LazyVStack(spacing: 12) {
                                ForEach(logManager.rounds) { round in
                                    RoundCardView(round: round)
                                        .onTapGesture {
                                            if round.isCompleted {
                                                selectedRound = round
                                            } else {
                                                showingActiveRound = round
                                            }
                                        }
                                        .contextMenu {
                                            if !round.isCompleted {
                                                Button {
                                                    showingActiveRound = round
                                                } label: {
                                                    Label("Continue Round", systemImage: "play.fill")
                                                }
                                            }
                                            Button {
                                                selectedRound = round
                                            } label: {
                                                Label("View Summary", systemImage: "list.bullet.clipboard")
                                            }
                                            Divider()
                                            Button(role: .destructive) {
                                                roundToDelete = round
                                                showingDeleteAlert = true
                                            } label: {
                                                Label("Delete Round", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }

                    Spacer(minLength: 60)
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingNewRound) {
            NewRoundView { newRound in
                logManager.addRound(newRound)
                showingActiveRound = newRound
            }
        }
        .sheet(item: $showingActiveRound) { round in
            ActiveRoundView(round: round)
        }
        .sheet(item: $selectedRound) { round in
            RoundSummaryView(round: round)
        }
        .alert("Delete Round?", isPresented: $showingDeleteAlert, presenting: roundToDelete) { round in
            Button("Delete", role: .destructive) {
                logManager.deleteRound(round)
            }
            Button("Cancel", role: .cancel) {}
        } message: { round in
            Text("Are you sure you want to delete the round at \(round.courseName)? This cannot be undone.")
        }
    }
}

// MARK: - Stats Bar

struct RoundLogStatsBar: View {
    @ObservedObject var logManager: RoundLogManager

    var body: some View {
        HStack(spacing: 12) {
            RoundLogStatChip(
                label: "Rounds",
                value: "\(logManager.totalRoundsPlayed)",
                color: .forestGreen
            )

            if let best = logManager.bestScore {
                RoundLogStatChip(
                    label: "Best",
                    value: best == 0 ? "E" : (best > 0 ? "+\(best)" : "\(best)"),
                    color: best < 0 ? .green : (best == 0 ? .primary : .orange)
                )
            }

            if let avg = logManager.averageScore {
                let avgRounded = Int(avg.rounded())
                RoundLogStatChip(
                    label: "Avg",
                    value: avgRounded == 0 ? "E" : (avgRounded > 0 ? "+\(avgRounded)" : "\(avgRounded)"),
                    color: .blue
                )
            }

            Spacer()
        }
    }
}

struct RoundLogStatChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - In-Progress Banner

struct InProgressRoundBanner: View {
    let round: GolfRound
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "flag.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Round in Progress")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(round.courseName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text("Hole \(round.holesPlayed + 1) of \(round.numberOfHoles)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(ElegantButtonStyle())
    }
}

// MARK: - Round Card

struct RoundCardView: View {
    let round: GolfRound

    var body: some View {
        HStack(spacing: 14) {
            // Left: Score badge
            VStack(spacing: 2) {
                if round.totalScore > 0 {
                    Text(round.scoreRelativeToParString)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(round.scoreColor)
                    Text("\(round.totalScore)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "flag")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 48)

            // Divider
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(width: 1, height: 40)

            // Center: Course info
            VStack(alignment: .leading, spacing: 4) {
                Text(round.courseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(round.formattedDate, systemImage: "calendar")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)

                    if !round.teePlayed.isEmpty && round.teePlayed != "White" {
                        Text("• \(round.teePlayed) Tees")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text("\(round.holesPlayed)/\(round.numberOfHoles) holes")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(round.isCompleted ? .secondary : .orange)

                    if !round.isCompleted {
                        Text("IN PROGRESS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Empty State

struct RoundLogEmptyState: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 52, weight: .light))
                    .foregroundColor(.forestGreen.opacity(0.5))

                Text("No rounds logged yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Start tracking your rounds on the course — log your shots, scores, and notes hole by hole.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Start Your First Round")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.forestGreen)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
    }
}

#Preview {
    RoundLogView()
}
