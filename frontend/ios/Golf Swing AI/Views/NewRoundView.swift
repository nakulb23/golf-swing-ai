import SwiftUI

// MARK: - New Round View

struct NewRoundView: View {
    @Environment(\.dismiss) private var dismiss

    let onStart: (GolfRound) -> Void

    // Course selection
    @State private var searchText = ""
    @State private var selectedCourse: String = ""
    @State private var isCustomCourse = false
    @State private var customCourseName = ""
    @State private var showingCourseSearch = false

    // Round settings
    @State private var selectedDate = Date()
    @State private var numberOfHoles: Int = 18
    @State private var selectedTee: TeeColor = .white
    @State private var customTee: String = ""

    // Par configuration
    @State private var showingParConfig = false
    @State private var holePars: [Int] = [Int](repeating: 4, count: 18)
    @State private var parsAutoFilled = false     // true when loaded from course data
    @State private var selectedGolfCourse: GolfCourse? = nil

    // Validation
    @State private var showingValidationAlert = false

    private var effectiveCourseName: String {
        isCustomCourse ? customCourseName.trimmingCharacters(in: .whitespaces) : selectedCourse
    }

    private var filteredCourses: [GolfCourse] {
        GolfCoursesDatabase.search(searchText)
    }

    private var effectiveTee: String {
        selectedTee == .custom ? customTee.trimmingCharacters(in: .whitespaces) : selectedTee.rawValue
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Course Selection
                    SectionCard(title: "Golf Course") {
                        VStack(spacing: 12) {
                            // Search / Select Course
                            Button(action: { showingCourseSearch = true }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)

                                    if selectedCourse.isEmpty && !isCustomCourse {
                                        Text("Search for a course…")
                                            .font(.system(size: 15))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(isCustomCourse ? (customCourseName.isEmpty ? "Custom course" : customCourseName) : selectedCourse)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor.tertiarySystemBackground))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Toggle for custom entry
                            Toggle(isOn: $isCustomCourse) {
                                Text("Enter a custom course name")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            .tint(Color.forestGreen)

                            if isCustomCourse {
                                TextField("Course name", text: $customCourseName)
                                    .font(.system(size: 15))
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(UIColor.tertiarySystemBackground))
                                    )
                            }
                        }
                    }

                    // MARK: - Date
                    SectionCard(title: "Date") {
                        DatePicker(
                            "Date",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tint(Color.forestGreen)
                    }

                    // MARK: - Holes
                    SectionCard(title: "Number of Holes") {
                        HStack(spacing: 12) {
                            ForEach([9, 18], id: \.self) { count in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        numberOfHoles = count
                                        applyPars(for: count)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: numberOfHoles == count ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(numberOfHoles == count ? .forestGreen : .secondary)
                                        Text("\(count) holes")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(numberOfHoles == count ? .primary : .secondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(numberOfHoles == count
                                                  ? Color.forestGreen.opacity(0.1)
                                                  : Color(UIColor.tertiarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(numberOfHoles == count ? Color.forestGreen.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // MARK: - Tee
                    SectionCard(title: "Tee Played") {
                        VStack(spacing: 12) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                ForEach(TeeColor.allCases, id: \.self) { tee in
                                    Button(action: { selectedTee = tee }) {
                                        VStack(spacing: 6) {
                                            Circle()
                                                .fill(tee.color)
                                                .frame(width: 24, height: 24)
                                                .overlay(
                                                    Circle().stroke(tee.borderColor, lineWidth: 1.5)
                                                )
                                                .overlay(
                                                    Circle().stroke(selectedTee == tee ? Color.forestGreen : Color.clear, lineWidth: 2.5)
                                                        .padding(-3)
                                                )
                                            Text(tee.rawValue)
                                                .font(.system(size: 11, weight: selectedTee == tee ? .semibold : .regular))
                                                .foregroundColor(selectedTee == tee ? .primary : .secondary)
                                        }
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedTee == tee
                                                      ? Color.forestGreen.opacity(0.08)
                                                      : Color(UIColor.tertiarySystemBackground))
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            if selectedTee == .custom {
                                TextField("Tee name (e.g. Championship)", text: $customTee)
                                    .font(.system(size: 15))
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(UIColor.tertiarySystemBackground))
                                    )
                            }
                        }
                    }

                    // MARK: - Par Setup
                    SectionCard(title: "Par Setup") {
                        VStack(spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Total Par: \(holePars.reduce(0, +))")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        if parsAutoFilled {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.forestGreen)
                                        }
                                    }
                                    Text(parsAutoFilled
                                         ? "Auto-filled from course data. Tap Edit to adjust."
                                         : "Default is 4 per hole. Tap Edit to customise.")
                                        .font(.system(size: 12))
                                        .foregroundColor(parsAutoFilled ? .forestGreen : .secondary)
                                }
                                Spacer()
                                Button(action: { showingParConfig.toggle() }) {
                                    Text(showingParConfig ? "Done" : "Edit")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.forestGreen)
                                }
                            }

                            if showingParConfig {
                                Divider()
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 9), spacing: 8) {
                                    ForEach(0..<numberOfHoles, id: \.self) { idx in
                                        ParSelector(
                                            holeNumber: idx + 1,
                                            par: $holePars[idx]
                                        )
                                    }
                                }
                            } else {
                                // Compact preview
                                HStack(spacing: 4) {
                                    ForEach(0..<numberOfHoles, id: \.self) { idx in
                                        VStack(spacing: 1) {
                                            Text("\(idx + 1)")
                                                .font(.system(size: 8, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Text("\(holePars[idx])")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // MARK: - Start Button
                    Button(action: startRound) {
                        HStack(spacing: 10) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("Start Round")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(effectiveCourseName.isEmpty ? Color.gray : Color.forestGreen)
                        )
                    }
                    .disabled(effectiveCourseName.isEmpty)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("New Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingCourseSearch) {
            CourseSearchView(
                selectedCourse: $selectedCourse,
                isCustomCourse: $isCustomCourse,
                onCourseSelected: { course in
                    selectedGolfCourse = course
                    applyPars(for: numberOfHoles)
                }
            )
        }
        .alert("Course Required", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please select or enter a course name to start your round.")
        }
    }

    /// Applies per-hole par values for `count` holes.
    /// Uses the selected course's known pars when available; otherwise defaults to par 4.
    private func applyPars(for count: Int) {
        if let pars = selectedGolfCourse?.holePars {
            if pars.count >= count {
                holePars = Array(pars.prefix(count))
            } else {
                holePars = pars + [Int](repeating: 4, count: count - pars.count)
            }
            parsAutoFilled = true
        } else {
            holePars = [Int](repeating: 4, count: count)
            parsAutoFilled = false
        }
    }

    private func startRound() {
        let name = effectiveCourseName
        guard !name.isEmpty else {
            showingValidationAlert = true
            return
        }

        var round = GolfRound(
            courseName: name,
            teePlayed: effectiveTee,
            numberOfHoles: numberOfHoles
        )
        round.date = selectedDate

        // Apply custom pars
        for (i, par) in holePars.prefix(round.holes.count).enumerated() {
            round.holes[i].par = par
        }

        dismiss()
        onStart(round)
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Par Selector

struct ParSelector: View {
    let holeNumber: Int
    @Binding var par: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(holeNumber)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)

            Menu {
                ForEach([3, 4, 5], id: \.self) { p in
                    Button("Par \(p)") { par = p }
                }
            } label: {
                Text("\(par)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(Color(UIColor.tertiarySystemBackground))
                    )
            }
        }
    }
}

// MARK: - Course Search View

struct CourseSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCourse: String
    @Binding var isCustomCourse: Bool
    /// Called with the full GolfCourse object when a course is tapped (nil for free-text entry).
    var onCourseSelected: ((GolfCourse) -> Void)? = nil
    @State private var searchQuery = ""

    private var results: [GolfCourse] {
        GolfCoursesDatabase.search(searchQuery)
    }

    var body: some View {
        NavigationStack {
            List {
                if !searchQuery.isEmpty {
                    // Option to use exactly what was typed
                    Button(action: {
                        selectedCourse = searchQuery.trimmingCharacters(in: .whitespaces)
                        isCustomCourse = false
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.forestGreen)
                            Text("Use \"\(searchQuery)\"")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.forestGreen)
                        }
                    }
                }

                if results.isEmpty && searchQuery.isEmpty {
                    Section("All Courses") {
                        ForEach(GolfCoursesDatabase.allCourses) { course in
                            courseRow(course)
                        }
                    }
                } else if !results.isEmpty {
                    Section(searchQuery.isEmpty ? "All Courses" : "Results") {
                        ForEach(results) { course in
                            courseRow(course)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Courses Found",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different name or use the option above to add it manually.")
                    )
                }
            }
            .searchable(text: $searchQuery, prompt: "Search courses…")
            .navigationTitle("Select Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func courseRow(_ course: GolfCourse) -> some View {
        Button(action: {
            selectedCourse = course.name
            isCustomCourse = false
            onCourseSelected?(course)
            dismiss()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text("\(course.location) · \(course.country)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let pars = course.holePars {
                    // Show par badge so users know pars will auto-fill
                    Text("Par \(pars.reduce(0, +))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.forestGreen)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.forestGreen.opacity(0.12)))
                }
            }
        }
    }
}

#Preview {
    NewRoundView { _ in }
}
