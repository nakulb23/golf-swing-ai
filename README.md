# Golf Swing AI - Professional Swing Analysis Platform

A comprehensive golf instruction platform featuring **AI-powered swing analysis** and a **premium Physics Engine** that delivers professional-grade biomechanics analysis with real StoreKit integration.

## 🏌️ Key Features

### Core AI Analysis
- **Physics-Based Classification**: Uses 31 physics features including swing plane angles, body rotation, and biomechanics
- **High Accuracy**: 96.12% test accuracy with neural network model
- **Real-time Processing**: Fast video analysis with MediaPipe pose estimation
- **REST API**: Ready-to-deploy FastAPI web service

### 🔬 Physics Engine Premium Feature
- **Elite Benchmarks**: Compare against professional standards (113 mph club speed, 71% accuracy, 320 yard distance)
- **Real-time Camera Recording**: Full AVFoundation integration with permission handling
- **Comprehensive Analysis**: Detailed biomechanics analysis with improvement recommendations
- **StoreKit 2 Integration**: Monthly ($1.99) and Annual ($21.99) subscription plans
- **Transaction Monitoring**: Proper transaction updates listener to prevent missed purchases

### 📱 iOS App Features
- **SwiftUI Interface**: Modern, professional design with premium feel
- **Camera Permissions**: Proper permission request flow with Settings redirect
- **Video Management**: Record new swings or upload from camera roll
- **Elite Comparisons**: Real benchmarks instead of fake metrics
- **Development Mode**: Fallback for testing when StoreKit unavailable

## 🚀 Recent Updates (January 2025)

### StoreKit 2 Integration
- ✅ **Transaction Updates Listener**: Properly handles background purchases and prevents missed transactions
- ✅ **Real Purchase Flow**: Monthly ($1.99) and Annual ($21.99) subscription plans with test configuration
- ✅ **Development Fallback**: Automatic development mode when StoreKit testing unavailable
- ✅ **Error Handling**: Comprehensive error handling with user-friendly messaging

### Camera & Permissions
- 🎥 **Permission-First Design**: Requests camera permission before attempting to access camera
- 🎥 **Beautiful Permission UI**: Custom permission request screen with clear messaging
- 🎥 **Settings Integration**: Redirects users to Settings if permission denied
- 🎥 **Robust Session Management**: Proper AVFoundation session lifecycle handling

### Physics Engine Enhancement
- 📊 **Elite Benchmarks**: Replaced fake metrics with real professional standards
- 📊 **Meaningful Comparisons**: Elite vs User comparisons instead of arbitrary numbers
- 📊 **Analysis Required**: Clear indication that video analysis is needed for personalized data
- 📊 **Visual Improvements**: Enhanced UI with color-coded benchmark cards

### Technical Improvements
- 🔧 **Fixed Build Issues**: Resolved Transaction type ambiguity and XML syntax errors
- 🔧 **Enhanced Debugging**: Comprehensive logging for troubleshooting camera and StoreKit issues
- 🔧 **Performance Optimization**: Background thread handling for camera operations
- 🔧 **Code Quality**: Improved async/await patterns and error handling

## 📊 Model Performance

- **Test Accuracy**: 96.12%
- **Training Data**: 45 real samples + 600 synthetic physics-based samples
- **Features**: 31 golf-specific physics features
- **Classes**: on_plane (35-55°), too_steep (>55°), too_flat (<35°)

## 🚀 Quick Start

### Local Installation

```bash
# Install dependencies
pip install -r requirements.txt

# Test the model
python predict_physics_based.py

# Start API server
python api.py
```

### Docker Deployment

```bash
# Build image
docker build -t golf-swing-ai .

# Run container
docker run -p 8000:8000 golf-swing-ai
```

## 📡 API Usage

### Health Check
```bash
curl http://localhost:8000/health
```

### Predict Swing
```bash
curl -X POST "http://localhost:8000/predict" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@swing_video.mp4"
```

### Response Format
```json
{
  "predicted_label": "on_plane",
  "confidence": 0.988,
  "confidence_gap": 0.981,
  "all_probabilities": {
    "on_plane": 0.988,
    "too_flat": 0.007,
    "too_steep": 0.005
  },
  "physics_insights": {
    "avg_plane_angle": 45.2,
    "plane_analysis": "Swing plane is ON-PLANE (35-55° from vertical)"
  },
  "extraction_status": "Success"
}
```

## 🔬 Physics Features

The model analyzes 31 physics-based features:

### Swing Plane Analysis
- Average, max, min plane angles
- Plane angle consistency and deviation
- Plane tendency classification

### Body Rotation
- Shoulder and hip rotation ranges
- X-factor (shoulder-hip separation)
- Rotation sequence timing

### Arm/Club Path
- 3D swing path analysis
- Path smoothness and efficiency
- Swing arc dimensions

### Tempo & Balance
- Velocity and acceleration patterns
- Impact timing analysis
- Center of mass stability

## 🏗️ Architecture

```
├── api.py                     # FastAPI web service
├── predict_physics_based.py   # Main prediction script
├── physics_based_features.py  # Feature extraction engine
├── scripts/
│   └── extract_features_robust.py  # MediaPipe processing
├── models/
│   ├── physics_based_model.pt      # Neural network weights
│   ├── physics_scaler.pkl          # Feature scaler
│   └── physics_label_encoder.pkl   # Label encoder
├── requirements.txt           # Dependencies
└── Dockerfile                # Container config
```

## 📈 Model Details

- **Architecture**: 4-layer feedforward neural network
- **Input**: 31 physics-based features
- **Output**: 3-class probability distribution
- **Training**: Adam optimizer with L2 regularization
- **Validation**: Cross-validation with synthetic data augmentation

## 💰 Physics Engine Value Proposition

### Professional Analysis at Consumer Price
- **$1.50 vs $50-100**: Premium analysis at fraction of golf lesson cost
- **Immediate Access**: Professional-grade feedback in 3 seconds
- **Unlimited Analysis**: No per-session fees or subscription required
- **Progress Tracking**: Measurable improvement over time

### Technical Implementation
- **SwiftUI Premium Interface**: Professional design with score visualizations
- **StoreKit 2 Integration**: Seamless one-time purchase flow
- **Video Processing**: Real-time analysis with progress indicators
- **Comprehensive Feedback**: 4-tab interface (Issues, Strengths, Comparisons, Practice)

### User Experience
```
1. Select Video → 2. AI Analysis (3s) → 3. Professional Report → 4. Practice Plan
```

**[📋 Detailed Physics Engine Documentation](PHYSICS_ENGINE.md)**

## 🎯 Use Cases

### For Golfers
- **Personal Improvement**: Detailed swing analysis with actionable feedback
- **Progress Tracking**: Measure improvement with professional metrics
- **Cost-Effective Coaching**: Professional analysis without lesson costs

### For Developers
- **Golf Instruction Apps**: Integrate professional swing analysis
- **Performance Analytics**: Track swing improvements over time  
- **Premium Monetization**: Proven $1.50 price point with high value perception
- **Training Tools**: Provide real-time swing feedback

## 🔧 Development

### Adding New Features
1. Modify `physics_based_features.py` to extract new physics features
2. Retrain model with `physics_based_training.py`
3. Update API response format if needed

### Custom Deployment
- Modify `api.py` for custom endpoints
- Adjust `Dockerfile` for specific hosting requirements
- Scale with load balancers and multiple containers

## 📄 License

This project is for educational and commercial use. Please ensure compliance with MediaPipe and PyTorch licenses.

## 🤝 Support

For questions or issues, please refer to the original development documentation or contact the development team.
