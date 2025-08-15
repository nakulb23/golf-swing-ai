import Foundation

// MARK: - Local Golf AI Models

/// Golf AI analysis result that includes all golf-specific data
struct LocalGolfAnalysisResult: Codable {
    let predicted_label: String
    let confidence: Double
    let swing_phases: [GolfSwingPhase]
    let biomechanics: GolfBiomechanicsData
    let club_analysis: GolfClubAnalysisData
    let recommendations: [GolfRecommendation]
    let overall_score: Double
    let analysis_type: String // Always "golf_ai_local"
    let model_version: String
    
    // Compatibility with existing SwingAnalysisResponse
    var asSwingAnalysisResponse: SwingAnalysisResponse {
        return SwingAnalysisResponse(
            predicted_label: predicted_label,
            confidence: confidence,
            confidence_gap: 0.8 - confidence,
            all_probabilities: generateProbabilities(),
            camera_angle: biomechanics.camera_angle,
            angle_confidence: Double(biomechanics.angle_confidence),
            feature_reliability: biomechanics.feature_reliability,
            club_face_analysis: club_analysis.club_face_analysis,
            club_speed_analysis: club_analysis.club_speed_analysis,
            premium_features_available: true, // Golf AI always provides premium features
            physics_insights: biomechanics.physics_summary,
            angle_insights: biomechanics.posture_insights,
            recommendations: recommendations.map { $0.description },
            extraction_status: "success",
            analysis_type: analysis_type,
            model_version: model_version,
            plane_angle: biomechanics.swing_plane_angle,
            tempo_ratio: biomechanics.tempo_ratio,
            shoulder_tilt: biomechanics.shoulder_rotation,
            video_duration_seconds: biomechanics.video_duration
        )
    }
    
    private func generateProbabilities() -> [String: Double] {
        var probs: [String: Double] = [:]
        probs[predicted_label] = confidence
        
        let otherLabels = ["perfect", "too_steep", "too_flat", "over_the_top", "inside_out"]
        let remainingProb = 1.0 - confidence
        let otherProb = remainingProb / Double(otherLabels.count - 1)
        
        for label in otherLabels where label != predicted_label {
            probs[label] = otherProb
        }
        
        return probs
    }
}

struct GolfSwingPhase: Codable {
    let phase: String // address, backswing, etc.
    let start_time: Double
    let end_time: Double
    let duration: Double
    let quality_score: Double
    let keypoints_detected: Int
}

struct GolfBiomechanicsData: Codable {
    let spine_angle: Double
    let hip_rotation: Double
    let shoulder_rotation: Double
    let weight_transfer: GolfWeightTransfer
    let posture_rating: String
    let tempo_ratio: Double
    let swing_plane_angle: Double
    let balance_score: Double
    
    // Analysis metadata
    let camera_angle: String
    let angle_confidence: Float
    let feature_reliability: [String: Double]
    let physics_summary: String
    let posture_insights: String
    let video_duration: Double
}

struct GolfWeightTransfer: Codable {
    let left_percentage: Double
    let right_percentage: Double
    let transfer_quality: String // "excellent", "good", "needs_work"
    let center_of_gravity_path: [GolfPoint]
}

struct GolfPoint: Codable {
    let x: Double
    let y: Double
    let timestamp: Double
}

struct GolfClubAnalysisData: Codable {
    let club_detected: Bool
    let club_type: String
    let shaft_angle_at_impact: Double
    let club_face_angle: Double
    let club_path: [GolfPoint]
    let grip_analysis: GolfGripAnalysis
    
    // Premium club analysis features
    let club_face_analysis: ClubFaceAnalysis?
    let club_speed_analysis: ClubSpeedAnalysis?
}

struct GolfGripAnalysis: Codable {
    let grip_strength: String // "weak", "neutral", "strong"
    let grip_position: String // "correct", "too_high", "too_low"
    let grip_consistency: Double
    let hand_separation: Double
}

struct GolfRecommendation: Codable {
    let category: String // "posture", "grip", "swing_plane", etc.
    let priority: Int // 1 = highest priority
    let title: String
    let description: String
    let drill_suggestion: String?
    
    var displayText: String {
        return "\(title): \(description)"
    }
}

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
      let minimal: Bool?
      let model_loaded: Bool?
      
      // Support both old and new server response formats
      init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          status = try container.decode(String.self, forKey: .status)
          minimal = try container.decodeIfPresent(Bool.self, forKey: .minimal)
          model_loaded = try container.decodeIfPresent(Bool.self, forKey: .model_loaded)
      }
      
      private enum CodingKeys: String, CodingKey {
          case status, minimal, model_loaded
      }
  }

  // MARK: - Swing Analysis Models (Enhanced Multi-Angle + Premium Features)
  struct SwingAnalysisResponse: Codable {
      let predicted_label: String
      let confidence: Double
      let confidence_gap: Double
      let all_probabilities: [String: Double]
      
      // Enhanced multi-angle features (optional for backward compatibility)
      let camera_angle: String?
      let angle_confidence: Double?
      let feature_reliability: [String: Double]?
      
      // New fields for enhanced UI
      let plane_angle: Double?
      let tempo_ratio: Double?
      let shoulder_tilt: Double?
      let video_duration_seconds: Double?
      
      // Quality validation fields (optional)
      let feature_dimension_ok: Bool?
      let quality_score: Double?
      
      // Detailed biomechanics analysis (optional)
      let detailed_biomechanics: [BiomechanicMeasurement]?
      let priority_flaws: [PriorityFlaw]?
      let pose_sequence: [PoseFrame]?
      let optimal_reference: [PoseFrame]?
      let comparison_data: ComparisonData?
      let has_detailed_analysis: Bool?
      
      // Premium Features - Club Face & Speed Analysis
      let club_face_analysis: ClubFaceAnalysis?
      let club_speed_analysis: ClubSpeedAnalysis?
      let premium_features_available: Bool?
      
      // Physics insights - support both old and new formats
      private let _physics_insights: PhysicsInsightsWrapper
      let angle_insights: String?
      let recommendations: [String]?
      
      // Status and compatibility
      let extraction_status: String
      let analysis_type: String?
      let model_version: String?
      
      // Computed property for backward compatibility
      var physics_insights: PhysicsInsights {
          switch _physics_insights {
          case .object(let insights):
              return insights
          case .string(let insightText):
              // Create a mock PhysicsInsights from string for backward compatibility
              return PhysicsInsights(
                  avg_plane_angle: extractPlaneAngleFromString(insightText),
                  plane_analysis: insightText
              )
          }
      }
      
      // Custom initializer for new format with premium features
      init(predicted_label: String, confidence: Double, confidence_gap: Double, 
           all_probabilities: [String: Double], camera_angle: String?, 
           angle_confidence: Double?, feature_reliability: [String: Double]?,
           club_face_analysis: ClubFaceAnalysis?, club_speed_analysis: ClubSpeedAnalysis?,
           premium_features_available: Bool?, physics_insights: String, angle_insights: String?, 
           recommendations: [String]?, extraction_status: String,
           analysis_type: String?, model_version: String?,
           plane_angle: Double? = nil, tempo_ratio: Double? = nil, 
           shoulder_tilt: Double? = nil, video_duration_seconds: Double? = nil) {
          self.predicted_label = predicted_label
          self.confidence = confidence
          self.confidence_gap = confidence_gap
          self.all_probabilities = all_probabilities
          self.camera_angle = camera_angle
          self.angle_confidence = angle_confidence
          self.feature_reliability = feature_reliability
          
          // New enhanced UI fields
          self.plane_angle = plane_angle
          self.tempo_ratio = tempo_ratio
          self.shoulder_tilt = shoulder_tilt
          self.video_duration_seconds = video_duration_seconds
          
          // Initialize optional detailed analysis fields
          self.feature_dimension_ok = nil
          self.quality_score = nil
          self.detailed_biomechanics = nil
          self.priority_flaws = nil
          self.pose_sequence = nil
          self.optimal_reference = nil
          self.comparison_data = nil
          self.has_detailed_analysis = false
          
          self.club_face_analysis = club_face_analysis
          self.club_speed_analysis = club_speed_analysis
          self.premium_features_available = premium_features_available
          self._physics_insights = .string(physics_insights)
          self.angle_insights = angle_insights
          self.recommendations = recommendations
          self.extraction_status = extraction_status
          self.analysis_type = analysis_type
          self.model_version = model_version
      }
      
      // Custom initializer for old format (backward compatibility)
      init(predicted_label: String, confidence: Double, confidence_gap: Double,
           all_probabilities: [String: Double], physics_insights: PhysicsInsights,
           extraction_status: String) {
          self.predicted_label = predicted_label
          self.confidence = confidence
          self.confidence_gap = confidence_gap
          self.all_probabilities = all_probabilities
          self.camera_angle = nil
          self.angle_confidence = nil
          self.feature_reliability = nil
          
          // New enhanced UI fields - defaults for backward compatibility
          self.plane_angle = nil
          self.tempo_ratio = nil
          self.shoulder_tilt = nil
          self.video_duration_seconds = nil
          
          // Initialize optional detailed analysis fields
          self.feature_dimension_ok = nil
          self.quality_score = nil
          self.detailed_biomechanics = nil
          self.priority_flaws = nil
          self.pose_sequence = nil
          self.optimal_reference = nil
          self.comparison_data = nil
          self.has_detailed_analysis = false
          
          self.club_face_analysis = nil
          self.club_speed_analysis = nil
          self.premium_features_available = false
          self._physics_insights = .object(physics_insights)
          self.angle_insights = nil
          self.recommendations = nil
          self.extraction_status = extraction_status
          self.analysis_type = "traditional"
          self.model_version = "1.0"
      }
      
      // Helper function to extract plane angle from insight string
      private func extractPlaneAngleFromString(_ text: String) -> Double {
          // Try to extract a number followed by degree symbol or "degrees"
          let patterns = [
              #"\b(\d+\.?\d*)\s*°"#,
              #"\b(\d+\.?\d*)\s*degrees?"#,
              #"angle.*?(\d+\.?\d*)"#
          ]
          
          for pattern in patterns {
              if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                  let range = NSRange(text.startIndex..<text.endIndex, in: text)
                  if let match = regex.firstMatch(in: text, range: range),
                     let angleRange = Range(match.range(at: 1), in: text) {
                      if let angle = Double(String(text[angleRange])) {
                          return angle
                      }
                  }
              }
          }
          
          // Default fallback based on prediction
          switch predicted_label {
          case "too_steep":
              return 62.0
          case "too_flat":
              return 28.0
          default:
              return 45.0
          }
      }
      
      // Custom coding keys
      enum CodingKeys: String, CodingKey {
          case predicted_label, confidence, confidence_gap, all_probabilities
          case camera_angle, angle_confidence, feature_reliability
          case feature_dimension_ok, quality_score
          case detailed_biomechanics, priority_flaws, pose_sequence, optimal_reference, comparison_data, has_detailed_analysis
          case club_face_analysis, club_speed_analysis, premium_features_available
          case _physics_insights = "physics_insights"
          case angle_insights, recommendations, extraction_status
          case analysis_type, model_version
          case plane_angle, tempo_ratio, shoulder_tilt, video_duration_seconds
      }
      
      // Custom decoder to handle both string and object formats
      init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          
          predicted_label = try container.decodeIfPresent(String.self, forKey: .predicted_label) ?? "unknown"
          confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.5
          confidence_gap = try container.decodeIfPresent(Double.self, forKey: .confidence_gap) ?? 0.0
          all_probabilities = try container.decodeIfPresent([String: Double].self, forKey: .all_probabilities) ?? [:]
          extraction_status = try container.decodeIfPresent(String.self, forKey: .extraction_status) ?? "success"
          
          // Optional new fields
          camera_angle = try container.decodeIfPresent(String.self, forKey: .camera_angle)
          angle_confidence = try container.decodeIfPresent(Double.self, forKey: .angle_confidence)
          feature_reliability = try container.decodeIfPresent([String: Double].self, forKey: .feature_reliability)
          
          // Enhanced UI fields
          plane_angle = try container.decodeIfPresent(Double.self, forKey: .plane_angle)
          tempo_ratio = try container.decodeIfPresent(Double.self, forKey: .tempo_ratio)
          shoulder_tilt = try container.decodeIfPresent(Double.self, forKey: .shoulder_tilt)
          video_duration_seconds = try container.decodeIfPresent(Double.self, forKey: .video_duration_seconds)
          
          // Quality validation fields
          feature_dimension_ok = try container.decodeIfPresent(Bool.self, forKey: .feature_dimension_ok)
          quality_score = try container.decodeIfPresent(Double.self, forKey: .quality_score)
          
          // Detailed biomechanics fields
          detailed_biomechanics = try container.decodeIfPresent([BiomechanicMeasurement].self, forKey: .detailed_biomechanics)
          priority_flaws = try container.decodeIfPresent([PriorityFlaw].self, forKey: .priority_flaws)
          pose_sequence = try container.decodeIfPresent([PoseFrame].self, forKey: .pose_sequence)
          optimal_reference = try container.decodeIfPresent([PoseFrame].self, forKey: .optimal_reference)
          comparison_data = try container.decodeIfPresent(ComparisonData.self, forKey: .comparison_data)
          has_detailed_analysis = try container.decodeIfPresent(Bool.self, forKey: .has_detailed_analysis) ?? false
          
          // Premium features
          club_face_analysis = try container.decodeIfPresent(ClubFaceAnalysis.self, forKey: .club_face_analysis)
          club_speed_analysis = try container.decodeIfPresent(ClubSpeedAnalysis.self, forKey: .club_speed_analysis)
          premium_features_available = try container.decodeIfPresent(Bool.self, forKey: .premium_features_available) ?? false
          
          angle_insights = try container.decodeIfPresent(String.self, forKey: .angle_insights)
          recommendations = try container.decodeIfPresent([String].self, forKey: .recommendations)
          analysis_type = try container.decodeIfPresent(String.self, forKey: .analysis_type)
          model_version = try container.decodeIfPresent(String.self, forKey: .model_version)
          
          // Handle physics_insights as either string or object
          if let insightString = try? container.decode(String.self, forKey: ._physics_insights) {
              _physics_insights = .string(insightString)
          } else if let insightObject = try? container.decode(PhysicsInsights.self, forKey: ._physics_insights) {
              _physics_insights = .object(insightObject)
          } else {
              // Fallback
              _physics_insights = .string("Analysis completed successfully")
          }
      }
      
      // Custom encoder
      func encode(to encoder: Encoder) throws {
          var container = encoder.container(keyedBy: CodingKeys.self)
          
          try container.encode(predicted_label, forKey: .predicted_label)
          try container.encode(confidence, forKey: .confidence)
          try container.encode(confidence_gap, forKey: .confidence_gap)
          try container.encode(all_probabilities, forKey: .all_probabilities)
          try container.encode(extraction_status, forKey: .extraction_status)
          
          try container.encodeIfPresent(camera_angle, forKey: .camera_angle)
          try container.encodeIfPresent(angle_confidence, forKey: .angle_confidence)
          try container.encodeIfPresent(feature_reliability, forKey: .feature_reliability)
          try container.encodeIfPresent(feature_dimension_ok, forKey: .feature_dimension_ok)
          try container.encodeIfPresent(quality_score, forKey: .quality_score)
          try container.encodeIfPresent(detailed_biomechanics, forKey: .detailed_biomechanics)
          try container.encodeIfPresent(priority_flaws, forKey: .priority_flaws)
          try container.encodeIfPresent(pose_sequence, forKey: .pose_sequence)
          try container.encodeIfPresent(optimal_reference, forKey: .optimal_reference)
          try container.encodeIfPresent(comparison_data, forKey: .comparison_data)
          try container.encodeIfPresent(has_detailed_analysis, forKey: .has_detailed_analysis)
          
          // Premium features
          try container.encodeIfPresent(club_face_analysis, forKey: .club_face_analysis)
          try container.encodeIfPresent(club_speed_analysis, forKey: .club_speed_analysis)
          try container.encodeIfPresent(premium_features_available, forKey: .premium_features_available)
          
          try container.encodeIfPresent(angle_insights, forKey: .angle_insights)
          try container.encodeIfPresent(recommendations, forKey: .recommendations)
          try container.encodeIfPresent(analysis_type, forKey: .analysis_type)
          try container.encodeIfPresent(model_version, forKey: .model_version)
          try container.encodeIfPresent(plane_angle, forKey: .plane_angle)
          try container.encodeIfPresent(tempo_ratio, forKey: .tempo_ratio)
          try container.encodeIfPresent(shoulder_tilt, forKey: .shoulder_tilt)
          try container.encodeIfPresent(video_duration_seconds, forKey: .video_duration_seconds)
          
          // Encode physics_insights based on internal format
          switch _physics_insights {
          case .string(let text):
              try container.encode(text, forKey: ._physics_insights)
          case .object(let insights):
              try container.encode(insights, forKey: ._physics_insights)
          }
      }
  }

  // Internal enum to handle both physics insights formats
  private enum PhysicsInsightsWrapper {
      case string(String)
      case object(PhysicsInsights)
  }

  // Legacy physics insights structure (for backward compatibility)
  struct PhysicsInsights: Codable {
      let avg_plane_angle: Double
      let plane_analysis: String
  }

  // MARK: - Premium Analysis Models
  struct ClubFaceAnalysis: Codable {
      let face_angle_at_impact: Double // degrees (-10 to +10, 0 = square)
      let face_angle_rating: String // "Square", "Slightly Open/Closed", "Very Open/Closed"
      let consistency_score: Double // 0-100, how consistent the face angle is
      let impact_position: ImpactPosition
      let recommendations: [String]
      let elite_benchmark: SwingEliteBenchmark
  }

  struct ClubSpeedAnalysis: Codable {
      let club_head_speed_mph: Double
      let speed_rating: String // "Below Average", "Average", "Above Average", "Tour Level"
      let acceleration_profile: AccelerationProfile
      let tempo_analysis: TempoAnalysis
      let efficiency_metrics: EfficiencyMetrics
      let distance_potential: DistancePotential
      let elite_benchmark: SwingEliteBenchmark
  }

  struct ImpactPosition: Codable {
      let toe_heel_impact: String // "Center", "Toe", "Heel"
      let high_low_impact: String // "Center", "High", "Low"
      let impact_quality_score: Double // 0-100
  }

  struct AccelerationProfile: Codable {
      let backswing_speed: Double // mph
      let transition_speed: Double // mph
      let impact_speed: Double // mph
      let deceleration_after_impact: Double // mph
      let acceleration_efficiency: Double // 0-100
  }

  struct TempoAnalysis: Codable {
      let backswing_time: Double // seconds
      let downswing_time: Double // seconds
      let tempo_ratio: Double // backswing:downswing (ideal 3:1)
      let tempo_rating: String // "Too Fast", "Good", "Too Slow"
      let pause_at_top: Double // seconds
  }

  struct EfficiencyMetrics: Codable {
      let swing_efficiency: Double // 0-100 (power transfer)
      let energy_loss_points: [String] // Areas where energy is lost
      let smash_factor: Double // ball speed / club speed (optimal 1.48-1.50)
      let centeredness_of_contact: Double // 0-100
  }

  struct DistancePotential: Codable {
      let current_estimated_distance: Double // yards
      let optimal_distance_potential: Double // yards with improvements
      let distance_gain_opportunities: [DistanceGainOpportunity]
  }

  struct DistanceGainOpportunity: Codable {
      let improvement_area: String
      let potential_yards_gained: Double
      let difficulty_level: String // "Easy", "Moderate", "Advanced"
      let practice_recommendation: String
  }

  struct SwingEliteBenchmark: Codable {
      let elite_average: Double
      let amateur_average: Double
      let your_percentile: Double // 0-100 (what percentile you're in)
      let comparison_text: String // "Your club head speed is 15% above amateur average"
  }

  // MARK: - Detailed Biomechanics Models

struct BiomechanicMeasurement: Codable {
    let name: String
    let current_value: Double
    let optimal_range: [Double] // [min, max]
    let unit: String
    let severity: String // "pass", "minor", "major", "critical"
    let description: String
    let frame_indices: [Int] // Frames where this issue occurs
}

struct PriorityFlaw: Codable {
    let priority: Int
    let flaw: String
    let result: String
    let severity: String
    let description: String
    let current_value: Double
    let optimal_range: [Double]
    let frame_indices: [Int]
}

struct PoseFrame: Codable {
    let frame: Int
    let landmarks: [String: PoseLandmark]
    let issues: [String]?
    let phase: String?
}

struct PoseLandmark: Codable {
    let x: Double
    let y: Double
    let confidence: Double
}

struct ComparisonData: Codable {
    let frame_comparisons: [FrameComparison]
    let deviation_summary: [String: Double]
    let improvement_areas: [String]
}

struct FrameComparison: Codable {
    let frame: Int
    let deviations: [String: LandmarkDeviation]
    let issues: [String]
}

struct LandmarkDeviation: Codable {
    let distance: Double
    let x_diff: Double
    let y_diff: Double
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

  // MARK: - Data Collection & Model Improvement Models
  struct DataCollectionConsent: Codable {
      let user_id: String // Anonymous UUID
      let consent_given: Bool
      let consent_date: String
      let data_types_consented: [String] // ["swing_videos", "analysis_results", "feedback"]
      let privacy_version: String // Track privacy policy version
  }

  struct AnonymousSwingData: Codable {
      let session_id: String // Anonymous session identifier
      let swing_features: [String: Double] // Physics features extracted
      let predicted_classification: String
      let confidence_score: Double
      let camera_angle: String?
      let user_feedback: UserFeedback?
      let timestamp: String
      let app_version: String
      let model_version: String
  }

  struct UserFeedback: Codable {
      let feedback_type: FeedbackType
      let user_rating: Int? // 1-5 stars for prediction accuracy
      let correction: String? // If user disagrees with classification
      let helpful: Bool? // Was the analysis helpful?
      let comments: String? // Optional user comments
  }

  enum FeedbackType: String, Codable, CaseIterable {
      case rating = "rating"
      case correction = "correction"
      case helpful = "helpful"
      case detailed = "detailed"
  }

  struct ModelImprovementResponse: Codable {
      let data_received: Bool
      let anonymous_id: String
      let contribution_count: Int
      let thank_you_message: String
      let privacy_confirmed: Bool
  }

  struct DataContributionStats: Codable {
      let total_contributions: Int
      let your_contributions: Int
      let model_accuracy_improvement: Double?
      let last_model_update: String?
      let community_impact: String
  }
