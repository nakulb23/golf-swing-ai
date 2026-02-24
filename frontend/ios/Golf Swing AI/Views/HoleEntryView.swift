import SwiftUI

// MARK: - Hole Entry View

struct HoleEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let initialHole: HoleEntry
    let roundPar: Int
    let onSave: (HoleEntry) -> Void

    @State private var hole: HoleEntry
    @State private var showingAddShot = false
    @State private var editingShot: ShotEntry?
    @State private var notesText: String

    init(hole: HoleEntry, roundPar: Int, onSave: @escaping (HoleEntry) -> Void) {
        self.initialHole = hole
        self.roundPar = roundPar
        self.onSave = onSave
        self._hole = State(initialValue: hole)
        self._notesText = State(initialValue: hole.notes)
    }

    private var scoreLabel: String {
        guard hole.score > 0 else { return "–" }
        return hole.scoreLabel
    }

    private var scoreDiff: Int { hole.score - hole.par }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: - Score Entry
                    HoleScoreCard(hole: $hole)

                    // MARK: - Stats Row
                    if hole.par >= 4 {
                        HoleStatsRow(hole: $hole)
                    }

                    // MARK: - Shot Log
                    ShotLogSection(hole: $hole)

                    // MARK: - Notes
                    HoleNotesSection(notes: $notesText)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Hole \(hole.holeNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.forestGreen)
                }
            }
        }
    }

    private func save() {
        hole.notes = notesText
        onSave(hole)
        dismiss()
    }
}

// MARK: - Hole Score Card

struct HoleScoreCard: View {
    @Binding var hole: HoleEntry

    var body: some View {
        VStack(spacing: 16) {
            // Par indicator
            HStack {
                Label("Par \(hole.par)", systemImage: "flag")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                if hole.score > 0 {
                    Text(hole.scoreLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(hole.scoreColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(hole.scoreBackgroundColor)
                        )
                }
            }

            // Large score stepper
            HStack(spacing: 32) {
                Button(action: { if hole.score > 0 { hole.score -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(hole.score > 0 ? .primary : .secondary)
                }
                .disabled(hole.score == 0)

                VStack(spacing: 4) {
                    Text(hole.score == 0 ? "–" : "\(hole.score)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(hole.score == 0 ? .secondary : hole.scoreColor)
                        .animation(.easeInOut(duration: 0.15), value: hole.score)
                    Text("strokes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 100)

                Button(action: { hole.score += 1 }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Hole Stats Row

struct HoleStatsRow: View {
    @Binding var hole: HoleEntry

    var body: some View {
        HStack(spacing: 12) {
            // Fairway Hit (par 4/5 only)
            if hole.par >= 4 {
                StatToggleCard(
                    icon: "arrow.up.right.circle.fill",
                    label: "Fairway",
                    isOn: Binding(
                        get: { hole.fairwayHit == true },
                        set: { hole.fairwayHit = $0 ? true : false }
                    ),
                    activeColor: .green
                )
            }

            // GIR
            StatToggleCard(
                icon: "flag.fill",
                label: "GIR",
                isOn: Binding(
                    get: { hole.greenInRegulation == true },
                    set: { hole.greenInRegulation = $0 ? true : false }
                ),
                activeColor: .blue
            )

            // Putts stepper
            PuttsStepper(putts: $hole.putts)
        }
    }
}

struct StatToggleCard: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    let activeColor: Color

    var body: some View {
        Button(action: { isOn.toggle() }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isOn ? activeColor : .secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isOn ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isOn ? activeColor.opacity(0.12) : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn ? activeColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(ElegantButtonStyle())
    }
}

struct PuttsStepper: View {
    @Binding var putts: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Button(action: { if putts > 0 { putts -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(putts > 0 ? .primary : .secondary)
                }
                .disabled(putts == 0)

                Text("\(putts)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 28)

                Button(action: { putts += 1 }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            Text("Putts")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Shot Log Section

struct ShotLogSection: View {
    @Binding var hole: HoleEntry
    @State private var showingAddShot = false
    @State private var editingShot: ShotEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shot Log")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { showingAddShot = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add Shot")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.forestGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.forestGreen.opacity(0.1))
                    )
                }
            }

            if hole.shots.isEmpty {
                HStack {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("No shots logged yet")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(hole.shots) { shot in
                        ShotRowView(shot: shot)
                            .onTapGesture { editingShot = shot }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    hole.shots.removeAll { $0.id == shot.id }
                                    reNumberShots()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .sheet(isPresented: $showingAddShot) {
            ShotEditorView(
                shotNumber: hole.shots.count + 1,
                shot: nil
            ) { newShot in
                hole.shots.append(newShot)
            }
        }
        .sheet(item: $editingShot) { shot in
            ShotEditorView(
                shotNumber: shot.shotNumber,
                shot: shot
            ) { updated in
                if let idx = hole.shots.firstIndex(where: { $0.id == updated.id }) {
                    hole.shots[idx] = updated
                }
            }
        }
    }

    private func reNumberShots() {
        for i in hole.shots.indices {
            hole.shots[i].shotNumber = i + 1
        }
    }
}

// MARK: - Shot Row View

struct ShotRowView: View {
    let shot: ShotEntry

    var body: some View {
        HStack(spacing: 12) {
            // Shot number badge
            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(width: 28, height: 28)
                Text("\(shot.shotNumber)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
            }

            // Club
            Text(shot.club.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(minWidth: 50, alignment: .leading)

            // Outcome
            HStack(spacing: 4) {
                Image(systemName: shot.outcome.systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(shot.outcome.outcomeColor)
                Text(shot.outcome.rawValue)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Distance
            if let dist = shot.distanceYards {
                Text("\(dist)y")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
    }
}

// MARK: - Shot Editor View

struct ShotEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let shotNumber: Int
    let existingShot: ShotEntry?
    let onSave: (ShotEntry) -> Void

    @State private var selectedClub: GolfClub
    @State private var selectedOutcome: ShotOutcome
    @State private var distanceText: String
    @State private var notes: String
    @State private var shotID: UUID
    /// Tracks which club-category sections are expanded independently of selection.
    @State private var expandedCategories: Set<String>

    init(shotNumber: Int, shot: ShotEntry?, onSave: @escaping (ShotEntry) -> Void) {
        self.shotNumber = shotNumber
        self.existingShot = shot
        self.onSave = onSave
        let defaultClub = shot?.club ?? .sevenIron
        self._selectedClub = State(initialValue: defaultClub)
        self._selectedOutcome = State(initialValue: shot?.outcome ?? .fairway)
        self._distanceText = State(initialValue: shot?.distanceYards != nil ? "\(shot!.distanceYards!)" : "")
        self._notes = State(initialValue: shot?.notes ?? "")
        self._shotID = State(initialValue: shot?.id ?? UUID())
        // Start with the default club's category expanded
        let defaultCategory = GolfClub.grouped.first { $0.clubs.contains(defaultClub) }?.category ?? ""
        self._expandedCategories = State(initialValue: [defaultCategory])
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Club Selection
                Section("Club") {
                    ForEach(GolfClub.grouped, id: \.category) { group in
                        let isSelected = group.clubs.contains(selectedClub)
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedCategories.contains(group.category) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedCategories.insert(group.category)
                                    } else {
                                        expandedCategories.remove(group.category)
                                    }
                                }
                            )
                        ) {
                            ForEach(group.clubs, id: \.self) { club in
                                HStack {
                                    Text(club.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedClub == club {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.forestGreen)
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedClub = club
                                    // Keep the selected club's category open
                                    expandedCategories.insert(group.category)
                                }
                            }
                        } label: {
                            HStack {
                                Text(group.category)
                                    .font(.system(size: 14, weight: .medium))
                                if isSelected {
                                    Text("· \(selectedClub.rawValue)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // MARK: Outcome
                Section("Shot Outcome") {
                    ForEach(ShotOutcome.allCases, id: \.self) { outcome in
                        HStack {
                            Image(systemName: outcome.systemImage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(outcome.outcomeColor)
                                .frame(width: 20)
                            Text(outcome.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedOutcome == outcome {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.forestGreen)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedOutcome = outcome }
                    }
                }

                // MARK: Distance
                Section("Distance (optional)") {
                    HStack {
                        TextField("e.g. 180", text: $distanceText)
                            .keyboardType(.numberPad)
                        Text("yards")
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: Notes
                Section("Shot Notes (optional)") {
                    TextField("Any notes about this shot…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Shot \(shotNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveShot() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.forestGreen)
                }
            }
        }
    }

    private func saveShot() {
        var shot = ShotEntry(
            shotNumber: shotNumber,
            club: selectedClub,
            outcome: selectedOutcome
        )
        shot.distanceYards = Int(distanceText)
        shot.notes = notes
        // Preserve ID if editing
        if existingShot != nil {
            // SwiftUI structs – we'll pass the updated one back identified by shot number
        }
        // Use original id if editing existing
        let finalShot: ShotEntry
        if let existing = existingShot {
            var updated = existing
            updated.club = selectedClub
            updated.outcome = selectedOutcome
            updated.distanceYards = Int(distanceText)
            updated.notes = notes
            finalShot = updated
        } else {
            finalShot = shot
        }
        onSave(finalShot)
        dismiss()
    }
}

// MARK: - Notes Section

struct HoleNotesSection: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Hole Notes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }

            TextField("Course conditions, club thoughts, anything…", text: $notes, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(3...8)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

#Preview {
    HoleEntryView(
        hole: HoleEntry(holeNumber: 1, par: 4),
        roundPar: 72
    ) { _ in }
}
