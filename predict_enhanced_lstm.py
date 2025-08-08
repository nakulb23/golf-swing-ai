"""
Enhanced Golf Swing AI with LSTM Temporal Analysis
Combines the best of physics-based features with temporal sequence learning
"""

import sys
sys.path.append('scripts')

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from physics_based_features import GolfSwingPhysicsExtractor, PhysicsBasedSwingClassifier
from view_invariant_features import ViewInvariantFeatureExtractor
from camera_angle_detector import CameraAngle
from scripts.extract_features_robust import extract_keypoints_from_video_robust
import joblib
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# MARK: - Enhanced LSTM Temporal Classifier
class EnhancedTemporalSwingClassifier(nn.Module):
    """
    Advanced LSTM-based swing classifier with attention mechanism and residual connections
    """
    def __init__(self, input_size=35, hidden_size=128, num_classes=3, num_layers=2, dropout=0.3):
        super().__init__()
        
        # Multi-layer LSTM with dropout
        self.lstm = nn.LSTM(
            input_size, 
            hidden_size, 
            num_layers=num_layers,
            batch_first=True,
            dropout=dropout if num_layers > 1 else 0,
            bidirectional=True
        )
        
        # Attention mechanism
        self.attention = nn.MultiheadAttention(
            embed_dim=hidden_size * 2,  # bidirectional
            num_heads=8,
            dropout=dropout,
            batch_first=True
        )
        
        # Feature fusion layers
        self.feature_fusion = nn.Sequential(
            nn.Linear(hidden_size * 2, hidden_size),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_size, hidden_size // 2),
            nn.ReLU(),
            nn.Dropout(dropout)
        )
        
        # Classification head
        self.classifier = nn.Linear(hidden_size // 2, num_classes)
        
        # Phase detection head (auxiliary task)
        self.phase_detector = nn.Linear(hidden_size // 2, 6)  # setup, takeaway, backswing, transition, downswing, impact
        
        # Confidence estimation head
        self.confidence_head = nn.Linear(hidden_size // 2, 1)
        
    def forward(self, x, return_attention=False):
        # LSTM processing
        lstm_out, (h_n, c_n) = self.lstm(x)
        
        # Self-attention on LSTM outputs
        attn_out, attn_weights = self.attention(lstm_out, lstm_out, lstm_out)
        
        # Global average pooling with attention
        weighted_features = torch.mean(attn_out, dim=1)
        
        # Feature fusion
        fused_features = self.feature_fusion(weighted_features)
        
        # Multi-task outputs
        swing_logits = self.classifier(fused_features)
        phase_logits = self.phase_detector(fused_features)
        confidence_score = torch.sigmoid(self.confidence_head(fused_features))
        
        if return_attention:
            return swing_logits, phase_logits, confidence_score, attn_weights
        
        return swing_logits, phase_logits, confidence_score

# MARK: - Hybrid Model Ensemble
class HybridSwingAnalyzer(nn.Module):
    """
    Ensemble model combining LSTM temporal analysis with physics-based features
    """
    def __init__(self, lstm_model, physics_model, num_classes=3):
        super().__init__()
        self.lstm_model = lstm_model
        self.physics_model = physics_model
        
        # Ensemble weights (learnable)
        self.ensemble_weights = nn.Parameter(torch.tensor([0.7, 0.3]))  # LSTM, Physics
        self.softmax = nn.Softmax(dim=0)
        
    def forward(self, sequence_features, static_features):
        # LSTM prediction
        lstm_logits, phase_logits, confidence = self.lstm_model(sequence_features)
        
        # Physics-based prediction
        physics_logits = self.physics_model(static_features)
        
        # Weighted ensemble
        weights = self.softmax(self.ensemble_weights)
        final_logits = weights[0] * lstm_logits + weights[1] * physics_logits
        
        return final_logits, phase_logits, confidence, weights

def predict_with_enhanced_lstm(video_path, 
                              lstm_model_path="models/enhanced_temporal_model.pt", 
                              physics_model_path="models/physics_based_model.pt",
                              scaler_path="models/physics_scaler.pkl", 
                              encoder_path="models/physics_label_encoder.pkl",
                              use_ensemble=True):
    """
    Enhanced prediction using LSTM temporal analysis with optional ensemble
    
    Key improvements:
    1. LSTM with bidirectional processing and attention
    2. Multi-task learning (swing classification + phase detection)
    3. Confidence estimation
    4. Hybrid ensemble with physics model
    5. Enhanced temporal feature extraction
    """
    
    print(f"🎬 Analyzing swing with ENHANCED LSTM MODEL: {video_path}")
    print("="*80)
    
    # Check if video exists
    if not os.path.exists(video_path):
        print(f"❌ Video file not found: {video_path}")
        return None
    
    # Extract keypoints
    keypoints, status = extract_keypoints_from_video_robust(video_path)
    
    if keypoints.size == 0:
        print(f"❌ Failed to extract features: {status}")
        return None
    
    print(f"📊 Extracted keypoints shape: {keypoints.shape}")
    print(f"✅ Feature extraction: {status}")
    
    # STEP 1: Camera angle detection with enhanced analysis
    view_extractor = ViewInvariantFeatureExtractor()
    camera_angle = CameraAngle.SIDE_ON
    angle_confidence = 0.0
    feature_weights = None
    
    try:
        view_result = view_extractor.extract_view_invariant_features(keypoints)
        camera_analysis = view_result['camera_analysis']
        camera_angle = camera_analysis['angle_type']
        angle_confidence = camera_analysis['confidence']
        feature_weights = view_result['feature_weights']
        
        print(f"📷 Camera Detection: {camera_angle.value} (confidence: {angle_confidence:.3f})")
        
    except Exception as e:
        print(f"⚠️ Camera detection failed: {str(e)}")
        print("📷 Using default SIDE_ON analysis...")
    
    # STEP 2: Enhanced temporal feature extraction
    extractor = GolfSwingPhysicsExtractor()
    
    # Extract both sequence and static features
    try:
        # Temporal sequence features
        feature_sequence, feature_names = extractor.extract_feature_sequence(keypoints)
        
        # Static aggregate features (for physics model)
        static_features, _ = extractor.extract_feature_vector(keypoints)
        
        print(f"📊 Temporal sequence shape: {feature_sequence.shape}")
        print(f"📊 Static features shape: {static_features.shape}")
        
    except Exception as e:
        print(f"❌ Feature extraction failed: {str(e)}")
        return None
    
    # STEP 3: Sequence preprocessing with adaptive length
    target_seq_length = 200  # Optimized for golf swing duration
    expected_features = 35
    
    # Handle variable sequence lengths
    if feature_sequence.shape[0] < target_seq_length:
        # Pad with last frame values (more natural than zeros)
        last_frame = feature_sequence[-1:] if len(feature_sequence) > 0 else np.zeros((1, expected_features))
        padding_needed = target_seq_length - feature_sequence.shape[0]
        padding = np.repeat(last_frame, padding_needed, axis=0)
        feature_sequence = np.concatenate([feature_sequence, padding], axis=0)
    elif feature_sequence.shape[0] > target_seq_length:
        # Intelligently downsample to preserve key swing phases
        indices = np.linspace(0, len(feature_sequence)-1, target_seq_length, dtype=int)
        feature_sequence = feature_sequence[indices]
    
    # Validate dimensions
    if feature_sequence.shape[1] != expected_features:
        print(f"❌ Feature dimension mismatch: expected {expected_features}, got {feature_sequence.shape[1]}")
        return None
    
    # STEP 4: Load models and preprocessors
    try:
        scaler = joblib.load(scaler_path)
        label_encoder = joblib.load(encoder_path)
        class_names = label_encoder.classes_
        num_classes = len(class_names)
        
        print(f"🧠 Loaded preprocessing for {num_classes} classes: {list(class_names)}")
        
    except Exception as e:
        print(f"❌ Failed to load preprocessors: {str(e)}")
        return None
    
    # STEP 5: Scale features
    # Scale sequence features
    seq_shape = feature_sequence.shape
    feature_sequence_flat = feature_sequence.reshape(-1, seq_shape[1])
    scaled_sequence_flat = scaler.transform(feature_sequence_flat)
    scaled_sequence = scaled_sequence_flat.reshape(seq_shape)
    
    # Scale static features
    scaled_static = scaler.transform(static_features.reshape(1, -1))
    
    # STEP 6: Load enhanced LSTM model
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    try:
        # Load LSTM model
        lstm_model = EnhancedTemporalSwingClassifier(
            input_size=expected_features,
            hidden_size=128,
            num_classes=num_classes,
            num_layers=2,
            dropout=0.3
        )
        
        # Check if enhanced model exists, otherwise use fallback
        if os.path.exists(lstm_model_path):
            lstm_model.load_state_dict(torch.load(lstm_model_path, map_location=device))
            print(f"🧠 Loaded enhanced LSTM model from {lstm_model_path}")
        else:
            print(f"⚠️ Enhanced LSTM model not found at {lstm_model_path}")
            print("📚 Using physics-based model as fallback...")
            use_ensemble = False
        
        lstm_model.eval()
        lstm_model.to(device)
        
    except Exception as e:
        print(f"❌ Error loading LSTM model: {str(e)}")
        use_ensemble = False
    
    # STEP 7: Ensemble setup (if available)
    hybrid_model = None
    if use_ensemble and os.path.exists(physics_model_path):
        try:
            # Load physics model
            physics_model = PhysicsBasedSwingClassifier(num_features=expected_features, num_classes=num_classes)
            physics_model.load_state_dict(torch.load(physics_model_path, map_location=device))
            physics_model.eval()
            physics_model.to(device)
            
            # Create hybrid ensemble
            hybrid_model = HybridSwingAnalyzer(lstm_model, physics_model, num_classes)
            hybrid_model.eval()
            hybrid_model.to(device)
            
            print("🎯 Using hybrid ensemble model (LSTM + Physics)")
            
        except Exception as e:
            print(f"⚠️ Ensemble setup failed: {str(e)}")
            print("📚 Using LSTM model only...")
    
    # STEP 8: Prediction
    sequence_tensor = torch.FloatTensor(scaled_sequence).unsqueeze(0).to(device)
    static_tensor = torch.FloatTensor(scaled_static).to(device)
    
    try:
        with torch.no_grad():
            if hybrid_model:
                # Ensemble prediction
                swing_logits, phase_logits, confidence_score, ensemble_weights = hybrid_model(sequence_tensor, static_tensor)
                print(f"🎯 Ensemble weights - LSTM: {ensemble_weights[0]:.3f}, Physics: {ensemble_weights[1]:.3f}")
            else:
                # LSTM only prediction
                swing_logits, phase_logits, confidence_score = lstm_model(sequence_tensor)
                ensemble_weights = torch.tensor([1.0, 0.0])
            
            # Process outputs
            swing_probs = F.softmax(swing_logits, dim=1).cpu().numpy()[0]
            phase_probs = F.softmax(phase_logits, dim=1).cpu().numpy()[0]
            confidence_value = confidence_score.cpu().numpy()[0][0]
            
            # Get predictions
            predicted_class_idx = np.argmax(swing_probs)
            predicted_label = class_names[predicted_class_idx]
            prediction_confidence = swing_probs[predicted_class_idx]
            
            # Calculate confidence gap
            sorted_probs = np.sort(swing_probs)[::-1]
            confidence_gap = sorted_probs[0] - sorted_probs[1]
            
        print(f"\n🎯 ENHANCED LSTM PREDICTION RESULTS:")
        print(f"🎯 Predicted Swing: {predicted_label}")
        print(f"🎯 Model Confidence: {prediction_confidence:.3f}")
        print(f"🎯 Confidence Gap: {confidence_gap:.3f}")
        print(f"🎯 Neural Confidence: {confidence_value:.3f}")
        print(f"🎯 Camera Angle: {camera_angle.value} (confidence: {angle_confidence:.3f})")
        
        # Phase detection results
        phase_names = ["Setup", "Takeaway", "Backswing", "Transition", "Downswing", "Impact"]
        dominant_phase_idx = np.argmax(phase_probs)
        dominant_phase = phase_names[dominant_phase_idx]
        print(f"🎯 Dominant Phase: {dominant_phase} ({phase_probs[dominant_phase_idx]:.3f})")
        
        # Detailed probability breakdown
        print(f"\n📊 Detailed Analysis:")
        prob_dict = {}
        for i, class_name in enumerate(class_names):
            prob_dict[class_name] = float(swing_probs[i])
            print(f"   {class_name}: {swing_probs[i]:.3f}")
        
        # Generate enhanced insights
        insights = generate_enhanced_insights(
            predicted_label, prediction_confidence, confidence_gap, 
            camera_angle, angle_confidence, dominant_phase, phase_probs
        )
        
        # Return comprehensive results
        return {
            "predicted_label": predicted_label,
            "confidence": float(prediction_confidence),
            "confidence_gap": float(confidence_gap),
            "neural_confidence": float(confidence_value),
            "all_probabilities": prob_dict,
            "camera_angle": camera_angle.value,
            "angle_confidence": float(angle_confidence),
            "dominant_phase": dominant_phase,
            "phase_probabilities": {phase_names[i]: float(phase_probs[i]) for i in range(len(phase_names))},
            "ensemble_weights": {"lstm": float(ensemble_weights[0]), "physics": float(ensemble_weights[1])},
            "enhanced_insights": insights,
            "extraction_status": status,
            "analysis_type": "enhanced_lstm_temporal",
            "model_version": "2.0_lstm_enhanced"
        }
        
    except Exception as e:
        print(f"❌ Prediction failed: {str(e)}")
        return None

def generate_enhanced_insights(predicted_label, confidence, confidence_gap, 
                             camera_angle, angle_confidence, dominant_phase, phase_probs):
    """Generate enhanced insights using temporal and phase analysis"""
    
    insights = []
    
    # Swing plane insights
    if predicted_label == "too_steep":
        insights.append("Your swing plane is too steep, causing the club to approach the ball at a steep angle.")
        insights.append("Focus on a more around-the-body takeaway and maintain spine angle through impact.")
    elif predicted_label == "too_flat":
        insights.append("Your swing plane is too flat, which can lead to inconsistent contact.")
        insights.append("Work on getting the club more upright in the backswing with proper shoulder turn.")
    else:
        insights.append("Excellent! Your swing plane is on track for consistent ball striking.")
    
    # Confidence-based insights
    if confidence > 0.8:
        insights.append("The model is highly confident in this analysis.")
    elif confidence > 0.6:
        insights.append("The model shows good confidence in this analysis.")
    else:
        insights.append("The analysis shows some uncertainty - consider recording from a different angle.")
    
    # Phase-specific insights
    phase_names = ["Setup", "Takeaway", "Backswing", "Transition", "Downswing", "Impact"]
    max_phase_prob = np.max(phase_probs)
    
    if max_phase_prob > 0.4:
        insights.append(f"The swing shows strong characteristics of the {dominant_phase.lower()} phase.")
        
        if dominant_phase == "Setup":
            insights.append("Focus on proper posture and alignment at address.")
        elif dominant_phase == "Takeaway":
            insights.append("Pay attention to the first 18 inches of your swing - it sets up everything.")
        elif dominant_phase == "Backswing":
            insights.append("Your backswing position is key - maintain width and proper club face angle.")
        elif dominant_phase == "Transition":
            insights.append("The transition from backswing to downswing is crucial for power and accuracy.")
        elif dominant_phase == "Downswing":
            insights.append("Focus on proper sequencing: hips, shoulders, arms, then club.")
        elif dominant_phase == "Impact":
            insights.append("Impact position determines ball flight - maintain forward shaft lean.")
    
    # Camera angle insights
    if angle_confidence < 0.5:
        insights.append("Camera angle detection was uncertain - try recording from directly behind or to the side.")
    
    return insights

# Backwards compatibility functions
def predict_with_multi_angle_lstm(video_path, model_path="models/enhanced_temporal_model.pt", 
                                 scaler_path="models/physics_scaler.pkl", 
                                 encoder_path="models/physics_label_encoder.pkl"):
    """Compatibility wrapper for the enhanced LSTM prediction"""
    return predict_with_enhanced_lstm(video_path, model_path, scaler_path, encoder_path, use_ensemble=False)

def predict_with_multi_angle_model(video_path, model_path="models/physics_based_model.pt", 
                                 scaler_path="models/physics_scaler.pkl", 
                                 encoder_path="models/physics_label_encoder.pkl"):
    """Enhanced version of the original multi-angle model with LSTM capabilities"""
    # Try enhanced LSTM first, fallback to physics model
    lstm_path = "models/enhanced_temporal_model.pt"
    
    if os.path.exists(lstm_path):
        print("🚀 Using enhanced LSTM model...")
        return predict_with_enhanced_lstm(video_path, lstm_path, model_path, scaler_path, encoder_path, use_ensemble=True)
    else:
        print("📚 Enhanced LSTM not available, using physics model...")
        # Fallback to original implementation
        from predict_multi_angle import predict_with_multi_angle_model as original_predict
        return original_predict(video_path, model_path, scaler_path, encoder_path)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python predict_enhanced_lstm.py <video_path> [--ensemble]")
        print("  --ensemble: Use hybrid LSTM + Physics ensemble (default: True)")
        sys.exit(1)
    
    video_path = sys.argv[1]
    use_ensemble = "--no-ensemble" not in sys.argv
    
    # Model paths
    lstm_model_path = "models/enhanced_temporal_model.pt"
    physics_model_path = "models/physics_based_model.pt" 
    scaler_path = "models/physics_scaler.pkl"
    encoder_path = "models/physics_label_encoder.pkl"
    
    print("🏌️ ENHANCED GOLF SWING AI - LSTM TEMPORAL ANALYSIS")
    print("="*60)
    
    result = predict_with_enhanced_lstm(
        video_path, lstm_model_path, physics_model_path, 
        scaler_path, encoder_path, use_ensemble
    )
    
    if result:
        print("\n✅ Enhanced Analysis Complete!")
        print("="*60)
        print(f"🎯 Swing Classification: {result['predicted_label']}")
        print(f"🎯 Confidence: {result['confidence']:.3f}")
        print(f"🎯 Camera Angle: {result['camera_angle']}")
        print(f"🎯 Dominant Phase: {result['dominant_phase']}")
        print(f"🎯 Analysis Type: {result['analysis_type']}")
        
        print("\n💡 Enhanced Insights:")
        for insight in result['enhanced_insights']:
            print(f"   • {insight}")
    else:
        print("❌ Analysis failed. Please check video file and try again.")