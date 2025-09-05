# API Integration Guide for Golf Swing AI Server

This guide details how to implement the server-side API endpoints to receive and process data from the Golf Swing AI iOS app for centralized model improvement.

## 🎯 Overview

The iOS app collects anonymous swing analysis data and sends it to your server at `https://golfai.duckdns.org:8443`. This data is used to continuously improve AI models that benefit all users.

## 📊 Data Flow

```
iOS App → API Server → Training Database → Model Retraining → Enhanced Models → App Store Updates
```

## 🔌 Required API Endpoints

### 1. Upload Training Data

**Endpoint**: `POST /api/model/training-data`

**Purpose**: Receive swing analysis data from iOS app

**Request Headers**:
```
Content-Type: application/json
User-Agent: GolfSwingAI-iOS/1.0.0
```

**Request Body**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2024-01-15T10:30:00Z",
  "features": [
    45.2,    // spine_angle
    32.1,    // knee_flexion
    0.6,     // weight_distribution
    15.4,    // arm_hang_angle
    24.8,    // stance_width
    92.3,    // max_shoulder_turn
    48.7,    // hip_turn_at_top
    43.6,    // x_factor
    52.1,    // swing_plane_angle
    85.3,    // arm_extension
    0.75,    // weight_shift
    78.2,    // wrist_hinge
    3.2,     // backswing_tempo
    2.1,     // head_movement
    89.4,    // knee_stability
    1.8,     // transition_tempo
    65.7,    // hip_lead
    0.82,    // weight_transfer_rate
    72.3,    // wrist_timing
    87.6,    // sequence_efficiency
    145.2,   // hip_rotation_speed
    182.7,   // shoulder_rotation_speed
    2.3,     // club_path_angle
    -1.2,    // attack_angle
    78.9,    // release_timing
    91.5,    // left_side_stability
    1.9,     // downswing_tempo
    85.7,    // power_generation
    88.4,    // impact_position
    92.1,    // extension_through_impact
    86.3,    // follow_through_balance
    89.7,    // finish_quality
    2.8,     // overall_tempo
    87.2,    // rhythm_consistency
    84.6     // swing_efficiency
  ],
  "modelPrediction": "good_swing",
  "modelConfidence": 0.87,
  "userFeedback": {
    "isCorrect": false,
    "correctedLabel": "too_steep",
    "confidence": 4,
    "comments": "Backswing was too vertical",
    "submissionDate": "2024-01-15T10:32:00Z"
  },
  "swingMetadata": {
    "videoDuration": 4.2,
    "deviceModel": "iPhone 15 Pro",
    "appVersion": "1.0.0",
    "analysisDate": "2024-01-15T10:30:00Z",
    "userSkillLevel": "intermediate",
    "clubType": "driver",
    "practiceOrRound": "practice"
  },
  "isFromLocalModel": true,
  "modelVersion": "1.0-local"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Training data received successfully",
  "dataPointId": "dp_550e8400e29b41d4a716446655440000"
}
```

**Error Response**:
```json
{
  "success": false,
  "error": "validation_failed",
  "message": "Invalid features array length. Expected 35, got 32"
}
```

### 2. Check for Model Updates

**Endpoint**: `GET /api/model/updates`

**Purpose**: Allow iOS app to check for new model versions

**Query Parameters**:
- `currentVersion` (string): Current model version (e.g., "1.0-local")
- `platform` (string): Always "ios"

**Request Example**:
```
GET /api/model/updates?currentVersion=1.0-local&platform=ios
```

**Response**:
```json
{
  "hasUpdate": true,
  "modelVersion": "1.2.0",
  "downloadURL": "https://golfai.duckdns.org:8443/api/model/download/1.2.0",
  "releaseNotes": "Improved accuracy for steep swing detection. Better tempo analysis.",
  "isRequired": false,
  "fileSize": 15728640,
  "checksum": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
}
```

**No Update Response**:
```json
{
  "hasUpdate": false,
  "currentVersion": "1.0-local",
  "message": "You have the latest model version"
}
```

### 3. Download Model Update

**Endpoint**: `GET /api/model/download/{version}`

**Purpose**: Serve Core ML model files for app updates

**Request Example**:
```
GET /api/model/download/1.2.0
```

**Response Headers**:
```
Content-Type: application/octet-stream
Content-Disposition: attachment; filename="SwingAnalysisModel_1.2.0.mlmodel"
Content-Length: 15728640
```

**Response**: Binary Core ML model file

## 🗄️ Database Schema

### Training Data Table

```sql
CREATE TABLE training_data (
    id VARCHAR(36) PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    features JSON NOT NULL,                    -- Array of 35 float values
    model_prediction VARCHAR(50) NOT NULL,     -- 'good_swing', 'too_steep', 'too_flat'
    model_confidence DECIMAL(5,4) NOT NULL,    -- 0.0000 to 1.0000
    user_feedback JSON NULL,                   -- User correction data
    swing_metadata JSON NOT NULL,             -- Device and context info
    is_from_local_model BOOLEAN NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE
);

-- Indexes for efficient querying
CREATE INDEX idx_timestamp ON training_data(timestamp);
CREATE INDEX idx_model_prediction ON training_data(model_prediction);
CREATE INDEX idx_confidence ON training_data(model_confidence);
CREATE INDEX idx_processed ON training_data(processed);
CREATE INDEX idx_feedback ON training_data((JSON_EXTRACT(user_feedback, '$.isCorrect')));
```

### Model Versions Table

```sql
CREATE TABLE model_versions (
    version VARCHAR(20) PRIMARY KEY,
    file_path VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    checksum VARCHAR(64) NOT NULL,
    release_notes TEXT,
    is_required BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT FALSE
);
```

## 🐍 Python Implementation Example

### Flask API Server

```python
from flask import Flask, request, jsonify, send_file
import json
import mysql.connector
from datetime import datetime
import hashlib
import os

app = Flask(__name__)

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'golfai_user',
    'password': 'secure_password',
    'database': 'golfai_training'
}

@app.route('/api/model/training-data', methods=['POST'])
def upload_training_data():
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['id', 'timestamp', 'features', 'modelPrediction', 
                          'modelConfidence', 'swingMetadata', 'isFromLocalModel', 
                          'modelVersion']
        
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'success': False,
                    'error': 'missing_field',
                    'message': f'Required field missing: {field}'
                }), 400
        
        # Validate features array
        if len(data['features']) != 35:
            return jsonify({
                'success': False,
                'error': 'validation_failed',
                'message': f'Invalid features array length. Expected 35, got {len(data["features"])}'
            }), 400
        
        # Store in database
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        query = """
        INSERT INTO training_data 
        (id, timestamp, features, model_prediction, model_confidence, 
         user_feedback, swing_metadata, is_from_local_model, model_version)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        values = (
            data['id'],
            datetime.fromisoformat(data['timestamp'].replace('Z', '+00:00')),
            json.dumps(data['features']),
            data['modelPrediction'],
            data['modelConfidence'],
            json.dumps(data.get('userFeedback')),
            json.dumps(data['swingMetadata']),
            data['isFromLocalModel'],
            data['modelVersion']
        )
        
        cursor.execute(query, values)
        conn.commit()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Training data received successfully',
            'dataPointId': f"dp_{data['id'].replace('-', '')}"
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': 'server_error',
            'message': str(e)
        }), 500

@app.route('/api/model/updates', methods=['GET'])
def check_model_updates():
    try:
        current_version = request.args.get('currentVersion', '1.0-local')
        platform = request.args.get('platform', 'ios')
        
        # Get latest model version from database
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        cursor.execute("""
        SELECT version, file_path, file_size, checksum, release_notes, is_required
        FROM model_versions 
        WHERE is_active = TRUE 
        ORDER BY created_at DESC 
        LIMIT 1
        """)
        
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not result or result[0] == current_version:
            return jsonify({
                'hasUpdate': False,
                'currentVersion': current_version,
                'message': 'You have the latest model version'
            })
        
        version, file_path, file_size, checksum, release_notes, is_required = result
        
        return jsonify({
            'hasUpdate': True,
            'modelVersion': version,
            'downloadURL': f'https://golfai.duckdns.org:8443/api/model/download/{version}',
            'releaseNotes': release_notes,
            'isRequired': is_required,
            'fileSize': file_size,
            'checksum': f'sha256:{checksum}'
        })
        
    except Exception as e:
        return jsonify({
            'error': 'server_error',
            'message': str(e)
        }), 500

@app.route('/api/model/download/<version>', methods=['GET'])
def download_model(version):
    try:
        # Get model file path from database
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        cursor.execute("""
        SELECT file_path, file_size, checksum
        FROM model_versions 
        WHERE version = %s
        """, (version,))
        
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not result:
            return jsonify({
                'error': 'not_found',
                'message': f'Model version {version} not found'
            }), 404
        
        file_path, file_size, checksum = result
        
        if not os.path.exists(file_path):
            return jsonify({
                'error': 'file_not_found',
                'message': 'Model file not found on server'
            }), 404
        
        return send_file(
            file_path,
            as_attachment=True,
            download_name=f'SwingAnalysisModel_{version}.mlmodel',
            mimetype='application/octet-stream'
        )
        
    except Exception as e:
        return jsonify({
            'error': 'server_error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8443, ssl_context='adhoc')
```

## 🧠 Model Training Pipeline

### Data Processing Script

```python
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
import coremltools as ct
import mysql.connector
import json

def load_training_data():
    """Load training data from database"""
    conn = mysql.connector.connect(**DB_CONFIG)
    
    query = """
    SELECT features, model_prediction, user_feedback, model_confidence
    FROM training_data 
    WHERE processed = FALSE
    """
    
    df = pd.read_sql(query, conn)
    conn.close()
    
    return df

def prepare_training_data(df):
    """Prepare data for model training"""
    X = []
    y = []
    
    for _, row in df.iterrows():
        features = json.loads(row['features'])
        
        # Use corrected label if user provided feedback
        if row['user_feedback'] and not json.loads(row['user_feedback'])['isCorrect']:
            label = json.loads(row['user_feedback'])['correctedLabel']
        else:
            label = row['model_prediction']
        
        X.append(features)
        y.append(label)
    
    return np.array(X), np.array(y)

def train_model():
    """Train improved model with collected data"""
    # Load data
    df = load_training_data()
    print(f"Loaded {len(df)} training samples")
    
    if len(df) < 100:
        print("Not enough data for retraining (minimum 100 samples)")
        return
    
    # Prepare training data
    X, y = prepare_training_data(df)
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    # Train model
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        random_state=42
    )
    
    model.fit(X_train, y_train)
    
    # Evaluate
    train_accuracy = model.score(X_train, y_train)
    test_accuracy = model.score(X_test, y_test)
    
    print(f"Train accuracy: {train_accuracy:.3f}")
    print(f"Test accuracy: {test_accuracy:.3f}")
    
    # Convert to Core ML
    feature_names = [
        'spine_angle', 'knee_flexion', 'weight_distribution', 'arm_hang_angle',
        'stance_width', 'max_shoulder_turn', 'hip_turn_at_top', 'x_factor',
        'swing_plane_angle', 'arm_extension', 'weight_shift', 'wrist_hinge',
        'backswing_tempo', 'head_movement', 'knee_stability', 'transition_tempo',
        'hip_lead', 'weight_transfer_rate', 'wrist_timing', 'sequence_efficiency',
        'hip_rotation_speed', 'shoulder_rotation_speed', 'club_path_angle',
        'attack_angle', 'release_timing', 'left_side_stability', 'downswing_tempo',
        'power_generation', 'impact_position', 'extension_through_impact',
        'follow_through_balance', 'finish_quality', 'overall_tempo',
        'rhythm_consistency', 'swing_efficiency'
    ]
    
    # Convert to Core ML model
    coreml_model = ct.converters.sklearn.convert(
        model,
        input_features=feature_names,
        output_feature_names=['swing_classification']
    )
    
    # Save model
    version = f"1.{int(time.time())}.0"
    model_path = f"models/SwingAnalysisModel_{version}.mlmodel"
    coreml_model.save(model_path)
    
    # Update database
    file_size = os.path.getsize(model_path)
    checksum = calculate_checksum(model_path)
    
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    # Deactivate old models
    cursor.execute("UPDATE model_versions SET is_active = FALSE")
    
    # Add new model
    cursor.execute("""
    INSERT INTO model_versions 
    (version, file_path, file_size, checksum, release_notes, is_active)
    VALUES (%s, %s, %s, %s, %s, %s)
    """, (
        version,
        model_path,
        file_size,
        checksum,
        f"Improved accuracy: {test_accuracy:.1%}. Trained on {len(df)} samples.",
        True
    ))
    
    # Mark data as processed
    cursor.execute("UPDATE training_data SET processed = TRUE")
    
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"New model version {version} created and deployed")

def calculate_checksum(file_path):
    """Calculate SHA256 checksum of file"""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()

if __name__ == '__main__':
    train_model()
```

## 📈 Data Analysis Queries

### Useful SQL Queries for Data Analysis

```sql
-- Training data statistics
SELECT 
    COUNT(*) as total_samples,
    COUNT(CASE WHEN user_feedback IS NOT NULL THEN 1 END) as feedback_samples,
    AVG(model_confidence) as avg_confidence,
    DATE(timestamp) as date
FROM training_data 
GROUP BY DATE(timestamp)
ORDER BY date DESC;

-- Prediction accuracy analysis
SELECT 
    model_prediction,
    COUNT(*) as total,
    COUNT(CASE WHEN JSON_EXTRACT(user_feedback, '$.isCorrect') = true THEN 1 END) as correct,
    COUNT(CASE WHEN JSON_EXTRACT(user_feedback, '$.isCorrect') = false THEN 1 END) as incorrect,
    AVG(model_confidence) as avg_confidence
FROM training_data 
WHERE user_feedback IS NOT NULL
GROUP BY model_prediction;

-- User correction patterns
SELECT 
    model_prediction as ai_prediction,
    JSON_EXTRACT(user_feedback, '$.correctedLabel') as user_correction,
    COUNT(*) as occurrences,
    AVG(model_confidence) as avg_confidence
FROM training_data 
WHERE JSON_EXTRACT(user_feedback, '$.isCorrect') = false
GROUP BY model_prediction, JSON_EXTRACT(user_feedback, '$.correctedLabel')
ORDER BY occurrences DESC;

-- Device and app version statistics
SELECT 
    JSON_EXTRACT(swing_metadata, '$.deviceModel') as device,
    JSON_EXTRACT(swing_metadata, '$.appVersion') as app_version,
    COUNT(*) as samples
FROM training_data 
GROUP BY device, app_version
ORDER BY samples DESC;
```

## 🔐 Security Considerations

### API Security

```python
# Rate limiting
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

# Apply to upload endpoint
@app.route('/api/model/training-data', methods=['POST'])
@limiter.limit("10 per minute")  # Limit uploads
def upload_training_data():
    # ... existing code
```

### Data Validation

```python
def validate_training_data(data):
    """Validate incoming training data"""
    
    # Check features array
    features = data.get('features', [])
    if len(features) != 35:
        raise ValueError(f"Invalid features length: {len(features)}")
    
    # Validate feature ranges (example ranges)
    feature_ranges = {
        0: (0, 90),     # spine_angle
        1: (0, 90),     # knee_flexion
        2: (0, 1),      # weight_distribution
        # ... define ranges for all 35 features
    }
    
    for i, value in enumerate(features):
        if i in feature_ranges:
            min_val, max_val = feature_ranges[i]
            if not (min_val <= value <= max_val):
                raise ValueError(f"Feature {i} out of range: {value}")
    
    # Validate prediction labels
    valid_predictions = ['good_swing', 'too_steep', 'too_flat']
    if data['modelPrediction'] not in valid_predictions:
        raise ValueError(f"Invalid prediction: {data['modelPrediction']}")
    
    # Validate confidence score
    confidence = data['modelConfidence']
    if not (0 <= confidence <= 1):
        raise ValueError(f"Invalid confidence: {confidence}")
    
    return True
```

## 📊 Monitoring and Analytics

### Key Metrics to Track

1. **Data Collection Rate**: Samples per day/hour
2. **Feedback Rate**: Percentage of users providing corrections
3. **Model Accuracy**: Validation accuracy over time
4. **Prediction Distribution**: Balance of different classifications
5. **Confidence Trends**: Average confidence scores
6. **Error Patterns**: Common prediction mistakes

### Dashboard Queries

```sql
-- Daily collection metrics
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as total_samples,
    COUNT(DISTINCT JSON_EXTRACT(swing_metadata, '$.deviceModel')) as unique_devices,
    AVG(model_confidence) as avg_confidence,
    COUNT(CASE WHEN user_feedback IS NOT NULL THEN 1 END) as feedback_count
FROM training_data 
WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(timestamp)
ORDER BY date DESC;
```

This comprehensive guide provides everything needed to implement the server-side infrastructure for receiving, processing, and utilizing the training data from the Golf Swing AI iOS app.