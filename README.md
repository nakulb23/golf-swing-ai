# Golf Swing AI - Physics-Based Swing Plane Classification

A production-ready AI system that analyzes golf swing videos and classifies swing plane as "on_plane", "too_steep", or "too_flat" using physics-based features.

## 🏌️ Features

- **Physics-Based Analysis**: Uses 31 physics features including swing plane angles, body rotation, and biomechanics
- **High Accuracy**: 96.12% test accuracy with neural network model
- **Real-time Processing**: Fast video analysis with MediaPipe pose estimation
- **REST API**: Ready-to-deploy FastAPI web service
- **Docker Support**: Containerized deployment included

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

## 🎯 Use Cases

- **Golf Instruction**: Analyze student swing mechanics
- **Performance Analytics**: Track swing improvements over time  
- **Mobile Apps**: Integrate swing analysis into golf apps
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
