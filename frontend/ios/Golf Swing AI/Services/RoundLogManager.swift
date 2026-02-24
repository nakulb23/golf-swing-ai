import Foundation
import SwiftUI

// MARK: - Round Log Manager

@MainActor
final class RoundLogManager: ObservableObject {

    static let shared = RoundLogManager()

    @Published private(set) var rounds: [GolfRound] = []

    private let storageKey = "golf_round_log_v1"

    private init() {
        loadRounds()
    }

    // MARK: - CRUD

    func addRound(_ round: GolfRound) {
        rounds.insert(round, at: 0)
        saveRounds()
    }

    func updateRound(_ round: GolfRound) {
        guard let index = rounds.firstIndex(where: { $0.id == round.id }) else { return }
        rounds[index] = round
        saveRounds()
    }

    func deleteRound(at offsets: IndexSet) {
        rounds.remove(atOffsets: offsets)
        saveRounds()
    }

    func deleteRound(_ round: GolfRound) {
        rounds.removeAll { $0.id == round.id }
        saveRounds()
    }

    func completeRound(_ round: GolfRound) {
        var completed = round
        completed.isCompleted = true
        updateRound(completed)
    }

    // MARK: - Hole Updates

    func updateHole(roundID: UUID, hole: HoleEntry) {
        guard let roundIndex = rounds.firstIndex(where: { $0.id == roundID }) else { return }
        guard let holeIndex = rounds[roundIndex].holes.firstIndex(where: { $0.id == hole.id }) else { return }
        rounds[roundIndex].holes[holeIndex] = hole
        saveRounds()
    }

    // MARK: - Stats

    var totalRoundsPlayed: Int { rounds.count }

    var completedRounds: [GolfRound] { rounds.filter { $0.isCompleted } }

    var bestScore: Int? {
        completedRounds
            .filter { $0.totalScore > 0 }
            .min(by: { $0.scoreRelativeToPar < $1.scoreRelativeToPar })
            .map { $0.scoreRelativeToPar }
    }

    var averageScore: Double? {
        let completed = completedRounds.filter { $0.totalScore > 0 }
        guard !completed.isEmpty else { return nil }
        let sum = completed.reduce(0) { $0 + $1.scoreRelativeToPar }
        return Double(sum) / Double(completed.count)
    }

    var mostPlayedCourse: String? {
        guard !rounds.isEmpty else { return nil }
        let counts = Dictionary(grouping: rounds, by: { $0.courseName })
        return counts.max(by: { $0.value.count < $1.value.count })?.key
    }

    var inProgressRound: GolfRound? {
        rounds.first { !$0.isCompleted }
    }

    // MARK: - Persistence

    private func saveRounds() {
        do {
            let data = try JSONEncoder().encode(rounds)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[RoundLogManager] Failed to save rounds: \(error)")
        }
    }

    private func loadRounds() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            rounds = try JSONDecoder().decode([GolfRound].self, from: data)
        } catch {
            print("[RoundLogManager] Failed to load rounds: \(error)")
            rounds = []
        }
    }
}
