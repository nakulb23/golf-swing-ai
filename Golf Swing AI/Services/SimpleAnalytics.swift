import Foundation
import UIKit

// MARK: - Simple Anonymous Analytics Service
class SimpleAnalytics: ObservableObject {
    static let shared = SimpleAnalytics()
    
    @Published var isEnabled = true
    
    private let userDefaults = UserDefaults.standard
    private let sessionIdKey = "analytics_session_id"
    private let dataKey = "analytics_data"
    
    private init() {
        ensureSessionId()
    }
    
    // MARK: - Session Management
    private func ensureSessionId() {
        if userDefaults.string(forKey: sessionIdKey) == nil {
            let sessionId = UUID().uuidString
            userDefaults.set(sessionId, forKey: sessionIdKey)
        }
    }
    
    private var sessionId: String {
        return userDefaults.string(forKey: sessionIdKey) ?? UUID().uuidString
    }
    
    // MARK: - Data Collection
    func trackEvent(_ eventName: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        
        var event: [String: Any] = [
            "id": UUID().uuidString,
            "session": sessionId,
            "event": eventName,
            "timestamp": Date().timeIntervalSince1970,
            "device": UIDevice.current.userInterfaceIdiom == .phone ? "phone" : "tablet",
            "os": UIDevice.current.systemVersion
        ]
        
        // Add properties
        for (key, value) in properties {
            event[key] = value
        }
        
        saveEvent(event)
        print("📊 Analytics: \(eventName) tracked")
    }
    
    // MARK: - Specific Tracking Methods
    func trackAuth(method: String) {
        trackEvent("auth", properties: ["method": method])
    }
    
    func trackProfileUpdate(experienceLevel: String, hasHandicap: Bool, hasHomeCourse: Bool, yearsPlayed: String) {
        trackEvent("profile_update", properties: [
            "experience": experienceLevel,
            "has_handicap": hasHandicap,
            "has_home_course": hasHomeCourse,
            "years_played": yearsPlayed
        ])
    }
    
    func trackAppUsage(screen: String) {
        trackEvent("screen_view", properties: ["screen": screen])
    }
    
    func trackSwingAnalysis(speedRange: String, userExperience: String) {
        trackEvent("swing_analysis", properties: [
            "speed_range": speedRange,
            "user_experience": userExperience
        ])
    }
    
    // MARK: - Data Storage
    private func saveEvent(_ event: [String: Any]) {
        var events = loadEvents()
        events.append(event)
        
        // Keep only last 500 events
        if events.count > 500 {
            events = Array(events.suffix(500))
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: events) {
            userDefaults.set(data, forKey: dataKey)
        }
    }
    
    private func loadEvents() -> [[String: Any]] {
        guard let data = userDefaults.data(forKey: dataKey),
              let events = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return events
    }
    
    // MARK: - Data Management
    func getEventCount() -> Int {
        return loadEvents().count
    }
    
    func clearAllData() {
        userDefaults.removeObject(forKey: dataKey)
        userDefaults.removeObject(forKey: sessionIdKey)
        ensureSessionId()
        print("📊 Analytics: All data cleared")
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        print("📊 Analytics: \(enabled ? "Enabled" : "Disabled")")
    }
    
    func exportData() -> String {
        let events = loadEvents()
        var output = "Golf Swing AI - Anonymous Analytics Export\n"
        output += "Generated: \(Date())\n"
        output += "Total Events: \(events.count)\n\n"
        
        for event in events {
            if let eventName = event["event"] as? String,
               let timestamp = event["timestamp"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: timestamp)
                output += "[\(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short))] \(eventName)\n"
            }
        }
        
        return output
    }
}

// MARK: - Helper Functions
extension SimpleAnalytics {
    func getHandicapRange(_ handicap: Double?) -> String {
        guard let handicap = handicap else { return "none" }
        
        switch handicap {
        case ..<0: return "plus"
        case 0..<10: return "0-10"
        case 10..<20: return "10-20"
        case 20..<30: return "20-30"
        default: return "30+"
        }
    }
    
    func getYearsRange(_ years: Int?) -> String {
        guard let years = years else { return "unknown" }
        
        switch years {
        case 0: return "new"
        case 1...3: return "1-3"
        case 4...10: return "4-10"
        default: return "10+"
        }
    }
    
    func getSpeedRange(_ speed: Double) -> String {
        switch speed {
        case ..<70: return "under-70"
        case 70..<90: return "70-90"
        case 90..<110: return "90-110"
        default: return "110+"
        }
    }
}