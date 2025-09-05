# Server Training Guide - Golf Swing AI Data Processing

This guide explains how to process and interpret the incoming data from Golf Swing AI iOS app for model training and improvement.

## 🎯 Understanding the Data

### Data Types Received

The server receives two main types of data:

1. **Prediction Data**: Every swing analysis result
2. **Feedback Data**: User corrections when AI predictions are wrong

### Feature Vector Explanation (35 Features)

Each swing analysis produces a 35-element feature vector representing biomechanical aspects:

```python
# Feature Index Mapping
FEATURE_MAPPING = {
    0: "spine_angle",              # Degrees (0-90)
    1: "knee_flexion",             # Degrees (0-90) 
    2: "weight_distribution",      # Ratio (0-1, 0.5=balanced)
    3: "arm_hang_angle",           # Degrees (0-45)
    4: "stance_width",             # Normalized width (0-50)
    5: "max_shoulder_turn",        # Degrees (60-120)
    6: "hip_turn_at_top",          # Degrees (30-80)
    7: "x_factor",                 # Shoulder-hip separation (20-60)
    8: "swing_plane_angle",        # Degrees (30-70)
    9: "arm_extension",            # Percentage (60-100)
    10: "weight_shift",            # Left-right transfer (0-1)
    11: "wrist_hinge",             # Degrees (45-90)
    12: "backswing_tempo",         # Time ratio (2.0-4.0)
    13: "head_movement",           # Stability metric (0-10)
    14: "knee_stability",          # Flexion consistency (70-100)
    15: "transition_tempo",        # Top-to-impact time (0.2-0.4)
    16: "hip_lead",                # Hip initiation angle (40-80)
    17: "weight_transfer_rate",    # Speed of shift (0.5-1.0)
    18: "wrist_timing",            # Release timing (70-95)
    19: "sequence_efficiency",     # Kinetic chain (75-100)
    20: "hip_rotation_speed",      # Degrees/second (120-200)
    21: "shoulder_rotation_speed", # Degrees/second (150-250)
    22: "club_path_angle",         # Inside-out path (-5 to +5)
    23: "attack_angle",            # Up/down at impact (-3 to +3)
    24: "release_timing",          # Wrist release point (65-85)
    25: "left_side_stability",     # Left side firmness (80-100)
    26: "downswing_tempo",         # Impact timing (1.5-2.5)
    27: "power_generation",        # Energy transfer (70-100)
    28: "impact_position",         # Solid contact (75-100)
    29: "extension_through_impact", # Arm extension (80-100)
    30: "follow_through_balance",  # Finish stability (70-100)
    31: "finish_quality",          # Finish position (70-100)
    32: "overall_tempo",           # Full swing timing (2.5-3.5)
    33: "rhythm_consistency",      # Tempo smoothness (75-100)
    34: "swing_efficiency"         # Overall coordination (70-100)
}

# Classification Labels
SWING_CLASSIFICATIONS = {
    "good_swing": "Biomechanically sound swing",
    "too_steep": "Swing plane too vertical",
    "too_flat": "Swing plane too horizontal"
}
```

## 🧠 Data Processing Pipeline

### 1. Data Ingestion

```python
import pandas as pd
import numpy as np
import json
from datetime import datetime

class SwingDataProcessor:
    def __init__(self):
        self.feature_names = list(FEATURE_MAPPING.values())
        self.valid_labels = list(SWING_CLASSIFICATIONS.keys())
    
    def process_incoming_data(self, data_point):
        """Process single data point from iOS app"""
        
        # Extract features
        features = np.array(data_point['features'])
        
        # Get ground truth label
        ground_truth = self.get_ground_truth_label(
            data_point['modelPrediction'],
            data_point.get('userFeedback')
        )
        
        # Extract metadata
        metadata = self.extract_metadata(data_point)
        
        # Validate data quality
        if self.validate_data_point(features, ground_truth):
            return {
                'features': features,
                'label': ground_truth,
                'confidence': data_point['modelConfidence'],
                'metadata': metadata,
                'is_user_corrected': data_point.get('userFeedback') is not None
            }
        
        return None
    
    def get_ground_truth_label(self, prediction, feedback):
        """Determine ground truth label from prediction and feedback"""
        
        if feedback and not feedback.get('isCorrect', True):
            # User corrected the prediction - use their label
            return feedback['correctedLabel']
        else:
            # No feedback or user confirmed correct - use AI prediction
            return prediction
    
    def validate_data_point(self, features, label):
        """Validate data quality"""
        
        # Check feature vector length
        if len(features) != 35:
            return False
        
        # Check for valid label
        if label not in self.valid_labels:
            return False
        
        # Check for reasonable feature ranges
        if not self.validate_feature_ranges(features):
            return False
        
        return True
    
    def validate_feature_ranges(self, features):
        """Validate feature values are in expected ranges"""
        
        # Define expected ranges for each feature
        ranges = {
            0: (0, 90),     # spine_angle
            1: (0, 90),     # knee_flexion
            2: (0, 1),      # weight_distribution
            8: (20, 80),    # swing_plane_angle
            12: (1.5, 5.0), # backswing_tempo
            # Add more critical ranges as needed
        }
        
        for idx, (min_val, max_val) in ranges.items():
            if not (min_val <= features[idx] <= max_val):
                print(f"Feature {self.feature_names[idx]} out of range: {features[idx]}")
                return False
        
        return True
```

### 2. Feature Analysis and Insights

```python
class SwingAnalyzer:
    def __init__(self):
        self.processor = SwingDataProcessor()
    
    def analyze_prediction_patterns(self, training_data):
        """Analyze common prediction patterns and errors"""
        
        df = pd.DataFrame(training_data)
        
        # Analyze confidence vs accuracy
        confidence_accuracy = self.analyze_confidence_accuracy(df)
        
        # Find common misclassification patterns
        confusion_patterns = self.analyze_confusion_patterns(df)
        
        # Identify challenging feature combinations
        difficult_cases = self.find_difficult_cases(df)
        
        return {
            'confidence_accuracy': confidence_accuracy,
            'confusion_patterns': confusion_patterns,
            'difficult_cases': difficult_cases
        }
    
    def analyze_confidence_accuracy(self, df):
        """Analyze relationship between model confidence and accuracy"""
        
        # Only analyze cases where we have user feedback
        feedback_df = df[df['is_user_corrected'].notna()]
        
        if len(feedback_df) == 0:
            return {"message": "No user feedback data available"}
        
        # Group by confidence ranges
        confidence_ranges = [
            (0.0, 0.5, "Very Low"),
            (0.5, 0.7, "Low"),
            (0.7, 0.8, "Medium"),
            (0.8, 0.9, "High"),
            (0.9, 1.0, "Very High")
        ]
        
        analysis = []
        for min_conf, max_conf, label in confidence_ranges:
            range_data = feedback_df[
                (feedback_df['confidence'] >= min_conf) & 
                (feedback_df['confidence'] < max_conf)
            ]
            
            if len(range_data) > 0:
                # Calculate accuracy for this confidence range
                correct_predictions = len(range_data[~range_data['is_user_corrected']])
                total_predictions = len(range_data)
                accuracy = correct_predictions / total_predictions
                
                analysis.append({
                    'confidence_range': label,
                    'range': f"{min_conf:.1f}-{max_conf:.1f}",
                    'sample_count': total_predictions,
                    'accuracy': accuracy,
                    'avg_confidence': range_data['confidence'].mean()
                })
        
        return analysis
    
    def analyze_confusion_patterns(self, df):
        """Find common misclassification patterns"""
        
        # Get user-corrected samples only
        corrections = df[df['is_user_corrected'] == True]
        
        if len(corrections) == 0:
            return {"message": "No correction data available"}
        
        confusion_matrix = {}
        
        for _, row in corrections.iterrows():
            # Original AI prediction vs user correction
            ai_pred = row['model_prediction']  # What AI predicted
            correct_label = row['label']       # What user said it should be
            
            if ai_pred not in confusion_matrix:
                confusion_matrix[ai_pred] = {}
            
            if correct_label not in confusion_matrix[ai_pred]:
                confusion_matrix[ai_pred][correct_label] = 0
            
            confusion_matrix[ai_pred][correct_label] += 1
        
        # Convert to percentage and identify top errors
        common_errors = []
        for ai_pred, corrections in confusion_matrix.items():
            total = sum(corrections.values())
            for correct_label, count in corrections.items():
                if ai_pred != correct_label:  # Only misclassifications
                    error_rate = count / total
                    common_errors.append({
                        'ai_predicted': ai_pred,
                        'should_be': correct_label,
                        'error_count': count,
                        'error_rate': error_rate
                    })
        
        # Sort by error rate
        common_errors.sort(key=lambda x: x['error_rate'], reverse=True)
        
        return common_errors[:10]  # Top 10 errors
    
    def find_difficult_cases(self, df):
        """Identify feature patterns that lead to low confidence or errors"""
        
        # Cases with low confidence or user corrections
        difficult = df[
            (df['confidence'] < 0.7) | 
            (df['is_user_corrected'] == True)
        ]
        
        if len(difficult) == 0:
            return {"message": "No difficult cases found"}
        
        # Analyze feature statistics for difficult cases
        feature_analysis = {}
        
        for i, feature_name in enumerate(self.processor.feature_names):
            difficult_values = [row['features'][i] for _, row in difficult.iterrows()]
            all_values = [row['features'][i] for _, row in df.iterrows()]
            
            feature_analysis[feature_name] = {
                'difficult_mean': np.mean(difficult_values),
                'difficult_std': np.std(difficult_values),
                'overall_mean': np.mean(all_values),
                'overall_std': np.std(all_values),
                'difference': abs(np.mean(difficult_values) - np.mean(all_values))
            }
        
        # Sort by difference to find most problematic features
        problematic_features = sorted(
            feature_analysis.items(),
            key=lambda x: x[1]['difference'],
            reverse=True
        )
        
        return problematic_features[:10]  # Top 10 problematic features
```

### 3. Model Training Pipeline

```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import classification_report, confusion_matrix
import coremltools as ct

class ModelTrainer:
    def __init__(self):
        self.analyzer = SwingAnalyzer()
        self.current_model = None
        self.training_history = []
    
    def prepare_training_data(self, raw_data):
        """Prepare data for model training"""
        
        processed_data = []
        
        for data_point in raw_data:
            processed = self.analyzer.processor.process_incoming_data(data_point)
            if processed:
                processed_data.append(processed)
        
        if len(processed_data) < 50:
            raise ValueError(f"Insufficient training data: {len(processed_data)} samples")
        
        # Convert to training format
        X = np.array([dp['features'] for dp in processed_data])
        y = np.array([dp['label'] for dp in processed_data])
        
        # Get sample weights (higher weight for user-corrected samples)
        weights = np.array([
            2.0 if dp['is_user_corrected'] else 1.0 
            for dp in processed_data
        ])
        
        return X, y, weights, processed_data
    
    def train_model(self, training_data, validation_data=None):
        """Train new model with collected data"""
        
        print(f"Training with {len(training_data)} samples...")
        
        # Prepare data
        X, y, weights, processed_data = self.prepare_training_data(training_data)
        
        # Analyze data before training
        analysis = self.analyzer.analyze_prediction_patterns(processed_data)
        print("Training Data Analysis:")
        print(f"- Confidence vs Accuracy: {len(analysis['confidence_accuracy'])} ranges analyzed")
        print(f"- Common Errors: {len(analysis['confusion_patterns'])} error patterns found")
        
        # Split data
        X_train, X_test, y_train, y_test, w_train, w_test = train_test_split(
            X, y, weights, test_size=0.2, random_state=42, stratify=y
        )
        
        # Train model with class balancing
        model = RandomForestClassifier(
            n_estimators=200,
            max_depth=15,
            min_samples_split=5,
            min_samples_leaf=2,
            class_weight='balanced',  # Handle class imbalance
            random_state=42
        )
        
        # Fit with sample weights
        model.fit(X_train, y_train, sample_weight=w_train)
        
        # Evaluate model
        train_score = model.score(X_train, y_train, sample_weight=w_train)
        test_score = model.score(X_test, y_test, sample_weight=w_test)
        
        # Cross-validation
        cv_scores = cross_val_score(model, X, y, cv=5, scoring='accuracy')
        
        # Detailed evaluation
        y_pred = model.predict(X_test)
        report = classification_report(y_test, y_pred, output_dict=True)
        conf_matrix = confusion_matrix(y_test, y_pred)
        
        # Feature importance analysis
        feature_importance = self.analyze_feature_importance(model)
        
        training_results = {
            'train_accuracy': train_score,
            'test_accuracy': test_score,
            'cv_mean': cv_scores.mean(),
            'cv_std': cv_scores.std(),
            'classification_report': report,
            'confusion_matrix': conf_matrix.tolist(),
            'feature_importance': feature_importance,
            'training_samples': len(X_train),
            'test_samples': len(X_test),
            'user_corrected_samples': sum(weights > 1.0)
        }
        
        # Save training history
        self.training_history.append({
            'timestamp': datetime.now(),
            'results': training_results
        })
        
        self.current_model = model
        
        return training_results
    
    def analyze_feature_importance(self, model):
        """Analyze which features are most important for classification"""
        
        importances = model.feature_importances_
        feature_names = self.analyzer.processor.feature_names
        
        # Sort features by importance
        feature_importance = [
            {
                'feature': feature_names[i],
                'importance': float(importances[i]),
                'rank': i + 1
            }
            for i in range(len(feature_names))
        ]
        
        feature_importance.sort(key=lambda x: x['importance'], reverse=True)
        
        # Add ranks
        for i, feature in enumerate(feature_importance):
            feature['rank'] = i + 1
        
        return feature_importance
    
    def convert_to_coreml(self, model, version):
        """Convert trained model to Core ML format"""
        
        if model is None:
            raise ValueError("No trained model available")
        
        # Create Core ML model
        coreml_model = ct.converters.sklearn.convert(
            model,
            input_features=self.analyzer.processor.feature_names,
            output_feature_names=['swing_classification'],
            class_labels=self.analyzer.processor.valid_labels
        )
        
        # Add metadata
        coreml_model.short_description = "Golf Swing Classification Model"
        coreml_model.input_description['features'] = "35 biomechanical swing features"
        coreml_model.output_description['swing_classification'] = "Predicted swing type"
        coreml_model.version = version
        
        return coreml_model
    
    def should_retrain(self, new_data_count, error_rate_threshold=0.15):
        """Decide if model should be retrained"""
        
        if len(self.training_history) == 0:
            return True  # No previous training
        
        last_training = self.training_history[-1]
        
        # Retrain if:
        # 1. Significant amount of new data
        # 2. Error rate is above threshold
        # 3. Enough user corrections accumulated
        
        should_retrain_reasons = []
        
        if new_data_count >= 1000:
            should_retrain_reasons.append("Sufficient new data")
        
        if last_training['results']['test_accuracy'] < (1 - error_rate_threshold):
            should_retrain_reasons.append("Accuracy below threshold")
        
        return should_retrain_reasons
```

### 4. Production Deployment Pipeline

```python
import os
import hashlib
import shutil
from datetime import datetime

class ModelDeployment:
    def __init__(self, models_directory="/opt/golfai/models"):
        self.models_dir = models_directory
        self.trainer = ModelTrainer()
        
        # Ensure directories exist
        os.makedirs(self.models_dir, exist_ok=True)
    
    def deploy_new_model(self, training_data, min_accuracy=0.85):
        """Train and deploy new model if it meets quality standards"""
        
        print("Starting model training and deployment process...")
        
        # Train model
        results = self.trainer.train_model(training_data)
        
        # Check if model meets quality standards
        if results['test_accuracy'] < min_accuracy:
            print(f"Model accuracy {results['test_accuracy']:.3f} below threshold {min_accuracy}")
            return None
        
        # Generate version
        version = self.generate_version()
        
        # Convert to Core ML
        coreml_model = self.trainer.convert_to_coreml(
            self.trainer.current_model, 
            version
        )
        
        # Save model file
        model_filename = f"SwingAnalysisModel_{version}.mlmodel"
        model_path = os.path.join(self.models_dir, model_filename)
        coreml_model.save(model_path)
        
        # Calculate file info
        file_size = os.path.getsize(model_path)
        checksum = self.calculate_checksum(model_path)
        
        # Generate release notes
        release_notes = self.generate_release_notes(results)
        
        # Update database with new model info
        model_info = {
            'version': version,
            'file_path': model_path,
            'file_size': file_size,
            'checksum': checksum,
            'release_notes': release_notes,
            'training_results': results,
            'is_active': True
        }
        
        # Save model metadata
        self.save_model_metadata(model_info)
        
        print(f"✅ New model {version} deployed successfully!")
        print(f"📊 Test Accuracy: {results['test_accuracy']:.3f}")
        print(f"🔍 Training Samples: {results['training_samples']}")
        print(f"✏️ User Corrections: {results['user_corrected_samples']}")
        
        return model_info
    
    def generate_version(self):
        """Generate semantic version for new model"""
        current_time = datetime.now()
        return f"1.{current_time.year}{current_time.month:02d}.{current_time.day:02d}"
    
    def calculate_checksum(self, file_path):
        """Calculate SHA256 checksum"""
        sha256_hash = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256_hash.update(chunk)
        return sha256_hash.hexdigest()
    
    def generate_release_notes(self, training_results):
        """Generate human-readable release notes"""
        
        accuracy = training_results['test_accuracy']
        samples = training_results['training_samples']
        corrections = training_results['user_corrected_samples']
        
        # Get top important features
        top_features = training_results['feature_importance'][:3]
        feature_names = [f['feature'].replace('_', ' ').title() for f in top_features]
        
        notes = f"""Model Update v{self.generate_version()}
        
🎯 Accuracy: {accuracy:.1%}
📊 Trained on {samples:,} swing samples
✏️ Incorporated {corrections} user corrections

🧠 Key Improvements:
- Enhanced analysis of {feature_names[0]}
- Better detection of {feature_names[1]} 
- Improved {feature_names[2]} assessment

This model learns from real user swings and corrections to provide more accurate swing analysis."""
        
        return notes
    
    def save_model_metadata(self, model_info):
        """Save model metadata to JSON file"""
        
        metadata_path = os.path.join(self.models_dir, "model_metadata.json")
        
        # Load existing metadata
        if os.path.exists(metadata_path):
            with open(metadata_path, 'r') as f:
                metadata = json.load(f)
        else:
            metadata = {'models': []}
        
        # Add new model
        model_info['deployed_at'] = datetime.now().isoformat()
        metadata['models'].append(model_info)
        
        # Keep only last 10 models in metadata
        metadata['models'] = metadata['models'][-10:]
        
        # Save updated metadata
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2, default=str)
```

### 5. Automated Training Script

```python
#!/usr/bin/env python3
"""
Automated Model Training Script
Run this script periodically to check for new data and retrain models
"""

import sys
import logging
from datetime import datetime, timedelta

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/golfai/training.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

def main():
    """Main training pipeline"""
    
    try:
        # Load new training data from database
        training_data = load_new_training_data()
        
        if len(training_data) < 100:
            logging.info(f"Insufficient new data: {len(training_data)} samples")
            return
        
        # Initialize deployment pipeline
        deployment = ModelDeployment()
        
        # Check if retraining is needed
        should_retrain = deployment.trainer.should_retrain(len(training_data))
        
        if not should_retrain:
            logging.info("Retraining not required at this time")
            return
        
        logging.info(f"Starting training with {len(training_data)} samples...")
        
        # Train and deploy new model
        model_info = deployment.deploy_new_model(training_data)
        
        if model_info:
            logging.info(f"✅ Successfully deployed model {model_info['version']}")
            
            # Mark training data as processed
            mark_data_as_processed(training_data)
            
            # Send notification (email, Slack, etc.)
            send_deployment_notification(model_info)
        else:
            logging.warning("❌ Model did not meet quality standards for deployment")
        
    except Exception as e:
        logging.error(f"Training pipeline failed: {str(e)}")
        raise

if __name__ == "__main__":
    main()
```

This comprehensive guide provides everything needed to understand, process, and utilize the training data from the Golf Swing AI iOS app to continuously improve the AI models.