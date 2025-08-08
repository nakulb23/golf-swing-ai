import Foundation

// MARK: - User Authentication Models
struct User: Codable, Identifiable {
    let id: UUID
    var email: String
    var username: String
    var firstName: String
    var lastName: String
    var profileImageURL: String?
    var dateCreated: Date
    var lastLoginDate: Date?
    var handicap: Double?
    var preferredHand: GolfHand
    var experienceLevel: ExperienceLevel
    var homeCourse: String?
    var yearsPlayed: Int?
    var profile: UserProfile
    
    init(email: String, username: String, firstName: String, lastName: String, handicap: Double? = nil, preferredHand: GolfHand = .right, experienceLevel: ExperienceLevel = .beginner, homeCourse: String? = nil, yearsPlayed: Int? = nil) {
        self.id = UUID()
        self.email = email
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.dateCreated = Date()
        self.handicap = handicap
        self.preferredHand = preferredHand
        self.experienceLevel = experienceLevel
        self.homeCourse = homeCourse
        self.yearsPlayed = yearsPlayed
        self.profile = UserProfile()
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    var displayName: String {
        return username.isEmpty ? fullName : username
    }
}

enum GolfHand: String, CaseIterable, Codable {
    case left = "left"
    case right = "right"
    
    var displayName: String {
        switch self {
        case .left: return "Left-handed"
        case .right: return "Right-handed"
        }
    }
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case professional = "professional"
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .professional: return "Professional"
        }
    }
    
    var description: String {
        switch self {
        case .beginner: return "New to golf or less than 1 year"
        case .intermediate: return "1-5 years of playing experience"
        case .advanced: return "5+ years, consistent play"
        case .professional: return "Professional or semi-professional"
        }
    }
}

// MARK: - User Profile & Progress Tracking
struct UserProfile: Codable {
    var totalSwingsAnalyzed: Int = 0
    var totalVideosRecorded: Int = 0
    var averageSwingSpeed: Double = 0.0
    var bestSwingSpeed: Double = 0.0
    var totalPlayingSessions: Int = 0
    var favoriteClubs: [String] = []
    var goals: [UserGoal] = []
    var achievements: [Achievement] = []
    var swingHistory: [SwingAnalysisResult] = []
    var progressMetrics: ProgressMetrics = ProgressMetrics()
    
    mutating func recordSwingAnalysis(_ result: SwingAnalysisResult) {
        totalSwingsAnalyzed += 1
        swingHistory.append(result)
        
        // Update averages and bests
        if result.swingSpeed > bestSwingSpeed {
            bestSwingSpeed = result.swingSpeed
        }
        
        updateAverages()
    }
    
    private mutating func updateAverages() {
        if !swingHistory.isEmpty {
            averageSwingSpeed = swingHistory.reduce(0) { $0 + $1.swingSpeed } / Double(swingHistory.count)
        }
    }
}

struct UserGoal: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var targetValue: Double
    var currentValue: Double
    var unit: String
    var category: GoalCategory
    var deadline: Date?
    var isCompleted: Bool {
        return currentValue >= targetValue
    }
    var progress: Double {
        return min(currentValue / targetValue, 1.0)
    }
    
    init(title: String, description: String, targetValue: Double, currentValue: Double = 0.0, unit: String, category: GoalCategory, deadline: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.category = category
        self.deadline = deadline
    }
}

enum GoalCategory: String, CaseIterable, Codable {
    case swingSpeed = "swing_speed"
    case accuracy = "accuracy"
    case consistency = "consistency"
    case handicap = "handicap"
    case frequency = "frequency"
    
    var displayName: String {
        switch self {
        case .swingSpeed: return "Swing Speed"
        case .accuracy: return "Accuracy"
        case .consistency: return "Consistency"
        case .handicap: return "Handicap"
        case .frequency: return "Playing Frequency"
        }
    }
}

struct Achievement: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var iconName: String
    var dateEarned: Date
    var category: AchievementCategory
    
    init(title: String, description: String, iconName: String, dateEarned: Date = Date(), category: AchievementCategory) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.iconName = iconName
        self.dateEarned = dateEarned
        self.category = category
    }
}

enum AchievementCategory: String, CaseIterable, Codable {
    case milestone = "milestone"
    case improvement = "improvement"
    case consistency = "consistency"
    case speed = "speed"
    case accuracy = "accuracy"
}

struct ProgressMetrics: Codable {
    var weeklySwings: [Date: Int] = [:]
    var monthlyProgress: [String: Double] = [:]
    var swingSpeedTrend: [SwingSpeedData] = []
    var accuracyTrend: [AccuracyData] = []
    var consistencyScore: Double = 0.0
    var improvementRate: Double = 0.0
}

struct SwingSpeedData: Codable {
    let date: Date
    let speed: Double
    let club: String?
}

struct AccuracyData: Codable {
    let date: Date
    let accuracy: Double
    let targetType: String
}

// MARK: - Swing Analysis Results
struct SwingAnalysisResult: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let swingSpeed: Double
    let backswingAngle: Double
    let followThroughAngle: Double
    let clubFaceAngle: Double
    let swingPlane: SwingPlaneAnalysis
    let tempo: SwingTempo
    let balanceScore: Double
    let consistency: Double
    let recommendations: [String]
    let videoURL: String?
    let club: String?
    
    init(swingSpeed: Double, backswingAngle: Double, followThroughAngle: Double, clubFaceAngle: Double, swingPlane: SwingPlaneAnalysis, tempo: SwingTempo, balanceScore: Double, consistency: Double, recommendations: [String], videoURL: String? = nil, club: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.swingSpeed = swingSpeed
        self.backswingAngle = backswingAngle
        self.followThroughAngle = followThroughAngle
        self.clubFaceAngle = clubFaceAngle
        self.swingPlane = swingPlane
        self.tempo = tempo
        self.balanceScore = balanceScore
        self.consistency = consistency
        self.recommendations = recommendations
        self.videoURL = videoURL
        self.club = club
    }
}

struct SwingPlaneAnalysis: Codable {
    let angle: Double
    let isOnPlane: Bool
    let deviationDegrees: Double
}

struct SwingTempo: Codable {
    let backswingTime: Double
    let downswingTime: Double
    let ratio: Double
    let isIdeal: Bool
}

// MARK: - Authentication State
struct LoginCredentials {
    var email: String = ""
    var password: String = ""
}

struct RegistrationData {
    var email: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var username: String = ""
    var firstName: String = ""
    var lastName: String = ""
    var handicap: String = ""
    var preferredHand: GolfHand = .right
    var experienceLevel: ExperienceLevel = .beginner
    var agreedToTerms: Bool = false
}

enum AuthenticationError: Error, LocalizedError {
    case invalidEmail
    case passwordTooShort
    case passwordsDoNotMatch
    case emailAlreadyExists
    case invalidCredentials
    case networkError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .passwordTooShort:
            return "Password must be at least 8 characters long"
        case .passwordsDoNotMatch:
            return "Passwords do not match"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection error. Please try again."
        case .unknownError:
            return "An unexpected error occurred"
        }
    }
}