import SwiftUI

// MARK: - Active Round View

struct ActiveRoundView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logManager = RoundLogManager.shared

    let initialRound: GolfRound

    @State private var round: GolfRound
    @State private var selectedHole: HoleEntry?
    @State private var showingCompleteAlert = false
    @State private var showingAbandonAlert = false

    init(round: GolfRound) {
        self.initialRound = round
        self._round = State(initialValue: round)
    }

    // Computed totals
    private var playedHoles: [HoleEntry] { round.holes.filter { $0.score > 0 } }
    private var currentTotalScore: Int { playedHoles.reduce(0) { $0 + $1.score } }
    private var currentRelativeToPar: Int {
        let par = playedHoles.reduce(0) { $0 + $1.par }
        return currentTotalScore - par
    }
    private var currentRelativeToParString: String {
        if currentTotalScore == 0 { return "–" }
        if currentRelativeToPar == 0 { return "E" }
        return currentRelativeToPar > 0 ? "+\(currentRelativeToPar)" : "\(currentRelativeToPar)"
    }
    private var scoreColor: Color {
        if currentTotalScore == 0 { return .secondary }
        if currentRelativeToPar < 0 { return .green }
        if currentRelativeToPar == 0 { return .primary }
        if currentRelativeToPar <= 3 { return .orange }
        return .red
    }
    private var nextUnplayedHole: Int? {
        round.holes.first(where: { $0.score == 0 })?.holeNumber
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: Score Banner
                ScoreBanner(
                    courseName: round.courseName,
                    teePlayed: round.teePlayed,
                    holesPlayed: playedHoles.count,
                    totalHoles: round.numberOfHoles,
                    score: currentTotalScore,
                    relativeToPar: currentRelativeToParString,
                    scoreColor: scoreColor
                )

                // MARK: Scorecard
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        // Front 9 header
                        nineHeader(label: "Front 9", holes: Array(round.holes.prefix(9)))
                        ForEach(Array(round.holes.prefix(9).enumerated()), id: \.element.id) { _, hole in
                            HoleRowButton(hole: hole) {
                                selectedHole = hole
                            }
                        }

                        // Front 9 subtotal
                        let front9 = Array(round.holes.prefix(9))
                        NineSubtotal(holes: front9)

                        if round.numberOfHoles == 18 {
                            // Back 9
                            Divider().padding(.vertical, 4)
                            nineHeader(label: "Back 9", holes: Array(round.holes.suffix(9)))
                            ForEach(Array(round.holes.suffix(9).enumerated()), id: \.element.id) { _, hole in
                                HoleRowButton(hole: hole) {
                                    selectedHole = hole
                                }
                            }
                            let back9 = Array(round.holes.suffix(9))
                            NineSubtotal(holes: back9)

                            Divider().padding(.vertical, 4)

                            // Total row
                            TotalRow(round: round)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // MARK: Bottom Action Bar
                bottomBar
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedHole) { hole in
            HoleEntryView(
                hole: hole,
                roundPar: round.totalPar
            ) { updated in
                applyHoleUpdate(updated)
            }
        }
        .alert("Complete Round?", isPresented: $showingCompleteAlert) {
            Button("Complete Round", role: .none) { completeRound() }
            Button("Cancel", role: .cancel) {}
        } message: {
            let unplayed = round.numberOfHoles - playedHoles.count
            if unplayed > 0 {
                Text("You have \(unplayed) hole\(unplayed == 1 ? "" : "s") without a score. Complete anyway?")
            } else {
                Text("Mark this round as complete? Score: \(currentTotalScore) (\(currentRelativeToParString))")
            }
        }
        .alert("Abandon Round?", isPresented: $showingAbandonAlert) {
            Button("Save & Exit", role: .none) { saveAndDismiss() }
            Button("Discard Round", role: .destructive) {
                logManager.deleteRound(round)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your round progress will be saved so you can continue later.")
        }
        .onAppear {
            syncFromManager()
        }
    }

    // MARK: - Nine Header Helper

    @ViewBuilder
    private func nineHeader(label: String, holes: [HoleEntry]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
            let parSum = holes.reduce(0) { $0 + $1.par }
            Text("Par \(parSum)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                Button(action: { showingAbandonAlert = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 14))
                        Text("Exit")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }

                if let nextHole = nextUnplayedHole {
                    Button(action: {
                        if let hole = round.holes.first(where: { $0.holeNumber == nextHole }) {
                            selectedHole = hole
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("Hole \(nextHole)")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.forestGreen)
                        )
                    }
                } else {
                    Button(action: { showingCompleteAlert = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Finish Round")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.forestGreen)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
    }

    // MARK: - Actions

    private func applyHoleUpdate(_ updatedHole: HoleEntry) {
        guard let index = round.holes.firstIndex(where: { $0.id == updatedHole.id }) else { return }
        round.holes[index] = updatedHole
        logManager.updateHole(roundID: round.id, hole: updatedHole)
    }

    private func syncFromManager() {
        if let fresh = logManager.rounds.first(where: { $0.id == round.id }) {
            round = fresh
        }
    }

    private func saveAndDismiss() {
        logManager.updateRound(round)
        dismiss()
    }

    private func completeRound() {
        round.isCompleted = true
        logManager.updateRound(round)
        dismiss()
    }
}

// MARK: - Score Banner

struct ScoreBanner: View {
    let courseName: String
    let teePlayed: String
    let holesPlayed: Int
    let totalHoles: Int
    let score: Int
    let relativeToPar: String
    let scoreColor: Color

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(courseName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if !teePlayed.isEmpty {
                            Text("\(teePlayed) Tees")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(holesPlayed)/\(totalHoles) holes")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(relativeToPar)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(scoreColor)
                    if score > 0 {
                        Text("\(score) total")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
}

// MARK: - Hole Row Button

struct HoleRowButton: View {
    let hole: HoleEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Hole number circle
                ZStack {
                    Circle()
                        .fill(hole.score > 0 ? hole.scoreBackgroundColor : Color(UIColor.tertiarySystemBackground))
                        .frame(width: 36, height: 36)
                    Text("\(hole.holeNumber)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hole.score > 0 ? hole.scoreColor : .secondary)
                }

                // Par label
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hole \(hole.holeNumber)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text("Par \(hole.par)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Shot summary (if any)
                if !hole.shots.isEmpty {
                    Text("\(hole.shots.count) shot\(hole.shots.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // Score display
                if hole.score > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(hole.score)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(hole.scoreColor)
                        Text(hole.scoreLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(hole.scoreColor)
                    }
                    .frame(width: 52)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.forestGreen)
                        .frame(width: 52)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        .buttonStyle(ElegantButtonStyle())
    }
}

// MARK: - Nine Subtotal

struct NineSubtotal: View {
    let holes: [HoleEntry]

    private var parSum: Int { holes.reduce(0) { $0 + $1.par } }
    private var playedHoles: [HoleEntry] { holes.filter { $0.score > 0 } }
    private var scoreSum: Int { playedHoles.reduce(0) { $0 + $1.score } }
    private var diff: Int { scoreSum - playedHoles.reduce(0) { $0 + $1.par } }
    private var diffString: String {
        if scoreSum == 0 { return "–" }
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    var body: some View {
        HStack {
            Text("Subtotal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text("Par \(parSum)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            if scoreSum > 0 {
                Text("\(scoreSum) (\(diffString))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(diff < 0 ? .green : diff == 0 ? .primary : .orange)
            } else {
                Text("–")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
    }
}

// MARK: - Total Row

struct TotalRow: View {
    let round: GolfRound

    var body: some View {
        HStack {
            Text("Total")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
            Text("Par \(round.totalPar)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            if round.totalScore > 0 {
                Text("\(round.totalScore) (\(round.scoreRelativeToParString))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(round.scoreColor)
            } else {
                Text("–")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    let sampleRound = GolfRound(courseName: "Pebble Beach Golf Links", teePlayed: "White", numberOfHoles: 18)
    ActiveRoundView(round: sampleRound)
}
