import SwiftUI

// MARK: - Round Summary View

struct RoundSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logManager = RoundLogManager.shared

    let initialRound: GolfRound
    @State private var round: GolfRound

    init(round: GolfRound) {
        self.initialRound = round
        self._round = State(initialValue: round)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Header Card
                    SummaryHeaderCard(round: round)

                    // MARK: - Stats Grid
                    SummaryStatsGrid(round: round)

                    // MARK: - Scorecard
                    SummaryScorecard(round: round)

                    // MARK: - Notable Holes
                    if hasNotableHoles {
                        NotableHolesSection(round: round)
                    }

                    // MARK: - Round Notes
                    if !round.notes.isEmpty {
                        SummaryNotesCard(notes: round.notes, title: "Round Notes")
                    }

                    // MARK: - Hole Notes
                    let holesWithNotes = round.holes.filter { !$0.notes.isEmpty }
                    if !holesWithNotes.isEmpty {
                        HoleNotesListSection(holes: holesWithNotes)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Round Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .onAppear {
            if let fresh = logManager.rounds.first(where: { $0.id == round.id }) {
                round = fresh
            }
        }
    }

    private var hasNotableHoles: Bool {
        round.holes.contains { hole in
            guard hole.score > 0 else { return false }
            return (hole.score - hole.par) <= -1  // birdie or better
        }
    }
}

// MARK: - Summary Header Card

struct SummaryHeaderCard: View {
    let round: GolfRound

    var body: some View {
        VStack(spacing: 12) {
            // Course name
            Text(round.courseName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // Meta info
            HStack(spacing: 16) {
                Label(round.formattedDate, systemImage: "calendar")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                if !round.teePlayed.isEmpty {
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("\(round.teePlayed) Tees")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text("·")
                    .foregroundColor(.secondary)
                Text("\(round.numberOfHoles) Holes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Big score display
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("\(round.totalScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Total Score")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text(round.scoreRelativeToParString)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(round.scoreColor)
                    Text("To Par")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(round.totalPar)")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary)
                    Text("Course Par")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Stats Grid

struct SummaryStatsGrid: View {
    let round: GolfRound

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SummaryStatCard(
                    icon: "arrow.up.right.circle.fill",
                    title: "Fairways Hit",
                    value: round.fairwayOpportunities > 0
                        ? "\(round.fairwaysHit)/\(round.fairwayOpportunities)"
                        : "–",
                    subtitle: round.fairwayOpportunities > 0
                        ? "\(Int(Double(round.fairwaysHit) / Double(round.fairwayOpportunities) * 100))%"
                        : nil,
                    color: .green
                )

                SummaryStatCard(
                    icon: "flag.fill",
                    title: "Greens in Reg",
                    value: round.girOpportunities > 0
                        ? "\(round.greensInRegulation)/\(round.girOpportunities)"
                        : "–",
                    subtitle: round.girOpportunities > 0
                        ? "\(Int(Double(round.greensInRegulation) / Double(round.girOpportunities) * 100))%"
                        : nil,
                    color: .blue
                )

                SummaryStatCard(
                    icon: "arrow.right.circle.fill",
                    title: "Total Putts",
                    value: round.totalPutts > 0 ? "\(round.totalPutts)" : "–",
                    subtitle: round.holesPlayed > 0 && round.totalPutts > 0
                        ? String(format: "%.1f avg", Double(round.totalPutts) / Double(round.holesPlayed))
                        : nil,
                    color: .purple
                )

                SummaryStatCard(
                    icon: "checkmark.circle.fill",
                    title: "Holes Played",
                    value: "\(round.holesPlayed)/\(round.numberOfHoles)",
                    subtitle: round.isCompleted ? "Completed" : "In progress",
                    color: round.isCompleted ? .forestGreen : .orange
                )
            }
        }
    }
}

struct SummaryStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Scorecard

struct SummaryScorecard: View {
    let round: GolfRound
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut) { isExpanded.toggle() } }) {
                HStack {
                    Text("Scorecard")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                // Header row
                ScorecardHeaderRow()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider()
                    .padding(.horizontal, 16)

                // Holes
                ForEach(Array(round.holes.enumerated()), id: \.element.id) { index, hole in
                    if index == 9 && round.numberOfHoles == 18 {
                        // Mid-round divider + front 9 subtotal
                        FrontNineSubtotalRow(holes: Array(round.holes.prefix(9)))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        Divider().padding(.horizontal, 16)
                    }

                    ScorecardHoleRow(hole: hole)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)

                    if index < round.holes.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                            .opacity(0.5)
                    }
                }

                // Total row
                Divider()
                    .padding(.horizontal, 16)
                ScorecardTotalRow(round: round)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct ScorecardHeaderRow: View {
    var body: some View {
        HStack {
            Text("Hole")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
            Text("Par")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .center)
            Spacer()
            Text("Score")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .center)
            Text("+/-")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

struct ScorecardHoleRow: View {
    let hole: HoleEntry

    var body: some View {
        HStack {
            Text("\(hole.holeNumber)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 36, alignment: .leading)

            Text("\(hole.par)")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .center)

            Spacer()

            // Hole notes indicator
            if !hole.notes.isEmpty || !hole.shots.isEmpty {
                HStack(spacing: 4) {
                    if !hole.shots.isEmpty {
                        Text("\(hole.shots.count)s")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    if !hole.notes.isEmpty {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Score box
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(hole.score > 0 ? hole.scoreBackgroundColor : Color.clear)
                    .frame(width: 36, height: 28)

                Text(hole.score > 0 ? "\(hole.score)" : "–")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(hole.score > 0 ? hole.scoreColor : .secondary)
            }
            .frame(width: 52, alignment: .center)

            // +/- column
            if hole.score > 0 {
                Text(hole.scoreRelativeToPar == 0 ? "E" : (hole.scoreRelativeToPar > 0 ? "+\(hole.scoreRelativeToPar)" : "\(hole.scoreRelativeToPar)"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(hole.scoreColor)
                    .frame(width: 44, alignment: .trailing)
            } else {
                Text("–")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

struct FrontNineSubtotalRow: View {
    let holes: [HoleEntry]

    private var parSum: Int { holes.reduce(0) { $0 + $1.par } }
    private var playedScore: Int { holes.filter { $0.score > 0 }.reduce(0) { $0 + $1.score } }
    private var playedPar: Int { holes.filter { $0.score > 0 }.reduce(0) { $0 + $1.par } }
    private var diff: Int { playedScore - playedPar }

    var body: some View {
        HStack {
            Text("OUT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
            Text("\(parSum)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .center)
            Spacer()
            if playedScore > 0 {
                Text("\(playedScore)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 52, alignment: .center)
                Text(diff == 0 ? "E" : (diff > 0 ? "+\(diff)" : "\(diff)"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(diff < 0 ? .green : diff == 0 ? .primary : .orange)
                    .frame(width: 44, alignment: .trailing)
            } else {
                Text("–")
                    .foregroundColor(.secondary)
                    .frame(width: 52, alignment: .center)
                Text("–")
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
        .background(Color(UIColor.tertiarySystemBackground).opacity(0.5))
    }
}

struct ScorecardTotalRow: View {
    let round: GolfRound

    var body: some View {
        HStack {
            Text("TOTAL")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 36, alignment: .leading)
            Text("\(round.totalPar)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .center)
            Spacer()
            if round.totalScore > 0 {
                Text("\(round.totalScore)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 52, alignment: .center)
                Text(round.scoreRelativeToParString)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(round.scoreColor)
                    .frame(width: 44, alignment: .trailing)
            } else {
                Text("–")
                    .foregroundColor(.secondary)
                    .frame(width: 52, alignment: .center)
                Text("–")
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}

// MARK: - Notable Holes

struct NotableHolesSection: View {
    let round: GolfRound

    private var notableHoles: [HoleEntry] {
        round.holes.filter { hole in
            guard hole.score > 0 else { return false }
            return (hole.score - hole.par) <= -1
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlights")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                ForEach(notableHoles) { hole in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(hole.scoreBackgroundColor)
                                .frame(width: 36, height: 36)
                            Text("\(hole.holeNumber)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(hole.scoreColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hole.scoreLabel)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(hole.scoreColor)
                            Text("Par \(hole.par) · Score \(hole.score)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !hole.notes.isEmpty {
                            Image(systemName: "note.text")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
            }
        }
    }
}

// MARK: - Summary Notes Card

struct SummaryNotesCard: View {
    let notes: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            Text(notes)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Hole Notes List

struct HoleNotesListSection: View {
    let holes: [HoleEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hole Notes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                ForEach(holes) { hole in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Hole \(hole.holeNumber)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Par \(hole.par)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Text(hole.notes)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
            }
        }
    }
}

#Preview {
    var round = GolfRound(courseName: "Pebble Beach Golf Links", teePlayed: "White", numberOfHoles: 18)
    round.holes[0].score = 4
    round.holes[0].notes = "Pushed the drive right, recovered well"
    round.holes[1].score = 3
    round.holes[2].score = 5
    round.holes[3].score = 4
    round.isCompleted = true
    return RoundSummaryView(round: round)
}
