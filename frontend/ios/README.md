# Golf Swing AI - iOS App

[![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![iOS Version](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![Xcode Version](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

Professional golf swing analysis using advanced AI and computer vision on iOS devices.

## 🏌️ Features

### Core Analysis
- **Real-time Swing Analysis**: MediaPipe pose detection + 35 biomechanical features
- **Local AI Processing**: Core ML models for offline analysis
- **Interactive Video Playback**: Frame-by-frame swing breakdown with overlays
- **Physics-based Insights**: Swing plane, tempo, rotation analysis
- **Performance Tracking**: Historical analysis and progress monitoring

### AI Model Improvement
- **Centralized Learning**: All user data improves AI for everyone
- **User Feedback Collection**: Correct AI predictions to enhance accuracy
- **Automatic Model Updates**: Enhanced models delivered via app updates
- **Privacy-First Design**: Anonymous data collection with full user control

### Advanced Features
- **CaddieChat Pro**: Local AI golf expert for rules and strategy
- **Multi-angle Analysis**: Support for different camera positions
- **Premium Physics Engine**: Advanced biomechanical analysis
- **Offline Capability**: Full functionality without internet

## 🚀 Quick Start

### Prerequisites
- iOS 17.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Installation
1. Clone the repository:
```bash
git clone https://github.com/yourusername/golf-swing-ai-ios.git
cd golf-swing-ai-ios
```

2. Install dependencies:
```bash
# Core ML models will be downloaded on first build
open "Golf Swing AI.xcodeproj"
```

3. Build and run:
- Select target device/simulator
- Build (⌘+B) and Run (⌘+R)

## 🧠 AI Architecture

### Local Processing Pipeline
```
Video Input → MediaPipe Pose Detection → 35 Physics Features → Core ML Model → Prediction
```

### Core ML Models
- **SwingAnalysisModel.mlmodel**: Primary swing classification
- **PoseDetectionModel.mlmodel**: Human pose estimation enhancement
- **BallTrackingModel.mlmodel**: Golf ball trajectory analysis

### Feature Extraction (35 Features)
```swift
// Biomechanical Features Extracted:
1. spine_angle, 2. knee_flexion, 3. weight_distribution
4. arm_hang_angle, 5. stance_width, 6. max_shoulder_turn
7. hip_turn_at_top, 8. x_factor, 9. swing_plane_angle
10. arm_extension, 11. weight_shift, 12. wrist_hinge
// ... (see ModelFeatureExtractor.swift for complete list)
```

## 📊 Centralized Model Improvement

### Data Collection System
The app collects anonymous swing data to continuously improve AI models for all users.

#### What Data is Collected
```json
{
  "id": "uuid",
  "timestamp": "2024-01-15T10:30:00Z",
  "features": [35 physics values], // Real biomechanical data
  "modelPrediction": "good_swing", // AI classification
  "modelConfidence": 0.87,         // Confidence score
  "userFeedback": {                // Optional corrections
    "isCorrect": false,
    "correctedLabel": "too_steep",
    "confidence": 4,
    "comments": "backswing too vertical"
  },
  "swingMetadata": {
    "deviceModel": "iPhone 15 Pro",
    "appVersion": "1.0.0",
    "analysisDate": "2024-01-15T10:30:00Z",
    "userSkillLevel": "intermediate", // Optional
    "clubType": "driver",             // Optional
    "practiceOrRound": "practice"     // Optional
  },
  "isFromLocalModel": true,
  "modelVersion": "1.0-local"
}
```

#### Collection Points
1. **Every Swing Analysis**: Automatic collection of all predictions
2. **User Feedback**: When users correct AI predictions
3. **Confidence Validation**: High/low confidence prediction tracking

### Server Integration

#### API Endpoints Required
```swift
// Upload training data
POST /api/model/training-data
Content-Type: application/json
Body: ModelTrainingDataPoint (see above)

Response: {
  "success": true,
  "message": "Data received successfully",
  "dataPointId": "uuid"
}

// Check for model updates
GET /api/model/updates
Response: {
  "hasUpdate": true,
  "modelVersion": "1.2.0",
  "downloadURL": "https://api.../models/v1.2.0.mlmodel",
  "releaseNotes": "Improved accuracy for steep swings",
  "isRequired": false
}

// Download model update
GET /api/model/download/{version}
Response: Binary .mlmodel file
```

## 🏗️ Project Structure

```
Golf Swing AI/
├── Services/
│   ├── APIService.swift                      # Server communication
│   ├── LocalAIManager.swift                  # Core ML management
│   ├── CentralizedModelImprovement.swift     # Data collection system
│   ├── ModelFeedbackCollector.swift          # Local feedback storage
│   └── ModelRetrainingPipeline.swift         # Local retraining
├── Views/
│   ├── SwingAnalysisView.swift               # Main analysis interface
│   ├── VideoFirstAnalysisView.swift          # Video playback + results
│   ├── CaddieChatView.swift                  # AI golf expert chat
│   ├── FeedbackPromptView.swift              # User correction UI
│   └── CentralizedModelImprovementView.swift # Data sharing settings
├── Models/
│   ├── SwingAnalysisModel.mlmodel            # Core swing classifier
│   └── SwingAnalysisMLModel.swift            # Model wrapper classes
├── Utilities/
│   ├── SwingPhysicsCalculator.swift          # Biomechanical analysis
│   ├── MediaPipePoseDetector.swift           # Pose detection wrapper
│   └── Constants.swift                       # API endpoints & config
└── Documentation/
    ├── LOCAL_ONLY_CHANGES.md                 # Local AI implementation
    ├── CENTRALIZED_MODEL_IMPROVEMENT.md      # Data collection system
    └── API_INTEGRATION_GUIDE.md              # Server integration guide
```

## 🔧 Configuration

### API Configuration
Update `Constants.swift`:
```swift
struct Constants {
    static let baseURL = "https://your-api-server.com"
    static let appVersion = "1.0.0"
}
```

### Core ML Models
Place models in app bundle:
- `SwingAnalysisModel.mlmodel` - Primary classifier
- `BallTrackingModel.mlmodel` - Ball detection (optional)

### Privacy Settings
Configure data collection in app:
- Settings → AI Model Improvement
- Granular controls for data sharing
- Complete privacy transparency

## 📱 App Architecture

### Core Components

#### 1. Swing Analysis Pipeline
```swift
// Main analysis flow
VideoInput → PoseDetection → FeatureExtraction → MLInference → Results

// File: LocalAIManager.swift:173-194
func analyzeSwing(from videoURL: URL) async throws -> SwingAnalysisResponse
```

#### 2. Data Collection System
```swift
// Centralized collection (all predictions)
CentralizedModelImprovement.shared.collectPredictionData(...)

// Local collection (uncertain predictions)
ModelFeedbackCollector.shared.collectUncertainPrediction(...)
```

#### 3. User Feedback Loop
```swift
// Feedback prompt triggers
if confidence < 0.8 || (confidence < 0.9 && Bool.random()) {
    showFeedbackPrompt = true
}

// Collection with real features
features = localAnalyzer.getCurrentPredictionForFeedback()?.features ?? []
```

## 🧪 Testing

### Unit Tests
```bash
# Run all tests
xcodebuild test -scheme "Golf Swing AI" -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Integration Tests
- Core ML model loading
- API communication
- Data collection pipeline
- Privacy compliance

## 🚀 Deployment

### App Store Build
1. Update version in `Info.plist`
2. Archive build (⌘+Shift+B)
3. Upload to App Store Connect
4. Submit for review

### Model Updates
1. Train improved models server-side
2. Package as `.mlmodel` files
3. Upload to model distribution endpoint
4. App checks for updates automatically

## 📊 Server Training Guide

### Data Processing Pipeline
```python
# Server-side processing for incoming data
def process_training_data(data_point):
    features = data_point['features']        # 35-element array
    prediction = data_point['modelPrediction'] # string classification
    confidence = data_point['modelConfidence'] # float 0-1
    feedback = data_point['userFeedback']     # optional corrections
    
    # Store for batch training
    store_training_sample(features, get_ground_truth_label(prediction, feedback))

def get_ground_truth_label(prediction, feedback):
    if feedback and not feedback['isCorrect']:
        return feedback['correctedLabel']  # Use user correction
    return prediction  # Use AI prediction if user confirmed correct
```

### Model Retraining
```python
# Batch retraining with collected data
def retrain_model():
    # Load all training samples
    samples = load_training_samples()
    
    # Prepare training data
    X = [sample['features'] for sample in samples]  # 35 features each
    y = [sample['label'] for sample in samples]     # classifications
    
    # Train improved model
    model = MLClassifier(training_data={'features': X, 'target': y})
    
    # Validate improvement
    accuracy = validate_model(model)
    
    # Deploy if better
    if accuracy > current_model_accuracy:
        deploy_model_update(model)
```

## 🔐 Privacy & Security

### Data Protection
- ✅ Anonymous data collection only
- ✅ No personal identifiers stored
- ✅ User consent required for all sharing
- ✅ Granular privacy controls
- ✅ Right to opt-out anytime

### Security Measures
- HTTPS-only API communication
- Certificate pinning for production
- Secure local data storage
- Privacy-first architecture

## 📈 Analytics

### Collection Metrics
- Total predictions collected: Real-time counter
- User feedback rate: Percentage providing corrections
- Model confidence distribution: Accuracy insights
- Device compatibility: iOS version support

### Performance Monitoring
- Analysis speed (target: <2 seconds)
- Model accuracy (target: >90%)
- User engagement (feedback participation)
- Server sync success rate

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/improvement`)
3. Commit changes (`git commit -m 'Add improvement'`)
4. Push to branch (`git push origin feature/improvement`)
5. Create Pull Request

### Development Guidelines
- Follow Swift style guide
- Add unit tests for new features
- Update documentation
- Ensure privacy compliance

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- 📧 Email: support@golfswingai.com
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/golf-swing-ai-ios/issues)
- 📚 Wiki: [Documentation Wiki](https://github.com/yourusername/golf-swing-ai-ios/wiki)

## 🔄 Changelog

### v1.0.0 (Latest)
- ✅ Complete local AI implementation
- ✅ Centralized model improvement system
- ✅ User feedback collection
- ✅ Privacy-first data sharing
- ✅ Automatic model updates
- ✅ CaddieChat Pro integration
- ✅ Interactive video analysis

---

**Built with ❤️ for golfers who want to improve their game through AI-powered analysis.**