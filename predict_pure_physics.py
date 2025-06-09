"""
Pure Physics-Based Golf Swing Classification
No neural network - uses only physics principles for accurate swing plane analysis
"""

import numpy as np
from physics_based_features import GolfSwingPhysicsExtractor
from scripts.extract_features_robust import extract_keypoints_from_video_robust
import os
import logging

logger = logging.getLogger(__name__)

class PurePhysicsSwingClassifier:
    """
    Physics-only swing plane classifier based on biomechanical principles
    No machine learning bias - just pure golf swing physics
    """
    
    def __init__(self):
        # Golf swing physics constants (based on PGA analysis)
        self.ideal_plane_angle = 45  # degrees from vertical
        self.plane_tolerance = 10    # +/- degrees for "on plane"
        
        # Critical backswing thresholds
        self.steep_threshold = 55    # Above this = too steep
        self.flat_threshold = 35     # Below this = too flat
        
        # Consistency requirements
        self.min_consistency = 0.5   # Minimum consistency score
        
    def classify_swing_plane(self, features, feature_names):
        """
        Pure physics-based classification using biomechanical principles
        """
        
        # Extract key physics features
        backswing_avg_angle = features[0]      # Most critical
        backswing_max_angle = features[1]      
        backswing_consistency = features[2]    
        backswing_tendency = features[3]       
        avg_plane_angle = features[4]          # Overall swing plane
        plane_deviation = features[9]          # Deviation from ideal
        plane_consistency = features[10]       # Overall consistency
        
        print(f"🔬 PURE PHYSICS ANALYSIS:")
        print(f"   Early backswing angle: {backswing_avg_angle:.1f}°")
        print(f"   Overall plane angle: {avg_plane_angle:.1f}°")
        print(f"   Deviation from ideal (45°): {plane_deviation:.1f}°")
        print(f"   Consistency score: {backswing_consistency:.3f}")
        
        # Physics-based classification logic
        classification_factors = []
        confidence_factors = []
        
        # Factor 1: Early backswing analysis (MOST IMPORTANT - 60% weight)
        if backswing_avg_angle > self.steep_threshold:
            early_classification = "too_steep"
            early_confidence = min(0.95, (backswing_avg_angle - self.steep_threshold) / 20 + 0.7)
            early_reasoning = f"Early backswing {backswing_avg_angle:.1f}° > {self.steep_threshold}° threshold"
        elif backswing_avg_angle < self.flat_threshold:
            early_classification = "too_flat"
            early_confidence = min(0.95, (self.flat_threshold - backswing_avg_angle) / 20 + 0.7)
            early_reasoning = f"Early backswing {backswing_avg_angle:.1f}° < {self.flat_threshold}° threshold"
        else:
            early_classification = "on_plane"
            # Closer to ideal (45°) = higher confidence
            distance_from_ideal = abs(backswing_avg_angle - 45)
            early_confidence = min(0.95, 0.9 - (distance_from_ideal / 20))
            early_reasoning = f"Early backswing {backswing_avg_angle:.1f}° within {self.flat_threshold}-{self.steep_threshold}° range"
        
        classification_factors.append((early_classification, early_confidence * 0.6, early_reasoning))
        
        # Factor 2: Overall plane consistency (20% weight)
        if avg_plane_angle > self.steep_threshold + 5:
            overall_classification = "too_steep"
            overall_confidence = 0.7
        elif avg_plane_angle < self.flat_threshold - 5:
            overall_classification = "too_flat"
            overall_confidence = 0.7
        else:
            overall_classification = "on_plane"
            overall_confidence = 0.8
        
        classification_factors.append((overall_classification, overall_confidence * 0.2, f"Overall plane {avg_plane_angle:.1f}°"))
        
        # Factor 3: Plane deviation from ideal (20% weight)
        if plane_deviation > 15:  # More than 15° from ideal
            if avg_plane_angle > 45:
                deviation_classification = "too_steep"
            else:
                deviation_classification = "too_flat"
            deviation_confidence = min(0.8, plane_deviation / 30 + 0.5)
        else:
            deviation_classification = "on_plane"
            deviation_confidence = min(0.9, 0.9 - (plane_deviation / 30))
        
        classification_factors.append((deviation_classification, deviation_confidence * 0.2, f"Deviation {plane_deviation:.1f}° from ideal"))
        
        # Weighted voting system
        votes = {"too_steep": 0, "on_plane": 0, "too_flat": 0}
        total_confidence = 0
        
        for classification, confidence, reasoning in classification_factors:
            votes[classification] += confidence
            total_confidence += confidence
            print(f"   📊 {reasoning}: {classification} ({confidence:.2f})")
        
        # Determine final classification
        final_classification = max(votes, key=votes.get)
        final_confidence = votes[final_classification] / total_confidence
        
        # Consistency adjustment
        if backswing_consistency < 0.3:  # Very inconsistent swing
            final_confidence *= 0.8  # Reduce confidence
            consistency_note = "Reduced confidence due to inconsistent swing"
        else:
            consistency_note = "Consistent swing pattern"
        
        # Create physics-based probabilities
        physics_probabilities = {}
        for class_name in ["too_steep", "on_plane", "too_flat"]:
            physics_probabilities[class_name] = votes[class_name] / total_confidence
        
        # Ensure probabilities sum to 1
        prob_sum = sum(physics_probabilities.values())
        for key in physics_probabilities:
            physics_probabilities[key] /= prob_sum
        
        print(f"\n🎯 PHYSICS-BASED CLASSIFICATION:")
        print(f"   Final: {final_classification}")
        print(f"   Confidence: {final_confidence:.1%}")
        print(f"   Physics probabilities:")
        for class_name, prob in physics_probabilities.items():
            print(f"     {class_name}: {prob:.1%}")
        print(f"   Consistency: {consistency_note}")
        
        return {
            'classification': final_classification,
            'confidence': final_confidence,
            'probabilities': physics_probabilities,
            'physics_analysis': {
                'early_backswing_angle': backswing_avg_angle,
                'overall_plane_angle': avg_plane_angle,
                'deviation_from_ideal': plane_deviation,
                'consistency_score': backswing_consistency,
                'classification_factors': classification_factors
            },
            'reasoning': f"Physics-based: {early_reasoning}"
        }

def predict_with_pure_physics(video_path):
    """
    Pure physics-based prediction - no neural network involved
    """
    
    print(f"🔬 PURE PHYSICS SWING ANALYSIS: {video_path}")
    print("="*70)
    
    # Check if video exists
    if not os.path.exists(video_path):
        print(f"❌ Video file not found: {video_path}")
        return None
    
    # Extract keypoints
    keypoints, status = extract_keypoints_from_video_robust(video_path)
    
    if keypoints.size == 0:
        print(f"❌ Failed to extract keypoints: {status}")
        return None
    
    print(f"✅ Keypoints extracted: {keypoints.shape}")
    
    # Extract physics features
    extractor = GolfSwingPhysicsExtractor()
    features, feature_names = extractor.extract_feature_vector(keypoints)
    
    print(f"✅ Physics features extracted: {len(features)} features")
    
    # Pure physics classification
    classifier = PurePhysicsSwingClassifier()
    physics_result = classifier.classify_swing_plane(features, feature_names)
    
    # Calculate confidence gap
    probs = list(physics_result['probabilities'].values())
    probs.sort(reverse=True)
    confidence_gap = probs[0] - probs[1]
    
    # Format result to match expected API format
    result = {
        'predicted_label': physics_result['classification'],
        'confidence': physics_result['confidence'],
        'confidence_gap': confidence_gap,
        'all_probabilities': physics_result['probabilities'],
        'physics_features': features,
        'extraction_status': status,
        'method': 'pure_physics',
        'physics_analysis': physics_result['physics_analysis'],
        'reasoning': physics_result['reasoning']
    }
    
    print(f"\n📋 PURE PHYSICS SUMMARY:")
    print(f"   Prediction: {result['predicted_label']}")
    print(f"   Confidence: {result['confidence']:.1%}")
    print(f"   Method: Pure physics (no ML bias)")
    print(f"   Early backswing: {physics_result['physics_analysis']['early_backswing_angle']:.1f}°")
    print(f"   Overall plane: {physics_result['physics_analysis']['overall_plane_angle']:.1f}°")
    
    return result

def compare_methods(video_path):
    """
    Compare pure physics vs neural network predictions
    """
    
    print(f"⚖️ COMPARISON: Pure Physics vs Neural Network")
    print("="*60)
    
    # Pure physics prediction
    print("\n🔬 PURE PHYSICS METHOD:")
    physics_result = predict_with_pure_physics(video_path)
    
    # Neural network prediction (for comparison)
    print("\n🧠 NEURAL NETWORK METHOD:")
    try:
        from predict_physics_based import predict_with_physics_model
        nn_result = predict_with_physics_model(video_path)
        
        if physics_result and nn_result:
            print(f"\n📊 COMPARISON RESULTS:")
            print(f"   Pure Physics: {physics_result['predicted_label']} ({physics_result['confidence']:.1%})")
            print(f"   Neural Network: {nn_result['predicted_label']} ({nn_result['confidence']:.1%})")
            
            if physics_result['predicted_label'] == nn_result['predicted_label']:
                print("   ✅ Both methods agree")
            else:
                print("   ⚠️ Methods disagree - physics is likely more accurate")
                
                # Show why physics might be better
                early_angle = physics_result['physics_analysis']['early_backswing_angle']
                print(f"   🔬 Physics reasoning: Early backswing {early_angle:.1f}°")
                if 35 <= early_angle <= 55:
                    print("   💡 Physics suggests on_plane based on ideal backswing range")
                elif early_angle > 55:
                    print("   💡 Physics suggests too_steep based on biomechanics")
                else:
                    print("   💡 Physics suggests too_flat based on biomechanics")
        
    except Exception as e:
        print(f"❌ Neural network comparison failed: {str(e)}")
    
    return physics_result

def test_on_swing_3():
    """Test pure physics method on swing_3.mp4"""
    
    video_path = "/Users/nakulbhatnagar/Desktop/golf_swing_ai_v1/swing_3.mp4"
    
    print("🧪 Testing PURE PHYSICS on swing_3.mp4...")
    print("="*60)
    
    result = compare_methods(video_path)
    
    if result:
        early_angle = result['physics_analysis']['early_backswing_angle']
        prediction = result['predicted_label']
        
        print(f"\n🎯 PURE PHYSICS VERDICT:")
        print(f"   Early backswing: {early_angle:.1f}°")
        print(f"   Classification: {prediction}")
        print(f"   Confidence: {result['confidence']:.1%}")
        
        # Validate against physics principles
        if 35 <= early_angle <= 55:
            expected = "on_plane"
        elif early_angle > 55:
            expected = "too_steep"
        else:
            expected = "too_flat"
        
        print(f"   Expected (physics): {expected}")
        print(f"   Correct: {'✅' if prediction == expected else '❌'}")
        
        return prediction == expected
    
    return False

if __name__ == "__main__":
    test_on_swing_3()