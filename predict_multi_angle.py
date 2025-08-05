import sys
sys.path.append('scripts')

import numpy as np
import torch
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

def predict_with_multi_angle_model(video_path, model_path="models/physics_based_model.pt", 
                                 scaler_path="models/physics_scaler.pkl", 
                                 encoder_path="models/physics_label_encoder.pkl"):
    """
    Enhanced prediction using multi-angle camera support and view-invariant features.
    
    This function:
    1. Detects camera angle automatically
    2. Transforms coordinates to canonical view
    3. Extracts view-invariant physics features
    4. Applies angle-specific feature weighting
    5. Provides enhanced analysis with confidence metrics
    """
    
    print(f"🎬 Analyzing swing video with MULTI-ANGLE PHYSICS MODEL: {video_path}")
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
    
    # STEP 1: Detect camera angle and extract view-invariant features
    try:
        view_extractor = ViewInvariantFeatureExtractor()
        view_result = view_extractor.extract_view_invariant_features(keypoints)
        
        camera_analysis = view_result['camera_analysis']
        camera_angle = camera_analysis['angle_type']
        angle_confidence = camera_analysis['confidence']
        feature_weights = view_result['feature_weights']
        
        print(f"📷 Camera Angle Detected: {camera_angle.value}")
        print(f"📷 Detection Confidence: {angle_confidence:.3f}")
        print(f"📷 Reliability Score: {camera_analysis.get('reliability_score', 0):.3f}")
        
        # Display feature reliability by category
        print("\n🎯 Feature Reliability by Category:")
        for category, weight in feature_weights.items():
            print(f"   {category.replace('_', ' ').title()}: {weight:.3f}")
        
    except FileNotFoundError as e:
        print(f"❌ Camera angle model file not found: {str(e)}")
        print("📷 Falling back to traditional analysis...")
        camera_angle = CameraAngle.SIDE_ON
        angle_confidence = 0.0  # Low confidence for fallback
        view_result = None
    except ValueError as e:
        print(f"❌ Invalid video format for camera angle detection: {str(e)}")
        print("📷 Falling back to traditional analysis...")
        camera_angle = CameraAngle.SIDE_ON
        angle_confidence = 0.0
        view_result = None
    except Exception as e:
        print(f"❌ Unexpected error in camera angle detection: {str(e)}")
        print("📷 Falling back to traditional analysis...")
        camera_angle = CameraAngle.SIDE_ON
        angle_confidence = 0.0
        view_result = None
    
    # STEP 2: Extract physics features (view-invariant if possible)
    try:
        if view_result and 'features' in view_result and view_result['features']:
            # Use view-invariant features
            physics_features = view_result['features']
            feature_names = list(physics_features.keys())
            feature_vector = np.array([physics_features[name] for name in feature_names])
            
            print(f"🔬 Extracted {len(feature_vector)} VIEW-INVARIANT physics features")
            print(f"🔬 Features weighted for {camera_angle.value} perspective")
            
        else:
            # Fallback to traditional physics extraction
            extractor = GolfSwingPhysicsExtractor()
            feature_vector, feature_names = extractor.extract_feature_vector(keypoints)
            print(f"🔬 Extracted {len(feature_vector)} traditional physics features")
            
    except Exception as e:
        print(f"❌ Error extracting physics features: {str(e)}")
        return None
    
    # Validate feature vector dimensions
    expected_features = 35
    if len(feature_vector) != expected_features:
        print(f"⚠️  Feature dimension mismatch: Expected {expected_features}, got {len(feature_vector)}")
        
        if len(feature_vector) < expected_features:
            # Pad with zeros and log warning
            padding_size = expected_features - len(feature_vector)
            feature_vector = np.pad(feature_vector, (0, padding_size), 'constant', constant_values=0)
            print(f"⚠️  Padded {padding_size} features with zeros - prediction accuracy may be reduced")
        else:
            # Truncate and log warning
            truncated_features = len(feature_vector) - expected_features
            feature_vector = feature_vector[:expected_features]
            print(f"⚠️  Truncated {truncated_features} features - some information may be lost")
        
        # Add dimension mismatch flag to result
        dimension_mismatch = True
    else:
        dimension_mismatch = False
    
    # STEP 3: Load model and preprocessors
    try:
        scaler = joblib.load(scaler_path)
        label_encoder = joblib.load(encoder_path)
        class_names = label_encoder.classes_
        num_classes = len(class_names)
        
        print(f"🧠 Loaded model components for {num_classes} classes: {list(class_names)}")
        
    except FileNotFoundError as e:
        print(f"❌ Model file not found: {e}")
        return None
    except Exception as e:
        print(f"❌ Error loading model components: {str(e)}")
        return None
    
    # STEP 4: Load and prepare neural network
    try:
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        model = PhysicsBasedSwingClassifier(input_size=35, num_classes=num_classes)
        model.load_state_dict(torch.load(model_path, map_location=device))
        model.eval()
        model.to(device)
        
        print(f"🧠 Loaded neural network on {device}")
        
    except Exception as e:
        print(f"❌ Error loading neural network: {str(e)}")
        return None
    
    # STEP 5: Preprocess features
    try:
        # Scale features
        feature_vector = feature_vector.reshape(1, -1)
        scaled_features = scaler.transform(feature_vector)
        
        # Convert to tensor
        feature_tensor = torch.FloatTensor(scaled_features).to(device)
        
    except Exception as e:
        print(f"❌ Error preprocessing features: {str(e)}")
        return None
    
    # STEP 6: Make prediction
    try:
        with torch.no_grad():
            outputs = model(feature_tensor)
            probabilities = F.softmax(outputs, dim=1).cpu().numpy()[0]
            predicted_class_idx = np.argmax(probabilities)
            predicted_label = class_names[predicted_class_idx]
            confidence = probabilities[predicted_class_idx]
        
        print(f"\n🎯 MULTI-ANGLE PREDICTION RESULTS:")
        print(f"🎯 Predicted Class: {predicted_label}")
        print(f"🎯 Model Confidence: {confidence:.3f}")
        print(f"🎯 Camera Angle: {camera_angle.value} (confidence: {angle_confidence:.3f})")
        
    except Exception as e:
        print(f"❌ Error during prediction: {str(e)}")
        return None
    
    # STEP 7: Enhanced analysis with angle-specific insights
    try:
        analysis_result = generate_enhanced_analysis(
            predicted_label, confidence, probabilities, class_names,
            camera_angle, angle_confidence, feature_weights, view_result
        )
        
        print(f"\n📋 ENHANCED ANALYSIS:")
        print(f"📋 {analysis_result['physics_insights']}")
        
        if camera_angle != CameraAngle.SIDE_ON:
            print(f"\n📷 CAMERA ANGLE INSIGHTS:")
            print(f"📷 {analysis_result['angle_insights']}")
        
        # Add quality flags to the result
        analysis_result['feature_dimension_ok'] = not dimension_mismatch
        analysis_result['quality_score'] = calculate_prediction_quality(
            confidence, angle_confidence, dimension_mismatch
        )
        
        return analysis_result
        
    except Exception as e:
        print(f"❌ Error generating analysis: {str(e)}")
        # Return basic result even if enhanced analysis fails
        basic_result = {
            "predicted_label": predicted_label,
            "confidence": float(confidence),
            "all_probabilities": {class_names[i]: float(probabilities[i]) for i in range(len(class_names))},
            "camera_angle": camera_angle.value,
            "angle_confidence": float(angle_confidence),
            "extraction_status": "success",
            "feature_dimension_ok": not dimension_mismatch,
            "quality_score": calculate_prediction_quality(
                confidence, angle_confidence, dimension_mismatch
            )
        }
        return basic_result

def calculate_prediction_quality(confidence, angle_confidence, dimension_mismatch):
    """Calculate overall prediction quality score"""
    base_score = (confidence + angle_confidence) / 2
    
    # Penalize dimension mismatches
    if dimension_mismatch:
        base_score *= 0.8
    
    # Ensure reasonable bounds
    return max(0.0, min(1.0, base_score))

def generate_enhanced_analysis(predicted_label, confidence, probabilities, class_names,
                             camera_angle, angle_confidence, feature_weights, view_result):
    """Generate enhanced analysis combining traditional and multi-angle insights"""
    
    # Calculate confidence gap (margin between top 2 predictions)
    sorted_probs = np.sort(probabilities)[::-1]
    confidence_gap = sorted_probs[0] - sorted_probs[1] if len(sorted_probs) > 1 else sorted_probs[0]
    
    # Generate physics insights
    physics_insights = generate_physics_insights(predicted_label, confidence, confidence_gap)
    
    # Generate camera angle specific insights
    angle_insights = generate_angle_insights(camera_angle, angle_confidence, feature_weights)
    
    # Enhanced recommendations based on camera angle
    recommendations = generate_angle_specific_recommendations(
        predicted_label, camera_angle, feature_weights
    )
    
    return {
        "predicted_label": predicted_label,
        "confidence": float(confidence),
        "confidence_gap": float(confidence_gap),
        "all_probabilities": {class_names[i]: float(probabilities[i]) for i in range(len(class_names))},
        "camera_angle": camera_angle.value,
        "angle_confidence": float(angle_confidence),
        "feature_reliability": feature_weights,
        "physics_insights": physics_insights,
        "angle_insights": angle_insights,
        "recommendations": recommendations,
        "extraction_status": "success_multi_angle"
    }

def generate_physics_insights(predicted_label, confidence, confidence_gap):
    """Generate physics-based insights similar to original system"""
    
    if predicted_label == "too_steep":
        insight = f"Your swing plane is too steep (confidence: {confidence:.1%}). "
        insight += "This can lead to fat shots, loss of distance, and inconsistent ball striking. "
        insight += "Focus on taking the club back more around your body and less vertically."
        
    elif predicted_label == "too_flat":
        insight = f"Your swing plane is too flat (confidence: {confidence:.1%}). "
        insight += "This can cause thin shots and hooks. "
        insight += "Work on getting the club up more vertically in your backswing."
        
    else:  # on_plane
        insight = f"Your swing plane looks good! (confidence: {confidence:.1%}) "
        insight += "You're maintaining a good plane angle throughout your swing. "
        insight += "Keep working on consistency and tempo."
    
    if confidence_gap < 0.2:
        insight += f" Note: The model shows some uncertainty (gap: {confidence_gap:.1%}), "
        insight += "so consider getting additional analysis or video from different angles."
    
    return insight

def generate_angle_insights(camera_angle, angle_confidence, feature_weights):
    """Generate insights specific to the detected camera angle"""
    
    insights = []
    
    # Camera angle detection insights
    if angle_confidence > 0.8:
        insights.append(f"Camera angle detection is highly confident ({angle_confidence:.1%}).")
    elif angle_confidence > 0.6:
        insights.append(f"Camera angle detection is moderately confident ({angle_confidence:.1%}).")
    else:
        insights.append(f"Camera angle detection has low confidence ({angle_confidence:.1%}). "
                       "Consider recording from a clearer angle for better analysis.")
    
    # Angle-specific analysis quality
    if camera_angle == CameraAngle.SIDE_ON:
        insights.append("Side-on view provides optimal swing plane analysis. "
                       "This is the ideal angle for detecting swing plane issues.")
        
    elif camera_angle == CameraAngle.FRONT_ON:
        insights.append("Front-on view is excellent for analyzing balance and alignment. "
                       "However, swing plane analysis may be less accurate from this angle.")
        
    elif camera_angle == CameraAngle.BEHIND:
        insights.append("Behind view is great for club path analysis. "
                       "Swing plane measurements are adjusted for this perspective.")
        
    elif camera_angle in [CameraAngle.ANGLED_SIDE, CameraAngle.ANGLED_FRONT]:
        insights.append("Angled view detected. Analysis has been adjusted for this perspective. "
                       "For best results, try recording from directly to the side.")
        
    else:
        insights.append("Camera angle could not be determined reliably. "
                       "Results may be less accurate. Try recording from a side-on position.")
    
    # Feature reliability insights
    best_features = [k for k, v in feature_weights.items() if v > 0.8]
    if best_features:
        insights.append(f"Most reliable analysis: {', '.join(best_features).replace('_', ' ')}.")
    
    worst_features = [k for k, v in feature_weights.items() if v < 0.5]
    if worst_features:
        insights.append(f"Less reliable from this angle: {', '.join(worst_features).replace('_', ' ')}.")
    
    return " ".join(insights)

def generate_angle_specific_recommendations(predicted_label, camera_angle, feature_weights):
    """Generate recommendations specific to camera angle and swing analysis"""
    
    recommendations = []
    
    # Enhanced swing-specific recommendations based on classification
    if predicted_label == "too_steep":
        # Primary fixes for steep swings
        recommendations.append("🎯 Setup: Widen your stance slightly and bend more from the hips to create room for a shallower path")
        recommendations.append("🏌️ Takeaway: Start the club more inside by focusing on rotating your chest while keeping arms relaxed")
        recommendations.append("💪 Drill: Place a headcover just outside your ball - practice missing it on the backswing")
        
        # Check specific feature weights for additional tips
        if feature_weights.get('shaft_lean', 0) > 0.7:
            recommendations.append("⚠️ Excessive forward shaft lean detected - try to maintain more neutral shaft position at setup")
        if feature_weights.get('shoulder_rotation', 0) < 0.5:
            recommendations.append("🔄 Limited shoulder turn - work on getting your lead shoulder under your chin in backswing")
            
    elif predicted_label == "too_flat":
        # Primary fixes for flat swings
        recommendations.append("🎯 Setup: Stand slightly closer to the ball and maintain spine angle throughout swing")
        recommendations.append("🏌️ Backswing: Feel like you're lifting the club more vertically in the first part of takeaway")
        recommendations.append("💪 Drill: Practice swings with club shaft against a wall behind you - maintain that angle")
        
        # Check specific features
        if feature_weights.get('hip_sway', 0) > 0.6:
            recommendations.append("⚠️ Excessive hip sway detected - focus on rotating around your spine, not sliding")
        if feature_weights.get('arm_extension', 0) < 0.5:
            recommendations.append("📐 Keep your lead arm straighter in backswing for better plane control")
            
    else:  # Good plane
        # Refinement tips for good swings
        recommendations.append("✅ Excellent swing plane! Focus on consistency with these refinements:")
        
        # Look for minor improvements even in good swings
        if feature_weights.get('tempo', 0) < 0.7:
            recommendations.append("⏱️ Work on smoother tempo - count '1-2' on backswing, '3' on downswing")
        if feature_weights.get('weight_transfer', 0) < 0.8:
            recommendations.append("⚖️ Enhance weight transfer - feel 70% weight on trail foot at top of backswing")
        else:
            recommendations.append("🎯 Practice this swing under pressure - hit 10 balls with same pre-shot routine")
            recommendations.append("📹 Record yourself weekly to ensure you maintain this excellent plane")
    
    # Camera angle-specific tips
    if camera_angle == CameraAngle.FRONT_ON:
        recommendations.append("📸 Front view tip: Check that your head stays centered over the ball through impact")
    elif camera_angle == CameraAngle.BEHIND:
        recommendations.append("📸 Behind view tip: Ensure club exits left of target line after impact (right-handed)")
    elif camera_angle == CameraAngle.DIAGONAL:
        recommendations.append("📸 For best analysis, try recording from directly side-on (90° to target line)")
    
    # Limit to top 5 most relevant recommendations
    return recommendations[:5]

# Backwards compatibility function
def predict_with_physics_model(video_path, model_path="models/physics_based_model.pt", 
                              scaler_path="models/physics_scaler.pkl", 
                              encoder_path="models/physics_label_encoder.pkl"):
    """Backwards compatible wrapper for existing API calls"""
    return predict_with_multi_angle_model(video_path, model_path, scaler_path, encoder_path)

if __name__ == "__main__":
    # Test the multi-angle prediction
    if len(sys.argv) > 1:
        video_path = sys.argv[1]
        result = predict_with_multi_angle_model(video_path)
        if result:
            print("\n" + "="*80)
            print("🎉 MULTI-ANGLE ANALYSIS COMPLETE!")
            print("="*80)
    else:
        print("Usage: python predict_multi_angle.py <video_path>")