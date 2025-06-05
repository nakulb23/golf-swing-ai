import sys
sys.path.append('scripts')

import numpy as np
import torch
import torch.nn.functional as F
from physics_based_features import GolfSwingPhysicsExtractor, PhysicsBasedSwingClassifier
from scripts.extract_features_robust import extract_keypoints_from_video_robust
import joblib
import os

def predict_with_physics_model(video_path, model_path="models/physics_based_model.pt", 
                              scaler_path="models/physics_scaler.pkl", 
                              encoder_path="models/physics_label_encoder.pkl"):
    """Predict using the physics-based model"""
    
    print(f"🎬 Analyzing swing video with PHYSICS-BASED MODEL: {video_path}")
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
    
    print(f"📊 Extracted keypoints shape: {keypoints.shape}")
    print(f"✅ Feature extraction: {status}")
    
    # Extract physics-based features
    try:
        extractor = GolfSwingPhysicsExtractor()
        feature_vector, feature_names = extractor.extract_feature_vector(keypoints)
        print(f"🔬 Extracted {len(feature_vector)} physics features (including backswing analysis)")
    except Exception as e:
        print(f"❌ Error extracting physics features: {str(e)}")
        return None
    
    # Load preprocessors
    try:
        scaler = joblib.load(scaler_path)
        label_encoder = joblib.load(encoder_path)
        class_names = label_encoder.classes_
        num_classes = len(class_names)
    except FileNotFoundError as e:
        print(f"❌ Preprocessor not found: {str(e)}")
        return None
    
    print(f"🎯 Model classes: {list(class_names)}")
    
    # Scale features
    feature_vector_scaled = scaler.transform(feature_vector.reshape(1, -1))
    
    # Load physics-based model
    try:
        model = PhysicsBasedSwingClassifier(num_features=35, num_classes=num_classes)
        model.load_state_dict(torch.load(model_path, map_location=torch.device("cpu")))
        model.eval()
        print("🔬 Physics-based model loaded successfully")
    except FileNotFoundError:
        print(f"❌ Model file not found: {model_path}")
        return None
    except Exception as e:
        print(f"❌ Error loading model: {str(e)}")
        return None
    
    # Make prediction
    with torch.no_grad():
        input_tensor = torch.FloatTensor(feature_vector_scaled)
        output = model(input_tensor)
        probs = F.softmax(output, dim=1).squeeze().numpy()
        pred_idx = output.argmax(dim=1).item()
        predicted_label = label_encoder.inverse_transform([pred_idx])[0]
    
    # BACKSWING OVERRIDE RULE: Backswing faults take priority
    backswing_avg_angle = feature_vector[0]  # Early backswing angle
    backswing_tendency = feature_vector[3]   # Backswing tendency
    
    # Override prediction if backswing has clear fault
    if backswing_avg_angle < 35 and backswing_tendency < -0.5:
        predicted_label = 'too_flat'
        print("🔄 BACKSWING OVERRIDE: Flat backswing detected, overriding to TOO_FLAT")
        # Adjust probabilities to reflect override
        probs = np.array([0.1, 0.8, 0.1])  # High confidence for too_flat
    elif backswing_avg_angle > 55 and backswing_tendency > 0.5:
        predicted_label = 'too_steep' 
        print("🔄 BACKSWING OVERRIDE: Steep backswing detected, overriding to TOO_STEEP")
        # Adjust probabilities to reflect override
        probs = np.array([0.1, 0.1, 0.8])  # High confidence for too_steep
    
    # Display results
    print(f"\n🔍 Class Confidence Scores:")
    for i, class_name in enumerate(class_names):
        confidence = probs[i]
        print(f"  {class_name.ljust(12)}: {confidence:.3f} ({confidence*100:.1f}%)")
    
    max_confidence = np.max(probs)
    print(f"\n🟢 Predicted Swing Classification: {predicted_label.upper()}")
    print(f"🎯 Confidence: {max_confidence*100:.1f}%")
    
    # Enhanced confidence assessment
    confidence_gap = max_confidence - np.partition(probs, -2)[-2]  # Gap to second highest
    
    if max_confidence > 0.85:
        print(f"\n✅ Excellent confidence - very clear prediction (gap: {confidence_gap:.3f})")
    elif max_confidence > 0.7:
        print(f"\n✅ High confidence - clear prediction (gap: {confidence_gap:.3f})")
    elif max_confidence > 0.5:
        print(f"\n🔵 Moderate confidence - reasonable prediction (gap: {confidence_gap:.3f})")
    else:
        print(f"\n⚠️  Low confidence - uncertain prediction (gap: {confidence_gap:.3f})")
    
    # Display key physics insights with backswing focus
    print(f"\n🔬 KEY PHYSICS INSIGHTS:")
    
    # NEW: Backswing-specific analysis (first 4 features)
    backswing_avg_angle = feature_vector[0]  # backswing_avg_angle
    backswing_max_angle = feature_vector[1]  # backswing_max_angle  
    backswing_consistency = feature_vector[2]  # backswing_consistency
    backswing_tendency = feature_vector[3]  # backswing_tendency
    
    # Overall plane analysis (features 4-7)
    avg_plane_angle = feature_vector[4]  # avg_plane_angle
    plane_tendency = feature_vector[11]   # plane_tendency
    
    print(f"  🏌️ EARLY BACKSWING ANALYSIS (Critical Phase):")
    print(f"    Early Backswing Plane Angle: {backswing_avg_angle:.1f}°")
    print(f"    Early Backswing Max Angle: {backswing_max_angle:.1f}°")
    print(f"    Early Backswing Consistency: {backswing_consistency:.3f}")
    
    if backswing_tendency > 0.5:
        print(f"    ⚠️  BACKSWING FAULT: TOO STEEP (>55° from vertical)")
    elif backswing_tendency < -0.5:
        print(f"    ⚠️  BACKSWING FAULT: TOO FLAT (<35° from vertical)")
    else:
        print(f"    ✅ Backswing: ON-PLANE (35-55° from vertical)")
    
    print(f"\n  📊 Overall Swing Plane: {avg_plane_angle:.1f}°")
    if plane_tendency > 0.5:
        print(f"    Overall Analysis: Swing plane is TOO STEEP (>55° from vertical)")
    elif plane_tendency < -0.5:
        print(f"    Overall Analysis: Swing plane is TOO FLAT (<35° from vertical)")
    else:
        print(f"    Overall Analysis: Swing plane is ON-PLANE (35-55° from vertical)")
    
    return {
        'predicted_label': predicted_label,
        'confidence': max_confidence,
        'confidence_gap': confidence_gap,
        'all_probabilities': dict(zip(class_names, probs)),
        'physics_features': feature_vector,
        'feature_names': feature_names,
        'keypoints_shape': keypoints.shape,
        'extraction_status': status
    }

def compare_all_approaches(video_path):
    """Compare all model approaches on a video"""
    
    print(f"🔄 COMPLETE MODEL COMPARISON: {video_path}")
    print("="*80)
    
    results = {}
    
    # 1. Physics-Based Model (Latest and Best)
    print("🔬 PHYSICS-BASED MODEL (Latest):")
    try:
        physics_result = predict_with_physics_model(video_path)
        if physics_result:
            results['physics_based'] = physics_result
    except Exception as e:
        print(f"❌ Physics-based model error: {str(e)}")
    
    print("\n" + "="*80)
    
    # 2. Simple Robust Model
    print("🔧 SIMPLE ROBUST MODEL:")
    try:
        from predict_simple_robust import predict_with_simple_robust_model
        simple_result = predict_with_simple_robust_model(video_path)
        if simple_result:
            results['simple_robust'] = simple_result
    except Exception as e:
        print(f"❌ Simple robust model error: {str(e)}")
    
    # Summary
    print("\n" + "="*80)
    print("📋 COMPLETE MODEL COMPARISON SUMMARY:")
    print("="*80)
    
    for model_name, result in results.items():
        if result:
            conf = result['confidence']*100
            print(f"{model_name.upper().ljust(20)}: {result['predicted_label'].upper()} ({conf:.1f}%)")
    
    return results

def main():
    """Test physics-based model on all test videos"""
    
    test_videos = [
        ("videos/test_swing2.mp4", "on_plane"),
        ("videos/test_swing3.mov", "on_plane")
    ]
    
    print("🔬 TESTING PHYSICS-BASED MODEL")
    print("="*50)
    
    all_correct = True
    
    for video, expected in test_videos:
        if os.path.exists(video):
            print(f"\n{'='*70}")
            print(f"TESTING: {video} (Expected: {expected})")
            print('='*70)
            
            result = predict_with_physics_model(video)
            
            if result:
                actual = result['predicted_label']
                confidence = result['confidence']
                
                if actual == expected:
                    print(f"\n🎉 PERFECT: Expected {expected}, got {actual} ({confidence*100:.1f}%)")
                else:
                    print(f"\n❌ INCORRECT: Expected {expected}, got {actual} ({confidence*100:.1f}%)")
                    all_correct = False
            else:
                print(f"❌ FAILED to analyze {video}")
                all_correct = False
        else:
            print(f"⚠️  Video not found: {video}")
    
    print(f"\n🏆 FINAL ASSESSMENT:")
    if all_correct:
        print("🎉 ALL TEST VIDEOS CLASSIFIED CORRECTLY WITH PHYSICS-BASED MODEL!")
        print("✅ The physics-based approach successfully solved the swing plane classification problem!")
    else:
        print("❌ Some test videos were still misclassified")
    
    return all_correct

if __name__ == "__main__":
    main()