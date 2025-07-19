"""
Improve Golf Swing AI Model Accuracy
Focus on early backswing features for better swing plane classification
"""

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix
import joblib
import os
from pathlib import Path
import logging

# Import existing components
from physics_based_features import GolfSwingPhysicsExtractor, PhysicsBasedSwingClassifier

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ImprovedPhysicsBasedSwingClassifier(nn.Module):
    """
    Improved neural network that emphasizes early backswing features
    """
    
    def __init__(self, num_features=35, num_classes=3):
        super().__init__()
        
        # Feature importance weights (emphasize early backswing)
        self.feature_weights = nn.Parameter(torch.ones(num_features), requires_grad=False)
        self._initialize_feature_weights()
        
        # Network architecture optimized for swing plane classification
        self.feature_processor = nn.Sequential(
            nn.Linear(num_features, 64),
            nn.ReLU(),
            nn.BatchNorm1d(64),
            nn.Dropout(0.3),
            
            nn.Linear(64, 32),
            nn.ReLU(),
            nn.BatchNorm1d(32),
            nn.Dropout(0.2),
            
            nn.Linear(32, 16),
            nn.ReLU(),
            nn.Dropout(0.1),
            
            nn.Linear(16, num_classes)
        )
    
    def _initialize_feature_weights(self):
        """Initialize feature weights to emphasize early backswing"""
        
        # Feature names in order (from physics_based_features.py)
        feature_importance = {
            # BACKSWING FEATURES (Priority 1 - HIGHEST WEIGHT)
            0: 5.0,  # 'backswing_avg_angle' - MOST IMPORTANT
            1: 4.0,  # 'backswing_max_angle' 
            2: 3.0,  # 'backswing_consistency'
            3: 4.0,  # 'backswing_tendency'
            
            # OVERALL PLANE FEATURES (Priority 2 - MEDIUM WEIGHT)
            4: 2.0,  # 'avg_plane_angle'
            5: 1.5,  # 'max_plane_angle' - Reduce weight (causes issues)
            6: 1.5,  # 'min_plane_angle'
            7: 1.0,  # 'plane_angle_range' - Reduce weight (causes issues)
            8: 2.0,  # 'plane_angle_std'
            9: 2.5,  # 'plane_deviation_from_ideal'
            10: 2.0, # 'plane_consistency'
            11: 2.0, # 'plane_tendency'
            
            # BODY ROTATION FEATURES (Priority 3 - LOWER WEIGHT)
            12: 1.0, # 'max_shoulder_turn'
            13: 1.0, # 'shoulder_rotation_range'
            14: 1.0, # 'max_hip_turn'
            15: 1.0, # 'hip_rotation_range'
            16: 1.0, # 'avg_x_factor'
            17: 1.0, # 'max_x_factor'
            18: 1.0, # 'rotation_sequence_correct'
            
            # SWING PATH FEATURES (Priority 4 - LOWER WEIGHT)
            19: 0.8, # 'total_path_length'
            20: 1.0, # 'path_smoothness'
            21: 0.8, # 'swing_width'
            22: 0.8, # 'swing_height'
            23: 0.8, # 'swing_depth'
            24: 1.0, # 'swing_plane_deviation'
            25: 1.0, # 'swing_plane_consistency'
            
            # TEMPO & TIMING FEATURES (Priority 5 - LOWEST WEIGHT)
            26: 0.5, # 'max_velocity'
            27: 0.5, # 'avg_velocity'
            28: 0.5, # 'velocity_consistency'
            29: 0.5, # 'impact_timing'
            30: 0.3, # 'max_acceleration' - Very low weight
            31: 0.3, # 'max_deceleration' - Very low weight
            
            # BALANCE FEATURES (Priority 6 - LOWEST WEIGHT)
            32: 0.5, # 'balance_stability'
            33: 0.5, # 'lateral_weight_shift'
            34: 0.5, # 'sagittal_balance'
        }
        
        # Set the weights
        for i in range(len(self.feature_weights)):
            self.feature_weights[i] = feature_importance.get(i, 1.0)
        
        logger.info("🎯 Initialized feature weights with early backswing emphasis")
    
    def forward(self, x):
        # Apply feature weighting
        weighted_x = x * self.feature_weights.unsqueeze(0)
        return self.feature_processor(weighted_x)

def create_weighted_loss_function():
    """
    Create a loss function that penalizes early backswing misclassifications more heavily
    """
    
    def weighted_cross_entropy(outputs, targets, feature_batch):
        """
        Custom loss that increases penalty when early backswing features suggest on-plane
        but model predicts steep/flat
        """
        
        # Base cross entropy loss
        base_loss = nn.CrossEntropyLoss()(outputs, targets)
        
        # Extract early backswing features for penalty calculation
        backswing_avg_angles = feature_batch[:, 0]  # backswing_avg_angle
        backswing_tendencies = feature_batch[:, 3]   # backswing_tendency
        
        # Calculate penalty for misclassifying good backswings
        penalties = torch.zeros_like(targets, dtype=torch.float32)
        
        for i, (angle, tendency, target, output) in enumerate(
            zip(backswing_avg_angles, backswing_tendencies, targets, outputs)
        ):
            predicted_class = torch.argmax(output)
            
            # If early backswing is on-plane (35-55 degrees, tendency near 0)
            # but model predicts steep/flat, add penalty
            if 35 <= angle <= 55 and abs(tendency) < 0.5:
                if target == 1 and predicted_class != 1:  # Should be on-plane but isn't
                    penalties[i] = 2.0  # Double the loss
                elif target != 1 and predicted_class == 1:  # Shouldn't be on-plane but is
                    penalties[i] = 0.5  # Reduce penalty for these cases
        
        # Apply penalties
        penalty_factor = 1.0 + penalties.mean()
        return base_loss * penalty_factor
    
    return weighted_cross_entropy

def load_and_prepare_data():
    """Load training data and prepare for improved training"""
    
    logger.info("📊 Loading training data...")
    
    # Check for existing processed data
    real_data_path = "real_physics_features.npz"
    synthetic_data_path = "synthetic_physics_features.npz"
    
    if not os.path.exists(real_data_path):
        logger.error(f"❌ Real training data not found: {real_data_path}")
        logger.info("💡 Run physics_based_features.py first to generate training data")
        return None, None, None, None
    
    # Load real data
    real_data = np.load(real_data_path)
    X_real = real_data['features']
    y_real = real_data['labels']
    
    logger.info(f"✅ Loaded {len(X_real)} real training samples")
    
    # Load synthetic data if available
    X_synthetic, y_synthetic = None, None
    if os.path.exists(synthetic_data_path):
        synthetic_data = np.load(synthetic_data_path)
        X_synthetic = synthetic_data['features']
        y_synthetic = synthetic_data['labels']
        logger.info(f"✅ Loaded {len(X_synthetic)} synthetic training samples")
    
    # Combine datasets
    if X_synthetic is not None:
        X = np.vstack([X_real, X_synthetic])
        y = np.concatenate([y_real, y_synthetic])
        logger.info(f"📊 Combined dataset: {len(X)} total samples")
    else:
        X = X_real
        y = y_real
        logger.info(f"📊 Using real data only: {len(X)} samples")
    
    return X, y, real_data.get('feature_names', None), real_data.get('filenames', None)

def train_improved_model():
    """Train the improved model with early backswing emphasis"""
    
    logger.info("🚀 Training Improved Golf Swing AI Model")
    logger.info("="*60)
    
    # Load data
    X, y, feature_names, filenames = load_and_prepare_data()
    if X is None:
        return None, None, None
    
    # Prepare label encoder
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)
    
    logger.info(f"📋 Classes: {label_encoder.classes_}")
    logger.info(f"📊 Class distribution: {np.bincount(y_encoded)}")
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y_encoded, test_size=0.2, random_state=42, stratify=y_encoded
    )
    
    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Convert to tensors
    X_train_tensor = torch.FloatTensor(X_train_scaled)
    X_test_tensor = torch.FloatTensor(X_test_scaled)
    y_train_tensor = torch.LongTensor(y_train)
    y_test_tensor = torch.LongTensor(y_test)
    
    # Initialize improved model
    model = ImprovedPhysicsBasedSwingClassifier(num_features=X.shape[1], num_classes=len(label_encoder.classes_))
    
    # Custom loss function and optimizer
    criterion = create_weighted_loss_function()
    optimizer = optim.AdamW(model.parameters(), lr=0.001, weight_decay=0.01)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, patience=10)
    
    # Training loop
    logger.info("🔧 Starting training with early backswing emphasis...")
    
    best_accuracy = 0
    patience_counter = 0
    max_patience = 20
    
    for epoch in range(200):
        model.train()
        
        # Forward pass
        outputs = model(X_train_tensor)
        loss = criterion(outputs, y_train_tensor, X_train_tensor)
        
        # Backward pass
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        # Validation
        if epoch % 10 == 0:
            model.eval()
            with torch.no_grad():
                test_outputs = model(X_test_tensor)
                test_loss = nn.CrossEntropyLoss()(test_outputs, y_test_tensor)
                
                _, predicted = torch.max(test_outputs.data, 1)
                accuracy = (predicted == y_test_tensor).sum().item() / len(y_test_tensor)
                
                logger.info(f"Epoch {epoch:3d}: Train Loss: {loss.item():.4f}, "
                          f"Test Loss: {test_loss.item():.4f}, Accuracy: {accuracy:.4f}")
                
                # Early stopping with improvement tracking
                if accuracy > best_accuracy:
                    best_accuracy = accuracy
                    patience_counter = 0
                    # Save best model
                    torch.save(model.state_dict(), "models/improved_physics_model.pt")
                else:
                    patience_counter += 1
                
                if patience_counter >= max_patience:
                    logger.info(f"🛑 Early stopping at epoch {epoch}")
                    break
                
                scheduler.step(test_loss)
    
    # Final evaluation
    model.load_state_dict(torch.load("models/improved_physics_model.pt"))
    model.eval()
    
    with torch.no_grad():
        test_outputs = model(X_test_tensor)
        _, predicted = torch.max(test_outputs.data, 1)
        
    # Print detailed results
    logger.info("\\n📊 IMPROVED MODEL RESULTS:")
    logger.info("="*40)
    
    report = classification_report(y_test, predicted.numpy(), 
                                 target_names=label_encoder.classes_, 
                                 output_dict=True)
    
    for class_name in label_encoder.classes_:
        metrics = report[class_name]
        logger.info(f"{class_name}: Precision: {metrics['precision']:.3f}, "
                   f"Recall: {metrics['recall']:.3f}, F1: {metrics['f1-score']:.3f}")
    
    logger.info(f"\\n🎯 Overall Accuracy: {report['accuracy']:.3f}")
    
    # Save components
    joblib.dump(scaler, "models/improved_physics_scaler.pkl")
    joblib.dump(label_encoder, "models/improved_physics_label_encoder.pkl")
    
    logger.info("✅ Improved model saved successfully!")
    
    return model, scaler, label_encoder

def test_on_swing_3():
    """Test the improved model on swing_3.mp4 to verify fix"""
    
    logger.info("🧪 Testing improved model on swing_3.mp4...")
    
    # Import prediction function
    from scripts.extract_features_robust import extract_keypoints_from_video_robust
    
    video_path = "/Users/nakulbhatnagar/Desktop/golf_swing_ai_v1/swing_3.mp4"
    
    if not os.path.exists(video_path):
        logger.error(f"❌ Test video not found: {video_path}")
        return
    
    # Extract features
    keypoints, status = extract_keypoints_from_video_robust(video_path)
    if keypoints.size == 0:
        logger.error(f"❌ Failed to extract keypoints: {status}")
        return
    
    # Extract physics features
    extractor = GolfSwingPhysicsExtractor()
    features, feature_names = extractor.extract_feature_vector(keypoints)
    
    # Load improved model
    try:
        model = ImprovedPhysicsBasedSwingClassifier(num_features=35, num_classes=3)
        model.load_state_dict(torch.load("models/improved_physics_model.pt"))
        model.eval()
        
        scaler = joblib.load("models/improved_physics_scaler.pkl")
        label_encoder = joblib.load("models/improved_physics_label_encoder.pkl")
        
        # Make prediction
        features_scaled = scaler.transform(features.reshape(1, -1))
        features_tensor = torch.FloatTensor(features_scaled)
        
        with torch.no_grad():
            outputs = model(features_tensor)
            probabilities = torch.softmax(outputs, dim=1)
            predicted_class = torch.argmax(outputs, dim=1).item()
        
        predicted_label = label_encoder.inverse_transform([predicted_class])[0]
        confidence = float(probabilities[0][predicted_class])
        
        # Show results
        logger.info("\\n🎯 IMPROVED MODEL TEST RESULTS:")
        logger.info("="*40)
        logger.info(f"Video: swing_3.mp4")
        logger.info(f"Early backswing angle: {features[0]:.1f}°")
        logger.info(f"Early backswing tendency: {features[3]:.3f}")
        logger.info(f"Predicted: {predicted_label} ({confidence:.1%} confidence)")
        
        # Compare with expected
        early_backswing_angle = features[0]
        if 35 <= early_backswing_angle <= 55:
            expected = "on_plane"
        elif early_backswing_angle > 55:
            expected = "too_steep"  
        else:
            expected = "too_flat"
            
        logger.info(f"Expected (based on early backswing): {expected}")
        logger.info(f"Correct: {'✅' if predicted_label == expected else '❌'}")
        
        return predicted_label == expected
        
    except Exception as e:
        logger.error(f"❌ Failed to test improved model: {str(e)}")
        return False

def main():
    """Run the complete model improvement process"""
    
    # Step 1: Train improved model
    model, scaler, label_encoder = train_improved_model()
    
    if model is None:
        logger.error("❌ Failed to train improved model")
        return
    
    # Step 2: Test on swing_3.mp4
    success = test_on_swing_3()
    
    if success:
        logger.info("\\n🎉 SUCCESS! Improved model correctly classifies swing_3.mp4")
        logger.info("💡 The model now prioritizes early backswing features")
        logger.info("🚀 Ready to deploy improved model")
    else:
        logger.info("\\n⚠️ Model still needs work - consider additional training data")

if __name__ == "__main__":
    main()