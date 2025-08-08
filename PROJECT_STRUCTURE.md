# Golf Swing AI - Organized Project Structure

*Updated on August 8, 2025*

## 📁 New Organized Structure

```
Golf Swing AI/
├── README.md                          # Project overview
├── run_api.py                         # Main API launcher script
├── PROJECT_STRUCTURE.md              # This file
│
├── backend/                           # Python Backend
│   ├── core/                         # Core prediction engines
│   │   ├── api.py                   # FastAPI main service
│   │   ├── predict_enhanced_lstm.py # Enhanced LSTM temporal analysis
│   │   ├── predict_multi_angle.py   # Multi-angle camera support
│   │   ├── predict_physics_based.py # Physics-based predictions
│   │   ├── physics_based_features.py # Feature extraction
│   │   ├── detailed_swing_analysis.py # Detailed biomechanics
│   │   ├── incremental_lstm_trainer.py # Incremental learning
│   │   └── view_invariant_features.py # Camera angle handling
│   │
│   ├── utils/                        # Utility modules
│   │   ├── ball_tracking.py         # Ball trajectory analysis
│   │   ├── camera_angle_detector.py # Camera detection
│   │   └── golf_chatbot.py          # Golf Q&A system
│   │
│   ├── scripts/                      # Supporting scripts
│   │   ├── extract_features_robust.py # Keypoint extraction
│   │   ├── demo_incremental_training.py # Training demo
│   │   └── organize_project.py      # Project organization
│   │
│   └── models/                       # AI Models & Data
│       ├── physics_based_model.pt   # Pre-trained physics model
│       ├── physics_scaler.pkl       # Feature scaler
│       ├── physics_label_encoder.pkl # Label encoder
│       ├── EnhancedSwingAnalysisModels.swift # Swift model definitions
│       ├── APIModels.swift          # API data models
│       ├── PhysicsCalculator.swift  # Physics calculations
│       └── VideoManager.swift       # Video handling
│
├── frontend/                         # Frontend Applications
│   ├── ios/                         # iOS App
│   │   ├── Golf Swing AI.xcodeproj/ # Xcode project
│   │   ├── Golf Swing AITests/      # Unit tests
│   │   ├── Golf Swing AIUITests/    # UI tests
│   │   ├── Golf-Swing-AI-Info.plist # App configuration
│   │   │
│   │   ├── Golf Swing AI/           # Main iOS source
│   │   │   ├── Golf_Swing_AIApp.swift # App entry point
│   │   │   ├── ContentView.swift    # Main UI
│   │   │   ├── AuthenticationManager.swift
│   │   │   ├── ThemeManager.swift
│   │   │   ├── Assets.xcassets/     # App assets
│   │   │   └── GoogleService-Info.plist
│   │   │
│   │   ├── Views/                   # SwiftUI Views
│   │   │   ├── SwingAnalysisView.swift # Main analysis UI
│   │   │   ├── PhysicsEngineView.swift # Physics engine UI
│   │   │   ├── HomeView.swift       # Home screen
│   │   │   ├── BallTrackingView.swift # Ball tracking UI
│   │   │   ├── CaddieChatView.swift # Chatbot UI
│   │   │   └── SwingFeedbackView.swift # Feedback display
│   │   │
│   │   ├── Services/                # iOS Services
│   │   │   ├── API Service.swift    # API communication
│   │   │   ├── CameraManager.swift  # Camera handling
│   │   │   ├── PremiumManager.swift # Premium features
│   │   │   └── DataCollectionManager.swift
│   │   │
│   │   ├── Models/                  # iOS Data Models
│   │   │   ├── APIModels.swift      # API response models
│   │   │   └── EnhancedSwingAnalysisModels.swift
│   │   │
│   │   └── Utilities/               # iOS Utilities
│   │       ├── ColorTheme.swift     # App theming
│   │       ├── Constants.swift      # App constants
│   │       └── Logger.swift         # Logging utilities
│   │
│   └── shared/                      # Shared frontend resources
│       └── (reserved for future web interface)
│
├── docs/                            # Documentation
│   ├── CHANGELOG.md                 # Version history
│   ├── CLEANUP_REPORT.md           # Cleanup summary
│   ├── DEPLOYMENT_OPTIMIZED.md     # Deployment guide
│   ├── PHYSICS_ENGINE.md           # Physics engine docs
│   ├── API_CONNECTION_GUIDE.md     # API integration
│   ├── SETUP_INSTRUCTIONS.md      # Setup guide
│   └── [other documentation files]
│
└── config/                         # Configuration Files
    ├── requirements.txt            # Python dependencies
    ├── runtime.txt                # Python version
    ├── Procfile                   # Deployment config
    └── Dockerfile                 # Container config
```

## 🚀 Key Benefits

### **Organized Structure**
- **Clear separation** of backend Python and frontend iOS code
- **Logical grouping** by functionality (core, utils, scripts, models)
- **Easy navigation** and maintenance

### **Enhanced Path Management**
- **Automatic path resolution** using `run_api.py` launcher
- **Cross-platform compatibility** with proper path handling
- **Import optimization** with structured module loading

### **Better Development Experience**
- **Faster builds** with organized file structure
- **Easier debugging** with clear module boundaries
- **Scalable architecture** for future enhancements

## 🛠️ Usage

### **Starting the API Server**
```bash
# From project root
python run_api.py

# Or directly
cd backend/core && python api.py
```

### **iOS Development**
```bash
# Open Xcode project
open "frontend/ios/Golf Swing AI.xcodeproj"
```

### **Model Training**
```python
# Use the incremental training system
from backend.core.incremental_lstm_trainer import get_trainer
trainer = get_trainer()
trainer.add_training_sample(video_path, true_label)
```

## 📊 Migration Status

✅ **Completed:**
- Backend Python files organized
- Model paths updated
- Import references fixed
- API launcher created
- Documentation updated

⚠️ **Requires Manual Update:**
- Xcode project file references (frontend/ios/*.xcodeproj)
- Any deployment scripts using old paths
- External integrations pointing to old structure

## 🎯 Next Steps

1. **Update Xcode project** to reference new file locations
2. **Test API functionality** with new structure
3. **Update deployment scripts** if any
4. **Commit organized structure** to git

---
*The organized structure maintains all functionality while providing better maintainability and development experience.*