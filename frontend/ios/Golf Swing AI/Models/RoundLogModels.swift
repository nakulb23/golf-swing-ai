import Foundation
import SwiftUI

// MARK: - Golf Round

struct GolfRound: Codable, Identifiable, Sendable {
    let id: UUID
    var courseName: String
    var date: Date
    var teePlayed: String
    var numberOfHoles: Int
    var holes: [HoleEntry]
    var notes: String
    var weatherConditions: String
    var isCompleted: Bool

    init(courseName: String, teePlayed: String = "White", numberOfHoles: Int = 18) {
        self.id = UUID()
        self.courseName = courseName
        self.date = Date()
        self.teePlayed = teePlayed
        self.numberOfHoles = numberOfHoles
        self.holes = (1...numberOfHoles).map { HoleEntry(holeNumber: $0) }
        self.notes = ""
        self.weatherConditions = ""
        self.isCompleted = false
    }

    var totalScore: Int {
        holes.filter { $0.score > 0 }.reduce(0) { $0 + $1.score }
    }

    var totalPar: Int {
        holes.reduce(0) { $0 + $1.par }
    }

    var scoreRelativeToPar: Int {
        let played = holes.filter { $0.score > 0 }
        let playedPar = played.reduce(0) { $0 + $1.par }
        let playedScore = played.reduce(0) { $0 + $1.score }
        return playedScore - playedPar
    }

    var holesPlayed: Int {
        holes.filter { $0.score > 0 }.count
    }

    var scoreRelativeToParString: String {
        let diff = scoreRelativeToPar
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    var scoreColor: Color {
        let diff = scoreRelativeToPar
        if diff < 0 { return .green }
        if diff == 0 { return .primary }
        if diff <= 3 { return .orange }
        return .red
    }

    var fairwaysHit: Int {
        holes.filter { $0.par >= 4 && ($0.fairwayHit == true) }.count
    }

    var fairwayOpportunities: Int {
        holes.filter { $0.par >= 4 && $0.score > 0 }.count
    }

    var greensInRegulation: Int {
        holes.filter { $0.greenInRegulation == true }.count
    }

    var girOpportunities: Int {
        holes.filter { $0.score > 0 }.count
    }

    var totalPutts: Int {
        holes.reduce(0) { $0 + $1.putts }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Hole Entry

struct HoleEntry: Codable, Identifiable, Sendable {
    let id: UUID
    var holeNumber: Int
    var par: Int
    var score: Int
    var shots: [ShotEntry]
    var notes: String
    var fairwayHit: Bool?
    var greenInRegulation: Bool?
    var putts: Int

    init(holeNumber: Int, par: Int = 4) {
        self.id = UUID()
        self.holeNumber = holeNumber
        self.par = par
        self.score = 0
        self.shots = []
        self.notes = ""
        self.fairwayHit = nil
        self.greenInRegulation = nil
        self.putts = 0
    }

    var scoreRelativeToPar: Int { score - par }

    var scoreLabel: String {
        guard score > 0 else { return "—" }
        let diff = score - par
        switch diff {
        case ..<(-1): return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double"
        case 3: return "Triple"
        default: return "+\(diff)"
        }
    }

    var scoreColor: Color {
        guard score > 0 else { return .secondary }
        let diff = score - par
        if diff < -1 { return Color(red: 0.0, green: 0.5, blue: 0.8) } // eagle - blue
        if diff == -1 { return .green }  // birdie
        if diff == 0 { return .primary } // par
        if diff == 1 { return .orange }  // bogey
        return .red                       // double+
    }

    var scoreBackgroundColor: Color {
        guard score > 0 else { return Color(UIColor.tertiarySystemBackground) }
        let diff = score - par
        if diff < 0 { return .green.opacity(0.15) }
        if diff == 0 { return Color(UIColor.tertiarySystemBackground) }
        if diff == 1 { return .orange.opacity(0.15) }
        return .red.opacity(0.15)
    }
}

// MARK: - Shot Entry

struct ShotEntry: Codable, Identifiable, Sendable {
    let id: UUID
    var shotNumber: Int
    var club: GolfClub
    var outcome: ShotOutcome
    var distanceYards: Int?
    var notes: String

    init(shotNumber: Int, club: GolfClub = .sevenIron, outcome: ShotOutcome = .fairway) {
        self.id = UUID()
        self.shotNumber = shotNumber
        self.club = club
        self.outcome = outcome
        self.distanceYards = nil
        self.notes = ""
    }
}

// MARK: - Golf Club

enum GolfClub: String, CaseIterable, Codable, Sendable {
    case driver = "Driver"
    case threeWood = "3 Wood"
    case fiveWood = "5 Wood"
    case sevenWood = "7 Wood"
    case twoHybrid = "2 Hybrid"
    case threeHybrid = "3 Hybrid"
    case fourHybrid = "4 Hybrid"
    case twoIron = "2 Iron"
    case threeIron = "3 Iron"
    case fourIron = "4 Iron"
    case fiveIron = "5 Iron"
    case sixIron = "6 Iron"
    case sevenIron = "7 Iron"
    case eightIron = "8 Iron"
    case nineIron = "9 Iron"
    case pitchingWedge = "PW"
    case gapWedge = "GW"
    case sandWedge = "SW"
    case lobWedge = "LW"
    case sixtyDegree = "60°"
    case putter = "Putter"

    var category: String {
        switch self {
        case .driver, .threeWood, .fiveWood, .sevenWood: return "Woods"
        case .twoHybrid, .threeHybrid, .fourHybrid: return "Hybrids"
        case .twoIron, .threeIron, .fourIron: return "Long Irons"
        case .fiveIron, .sixIron, .sevenIron: return "Mid Irons"
        case .eightIron, .nineIron: return "Short Irons"
        case .pitchingWedge, .gapWedge, .sandWedge, .lobWedge, .sixtyDegree: return "Wedges"
        case .putter: return "Putter"
        }
    }

    static var grouped: [(category: String, clubs: [GolfClub])] {
        let all = GolfClub.allCases
        let categories = ["Woods", "Hybrids", "Long Irons", "Mid Irons", "Short Irons", "Wedges", "Putter"]
        return categories.compactMap { cat in
            let clubs = all.filter { $0.category == cat }
            return clubs.isEmpty ? nil : (category: cat, clubs: clubs)
        }
    }
}

// MARK: - Shot Outcome

enum ShotOutcome: String, CaseIterable, Codable, Sendable {
    case fairway = "Fairway"
    case roughLeft = "Rough Left"
    case roughRight = "Rough Right"
    case teeShot = "Tee Shot"
    case greenInRegulation = "Green (GIR)"
    case justMissedGreen = "Just Missed GIR"
    case bunkerFairway = "Fairway Bunker"
    case bunkerGreen = "Greenside Bunker"
    case chipClose = "Chip Close"
    case chipIn = "Chip In"
    case water = "Water Hazard"
    case outOfBounds = "Out of Bounds"
    case trees = "Trees/Forest"
    case penalty = "Penalty Drop"
    case closePutt = "Putt Made"
    case longPutt = "Long Putt Made"
    case missedPutt = "Putt Missed"
    case holledOut = "Holed Out"

    var outcomeColor: Color {
        switch self {
        case .fairway, .greenInRegulation, .chipClose, .chipIn, .closePutt, .longPutt, .holledOut:
            return .green
        case .roughLeft, .roughRight, .justMissedGreen, .bunkerFairway, .bunkerGreen, .trees, .missedPutt, .teeShot:
            return .orange
        case .water, .outOfBounds, .penalty:
            return .red
        }
    }

    var systemImage: String {
        switch self {
        case .fairway: return "checkmark.circle.fill"
        case .roughLeft, .roughRight: return "leaf.fill"
        case .teeShot: return "figure.golf"
        case .greenInRegulation: return "flag.fill"
        case .justMissedGreen: return "flag"
        case .bunkerFairway, .bunkerGreen: return "waveform"
        case .chipClose: return "arrow.up.right.circle"
        case .chipIn: return "star.fill"
        case .water: return "drop.fill"
        case .outOfBounds: return "xmark.circle.fill"
        case .trees: return "tree.fill"
        case .penalty: return "exclamationmark.triangle.fill"
        case .closePutt, .longPutt: return "checkmark.circle"
        case .missedPutt: return "circle"
        case .holledOut: return "flag.checkered"
        }
    }
}

// MARK: - Tee Options

enum TeeColor: String, CaseIterable, Sendable {
    case black = "Black"
    case blue = "Blue"
    case white = "White"
    case gold = "Gold"
    case red = "Red"
    case green = "Green"
    case custom = "Custom"

    var color: Color {
        switch self {
        case .black: return .black
        case .blue: return .blue
        case .white: return Color(UIColor.systemBackground)
        case .gold: return .yellow
        case .red: return .red
        case .green: return .green
        case .custom: return .purple
        }
    }

    var borderColor: Color {
        switch self {
        case .white: return .gray
        default: return color
        }
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let roundDisplay: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
