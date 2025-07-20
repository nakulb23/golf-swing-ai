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
      
      // Enhanced multi-angle features (optional for backward compatibility)
      let camera_angle: String?
      let angle_confidence: Double?
      let feature_reliability: [String: Double]?
      
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
      
      // Custom initializer for new format
      init(predicted_label: String, confidence: Double, confidence_gap: Double, 
           all_probabilities: [String: Double], camera_angle: String?, 
           angle_confidence: Double?, feature_reliability: [String: Double]?,
           physics_insights: String, angle_insights: String?, 
           recommendations: [String]?, extraction_status: String,
           analysis_type: String?, model_version: String?) {
          self.predicted_label = predicted_label
          self.confidence = confidence
          self.confidence_gap = confidence_gap
          self.all_probabilities = all_probabilities
          self.camera_angle = camera_angle
          self.angle_confidence = angle_confidence
          self.feature_reliability = feature_reliability
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
          case _physics_insights = "physics_insights"
          case angle_insights, recommendations, extraction_status
          case analysis_type, model_version
      }
      
      // Custom decoder to handle both string and object formats
      init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          
          predicted_label = try container.decode(String.self, forKey: .predicted_label)
          confidence = try container.decode(Double.self, forKey: .confidence)
          confidence_gap = try container.decode(Double.self, forKey: .confidence_gap)
          all_probabilities = try container.decode([String: Double].self, forKey: .all_probabilities)
          extraction_status = try container.decode(String.self, forKey: .extraction_status)
          
          // Optional new fields
          camera_angle = try container.decodeIfPresent(String.self, forKey: .camera_angle)
          angle_confidence = try container.decodeIfPresent(Double.self, forKey: .angle_confidence)
          feature_reliability = try container.decodeIfPresent([String: Double].self, forKey: .feature_reliability)
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
          try container.encodeIfPresent(angle_insights, forKey: .angle_insights)
          try container.encodeIfPresent(recommendations, forKey: .recommendations)
          try container.encodeIfPresent(analysis_type, forKey: .analysis_type)
          try container.encodeIfPresent(model_version, forKey: .model_version)
          
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
