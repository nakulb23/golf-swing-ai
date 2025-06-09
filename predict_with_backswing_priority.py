"""
Smart Golf Swing Prediction with Early Backswing Priority
Addresses the model accuracy issue by prioritizing early backswing analysis
"""

import numpy as np
import torch
import torch.nn.functional as F
from physics_based_features import GolfSwingPhysicsExtractor, PhysicsBasedSwingClassifier
from scripts.extract_features_robust import extract_keypoints_from_video_robust
import joblib
import os
import logging

logger = logging.getLogger(__name__)

def predict_with_backswing_priority(video_path, model_path="models/physics_based_model.pt", 
                                  scaler_path="models/physics_scaler.pkl", 
                                  encoder_path="models/physics_label_encoder.pkl"):
    """
    Smart prediction that prioritizes early backswing analysis over neural network output
    """
    
    print(f"🎬 Analyzing swing video with BACKSWING PRIORITY: {video_path}")
    print("="*70)
    
    # Check if video exists
    if not os.path.exists(video_path):
        print(f"❌ Video file not found: {video_path}")
        return None
    
    # Extract keypoints
    keypoints, status = extract_keypoints_from_video_robust(video_path)
    
    if keypoints.size == 0:
        print(f"❌ Failed to extract features: {status}")
        return None
    
    print(f"✅ Keypoints extracted: {keypoints.shape}")
    
    # Extract physics features
    extractor = GolfSwingPhysicsExtractor()
    features, feature_names = extractor.extract_feature_vector(keypoints)
    
    # Load model components
    try:
        model = PhysicsBasedSwingClassifier(num_features=35, num_classes=3)
        model.load_state_dict(torch.load(model_path, map_location='cpu'))
        model.eval()
        
        scaler = joblib.load(scaler_path)
        label_encoder = joblib.load(encoder_path)
        
    except Exception as e:
        print(f"❌ Failed to load model: {str(e)}")
        return None
    
    # Extract critical early backswing features
    backswing_avg_angle = features[0]      # Early backswing average angle
    backswing_max_angle = features[1]      # Early backswing max angle  
    backswing_consistency = features[2]    # Early backswing consistency
    backswing_tendency = features[3]       # Early backswing tendency
    
    print(f"\\n🔍 EARLY BACKSWING ANALYSIS:")
    print(f"   Average angle: {backswing_avg_angle:.1f}°")
    print(f"   Max angle: {backswing_max_angle:.1f}°")
    print(f"   Consistency: {backswing_consistency:.3f}")
    print(f"   Tendency: {backswing_tendency:.3f}")
    
    # Smart Classification Logic (prioritizes early backswing)
    smart_prediction = None
    confidence_adjustment = 0.0
    reasoning = ""
    
    # Rule 1: Clear early backswing patterns (HIGH CONFIDENCE)
    if 35 <= backswing_avg_angle <= 55 and abs(backswing_tendency) < 0.3:
        smart_prediction = "on_plane"
        confidence_adjustment = 0.2  # Boost confidence
        reasoning = f"Early backswing clearly on-plane ({backswing_avg_angle:.1f}° within 35-55° ideal range)"
        
    elif backswing_avg_angle > 60 and backswing_tendency > 0.5:
        smart_prediction = "too_steep"  
        confidence_adjustment = 0.1
        reasoning = f"Early backswing clearly too steep ({backswing_avg_angle:.1f}° > 60°)"
        
    elif backswing_avg_angle < 30 and backswing_tendency < -0.5:
        smart_prediction = "too_flat"
        confidence_adjustment = 0.1  
        reasoning = f"Early backswing clearly too flat ({backswing_avg_angle:.1f}° < 30°)"
    
    # Rule 2: Edge cases - defer to model but with reduced confidence
    elif 30 <= backswing_avg_angle <= 60:
        # Borderline case - use model but reduce confidence if conflicts with backswing
        confidence_adjustment = -0.1
        reasoning = f"Borderline backswing ({backswing_avg_angle:.1f}°) - using model with caution"
    
    # Get neural network prediction
    features_scaled = scaler.transform(features.reshape(1, -1))
    features_tensor = torch.FloatTensor(features_scaled)
    
    with torch.no_grad():
        outputs = model(features_tensor)
        probabilities = torch.softmax(outputs, dim=1)
        nn_predicted_class = torch.argmax(outputs, dim=1).item()
    
    nn_predicted_label = label_encoder.inverse_transform([nn_predicted_class])[0]
    nn_confidence = float(probabilities[0][nn_predicted_class])
    
    print(f"\\n🧠 NEURAL NETWORK PREDICTION:")
    print(f"   Predicted: {nn_predicted_label}")
    print(f"   Confidence: {nn_confidence:.1%}")
    
    # Final decision logic
    if smart_prediction is not None:
        if smart_prediction == nn_predicted_label:
            # Smart prediction agrees with NN - high confidence
            final_prediction = smart_prediction
            final_confidence = min(0.95, nn_confidence + confidence_adjustment)
            print(f"\\n✅ AGREEMENT: Both analyses predict {final_prediction}")
            
        else:
            # Smart prediction disagrees with NN - trust early backswing for critical range
            if 35 <= backswing_avg_angle <= 55:
                final_prediction = smart_prediction  # Trust early backswing analysis
                final_confidence = 0.75  # Moderate confidence when overriding
                print(f"\\n⚠️ OVERRIDE: Early backswing suggests {smart_prediction}, overriding NN prediction")
            else:
                # Outside critical range - average the predictions
                final_prediction = nn_predicted_label
                final_confidence = nn_confidence * 0.7  # Reduced confidence
                print(f"\\n🤔 UNCERTAINTY: Conflicting signals, using NN with reduced confidence")
    else:
        # No clear smart prediction - use NN
        final_prediction = nn_predicted_label
        final_confidence = nn_confidence + confidence_adjustment
        print(f"\\n🧠 NEURAL NETWORK: Using NN prediction (no clear backswing override)")
    
    print(f"\\n🎯 FINAL PREDICTION:")
    print(f"   Label: {final_prediction}")
    print(f"   Confidence: {final_confidence:.1%}")
    print(f"   Reasoning: {reasoning}")
    
    # Calculate confidence gap and all probabilities
    probs_sorted = torch.sort(probabilities[0], descending=True)[0]
    confidence_gap = float(probs_sorted[0] - probs_sorted[1])
    
    all_probs = {}
    for i, label in enumerate(label_encoder.classes_):
        all_probs[label] = float(probabilities[0][i])
    
    # Adjust probabilities to reflect final prediction
    if final_prediction != nn_predicted_label:
        # Redistribute probabilities to reflect override
        final_class_idx = list(label_encoder.classes_).index(final_prediction)
        all_probs[final_prediction] = final_confidence
        
        # Redistribute remaining probability
        remaining_prob = 1.0 - final_confidence
        other_classes = [c for c in label_encoder.classes_ if c != final_prediction]
        for other_class in other_classes:
            all_probs[other_class] = remaining_prob / len(other_classes)
    
    result = {
        'predicted_label': final_prediction,
        'confidence': final_confidence,
        'confidence_gap': confidence_gap,
        'all_probabilities': all_probs,
        'physics_features': features,
        'extraction_status': status,
        'neural_network_prediction': nn_predicted_label,
        'neural_network_confidence': nn_confidence,
        'override_applied': final_prediction != nn_predicted_label,
        'reasoning': reasoning,
        'early_backswing_analysis': {
            'avg_angle': float(backswing_avg_angle),
            'max_angle': float(backswing_max_angle),
            'consistency': float(backswing_consistency),
            'tendency': float(backswing_tendency)
        }
    }
    
    print(f"\\n📊 DETAILED RESULTS:")
    print(f"   Override applied: {'Yes' if result['override_applied'] else 'No'}")
    print(f"   Early backswing: {backswing_avg_angle:.1f}° (ideal: 35-55°)")
    
    return result

def test_on_swing_3():
    """Test the improved prediction on swing_3.mp4"""
    
    video_path = "/Users/nakulbhatnagar/Desktop/golf_swing_ai_v1/swing_3.mp4"
    
    print("🧪 Testing improved prediction on swing_3.mp4...")
    print("="*60)
    
    result = predict_with_backswing_priority(video_path)
    
    if result:
        print(f"\\n🎉 SUCCESS! New prediction: {result['predicted_label']}")
        print(f"📊 Confidence: {result['confidence']:.1%}")
        print(f"🔄 Override applied: {'Yes' if result['override_applied'] else 'No'}")
        print(f"💡 Reasoning: {result['reasoning']}")
        
        # Check if this fixes the original issue
        early_angle = result['early_backswing_analysis']['avg_angle']
        if 35 <= early_angle <= 55 and result['predicted_label'] == 'on_plane':
            print("\\n✅ FIXED! Early backswing is on-plane and correctly classified")
            return True
        else:
            print(f"\\n⚠️ Still needs work. Early backswing: {early_angle:.1f}°, Predicted: {result['predicted_label']}")
            return False
    else:
        print("❌ Prediction failed")
        return False

if __name__ == "__main__":
    test_on_swing_3()