import Foundation

  // MARK: - Chat Models
  struct ChatRequest: Codable {
      let question: String
  }

  struct ChatResponse: Codable {
      let answer: String
      let is_golf_related: Bool
  }

  // MARK: - API Health
  struct HealthResponse: Codable {
      let status: String
      let model_loaded: Bool
  }

  // MARK: - Swing Analysis Models (Enhanced Multi-Angle)
  struct SwingAnalysisResponse: Codable {
      let predicted_label: String
      let confidence: Double
      let confidence_gap: Double
      let all_probabilities: [String: Double]
      
      // Enhanced multi-angle features
      let camera_angle: String?
      let angle_confidence: Double?
      let feature_reliability: [String: Double]?
      
      // Enhanced insights
      let physics_insights: String // Changed from PhysicsInsights object to string
      let angle_insights: String?
      let recommendations: [String]?
      
      // Status and compatibility
      let extraction_status: String
      let analysis_type: String?
      let model_version: String?
  }

  // Legacy physics insights structure (for backward compatibility)
  struct PhysicsInsights: Codable {
      let avg_plane_angle: Double
      let plane_analysis: String
  }

  // MARK: - Camera Angle Detection Models
  struct CameraAngleResponse: Codable {
      let camera_angle: String
      let confidence: Double
      let reliability_score: Double
      let guidance: CameraGuidance
      let detection_status: String
      let frames_analyzed: Int
  }

  struct CameraGuidance: Codable {
      let status: String
      let message: String
      let recommendations: [String]
  }

  // MARK: - Ball Tracking Models
  struct BallTrackingResponse: Codable {
      let detection_summary: DetectionSummary
      let flight_analysis: FlightAnalysis?
      let trajectory_data: TrajectoryData
      let visualization_created: Bool
  }

  struct DetectionSummary: Codable {
      let total_frames: Int
      let ball_detected_frames: Int
      let detection_rate: Double
      let trajectory_points: Int
  }

  struct FlightAnalysis: Codable {
      let launch_speed_ms: Double?
      let launch_angle_degrees: Double?
      let trajectory_type: String?
      let estimated_max_height: Double?
      let estimated_range: Double?
  }

  struct TrajectoryData: Codable {
      let flight_time: Double
      let has_valid_trajectory: Bool
  }
