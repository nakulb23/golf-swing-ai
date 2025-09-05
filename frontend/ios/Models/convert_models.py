#!/usr/bin/env python3
"""
PyTorch to Core ML Model Conversion Script
Converts Golf Swing AI models for iOS deployment
"""

import torch
import torch.nn as nn
import coremltools as ct
import numpy as np
import pickle
import os
import json
from pathlib import Path

# Physics-Based Neural Network Architecture (matching your server)
class PhysicsBasedModel(nn.Module):
    def __init__(self, input_size=35, num_classes=3):
        super(PhysicsBasedModel, self).__init__()
        self.fc1 = nn.Linear(input_size, 64)
        self.fc2 = nn.Linear(64, 32)
        self.fc3 = nn.Linear(32, 16)
        self.fc4 = nn.Linear(16, num_classes)
        self.relu = nn.ReLU()
        self.dropout1 = nn.Dropout(0.3)
        self.dropout2 = nn.Dropout(0.2)
        
    def forward(self, x):
        x = self.relu(self.fc1(x))
        x = self.dropout1(x)
        x = self.relu(self.fc2(x))
        x = self.dropout2(x)
        x = self.relu(self.fc3(x))
        x = self.fc4(x)
        return x

# Enhanced LSTM Model Architecture
class EnhancedLSTMModel(nn.Module):
    def __init__(self, input_size=35, hidden_size=128, num_layers=2, num_classes=3):
        super(EnhancedLSTMModel, self).__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        
        # Bidirectional LSTM
        self.lstm = nn.LSTM(input_size, hidden_size, num_layers, 
                           batch_first=True, bidirectional=True, dropout=0.2)
        
        # Multi-head attention (simplified for Core ML compatibility)
        self.attention = nn.MultiheadAttention(hidden_size * 2, num_heads=4, batch_first=True)
        
        # Classification head
        self.classifier = nn.Sequential(
            nn.Linear(hidden_size * 2, 64),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(64, num_classes)
        )
        
        # Phase detection head
        self.phase_detector = nn.Sequential(
            nn.Linear(hidden_size * 2, 32),
            nn.ReLU(),
            nn.Linear(32, 6)  # 6 swing phases
        )
        
        # Confidence estimation head
        self.confidence_estimator = nn.Sequential(
            nn.Linear(hidden_size * 2, 16),
            nn.ReLU(),
            nn.Linear(16, 1),
            nn.Sigmoid()
        )
    
    def forward(self, x):
        # LSTM forward pass
        lstm_out, _ = self.lstm(x)
        
        # Attention mechanism
        attn_out, _ = self.attention(lstm_out, lstm_out, lstm_out)
        
        # Use last time step for classification
        final_hidden = attn_out[:, -1, :]
        
        # Multiple outputs
        classification = self.classifier(final_hidden)
        phase = self.phase_detector(final_hidden)
        confidence = self.confidence_estimator(final_hidden)
        
        return classification, phase, confidence

def download_models_from_server():
    """Download models from your server to convert them"""
    import requests
    
    server_url = "https://golfai.duckdns.org:8443"
    models_to_download = [
        "physics_based_model.pt",
        "physics_scaler.pkl", 
        "physics_label_encoder.pkl",
        "enhanced_temporal_model.pt"  # if available
    ]
    
    os.makedirs("server_models", exist_ok=True)
    
    for model_file in models_to_download:
        try:
            print(f"📥 Downloading {model_file}...")
            response = requests.get(f"{server_url}/models/{model_file}", verify=False)
            if response.status_code == 200:
                with open(f"server_models/{model_file}", "wb") as f:
                    f.write(response.content)
                print(f"✅ Downloaded {model_file}")
            else:
                print(f"❌ Failed to download {model_file}: {response.status_code}")
        except Exception as e:
            print(f"❌ Error downloading {model_file}: {e}")

def convert_physics_model():
    """Convert the physics-based model to Core ML"""
    print("🔄 Converting Physics-Based Model to Core ML...")
    
    # Create model instance
    model = PhysicsBasedModel(input_size=35, num_classes=3)
    
    # Load trained weights (if available)
    model_path = "server_models/physics_based_model.pt"
    if os.path.exists(model_path):
        try:
            state_dict = torch.load(model_path, map_location='cpu')
            model.load_state_dict(state_dict)
            print("✅ Loaded trained weights")
        except Exception as e:
            print(f"⚠️ Using random weights (couldn't load trained model): {e}")
    else:
        print("⚠️ Using random weights (no trained model found)")
    
    model.eval()
    
    # Create example input (35 physics features)
    example_input = torch.randn(1, 35)
    
    # Trace the model
    traced_model = torch.jit.trace(model, example_input)
    
    # Convert to Core ML with metadata
    coreml_model = ct.convert(
        traced_model,
        inputs=[ct.TensorType(name="physics_features", shape=(1, 35))],
        outputs=[ct.TensorType(name="swing_classification")],
        minimum_deployment_target=ct.target.iOS15,
        compute_units=ct.ComputeUnit.CPU_ONLY  # Ensure CPU compatibility
    )
    
    # Add model metadata
    coreml_model.author = "Golf Swing AI"
    coreml_model.short_description = "Golf swing physics-based classifier"
    coreml_model.version = "1.0"
    
    # Define class labels
    class_labels = ["good_swing", "too_steep", "too_flat"]
    coreml_model.user_defined_metadata["classes"] = json.dumps(class_labels)
    
    # Save the model
    output_path = "CoreML/SwingAnalysisModel.mlmodel"
    coreml_model.save(output_path)
    print(f"✅ Saved Physics Model to {output_path}")
    
    return coreml_model

def convert_lstm_model():
    """Convert the LSTM model to Core ML (simplified version)"""
    print("🔄 Converting LSTM Model to Core ML...")
    
    # For Core ML compatibility, we'll create a simplified version
    class SimplifiedLSTM(nn.Module):
        def __init__(self):
            super(SimplifiedLSTM, self).__init__()
            self.lstm = nn.LSTM(35, 64, 1, batch_first=True)
            self.classifier = nn.Linear(64, 3)
            
        def forward(self, x):
            lstm_out, _ = self.lstm(x)
            return self.classifier(lstm_out[:, -1, :])
    
    model = SimplifiedLSTM()
    model.eval()
    
    # Example input: sequence of 30 frames with 35 features each
    example_input = torch.randn(1, 30, 35)
    
    try:
        traced_model = torch.jit.trace(model, example_input)
        
        coreml_model = ct.convert(
            traced_model,
            inputs=[ct.TensorType(name="feature_sequence", shape=(1, 30, 35))],
            outputs=[ct.TensorType(name="temporal_classification")],
            minimum_deployment_target=ct.target.iOS15,
            compute_units=ct.ComputeUnit.CPU_ONLY
        )
        
        coreml_model.author = "Golf Swing AI"
        coreml_model.short_description = "Temporal golf swing analysis"
        coreml_model.version = "1.0"
        
        output_path = "CoreML/SwingLSTMModel.mlmodel"
        coreml_model.save(output_path)
        print(f"✅ Saved LSTM Model to {output_path}")
        
    except Exception as e:
        print(f"❌ LSTM conversion failed: {e}")
        print("💡 Using physics model only for now")

def create_ball_tracking_model():
    """Create a simplified ball tracking model for Core ML"""
    print("🔄 Creating Ball Tracking Model...")
    
    # Simple CNN for ball detection
    class BallDetector(nn.Module):
        def __init__(self):
            super(BallDetector, self).__init__()
            self.conv1 = nn.Conv2d(3, 32, 3, padding=1)
            self.conv2 = nn.Conv2d(32, 64, 3, padding=1)
            self.conv3 = nn.Conv2d(64, 128, 3, padding=1)
            self.pool = nn.MaxPool2d(2, 2)
            self.global_pool = nn.AdaptiveAvgPool2d(1)
            
            # Ball position predictor (x, y, confidence)
            self.predictor = nn.Sequential(
                nn.Linear(128, 64),
                nn.ReLU(),
                nn.Dropout(0.2),
                nn.Linear(64, 3)  # x, y, confidence
            )
        
        def forward(self, x):
            x = self.pool(torch.relu(self.conv1(x)))
            x = self.pool(torch.relu(self.conv2(x)))
            x = self.pool(torch.relu(self.conv3(x)))
            x = self.global_pool(x)
            x = x.view(x.size(0), -1)
            return self.predictor(x)
    
    model = BallDetector()
    model.eval()
    
    # Example input: 224x224 RGB image
    example_input = torch.randn(1, 3, 224, 224)
    
    try:
        traced_model = torch.jit.trace(model, example_input)
        
        coreml_model = ct.convert(
            traced_model,
            inputs=[ct.ImageType(name="input_image", shape=(1, 3, 224, 224))],
            outputs=[ct.TensorType(name="ball_position")],
            minimum_deployment_target=ct.target.iOS15,
            compute_units=ct.ComputeUnit.CPU_ONLY
        )
        
        coreml_model.author = "Golf Swing AI"
        coreml_model.short_description = "Golf ball detection and tracking"
        coreml_model.version = "1.0"
        
        output_path = "CoreML/BallTrackingModel.mlmodel"
        coreml_model.save(output_path)
        print(f"✅ Saved Ball Tracking Model to {output_path}")
        
    except Exception as e:
        print(f"❌ Ball tracking model creation failed: {e}")

def create_feature_scaler():
    """Create a Core ML model for feature normalization"""
    print("🔄 Creating Feature Scaler...")
    
    # Load scaler if available, otherwise create default
    scaler_path = "server_models/physics_scaler.pkl"
    if os.path.exists(scaler_path):
        try:
            with open(scaler_path, 'rb') as f:
                scaler = pickle.load(f)
            mean_values = scaler.mean_
            scale_values = scaler.scale_
            print("✅ Loaded scaler parameters from server")
        except Exception as e:
            print(f"⚠️ Using default scaler: {e}")
            mean_values = np.zeros(35)
            scale_values = np.ones(35)
    else:
        print("⚠️ Using default scaler (no trained scaler found)")
        mean_values = np.zeros(35)
        scale_values = np.ones(35)
    
    # Create normalization metadata
    scaler_metadata = {
        "mean": mean_values.tolist(),
        "scale": scale_values.tolist()
    }
    
    # Save scaler metadata for iOS
    with open("CoreML/scaler_metadata.json", "w") as f:
        json.dump(scaler_metadata, f, indent=2)
    
    print("✅ Created scaler metadata")

def main():
    """Main conversion process"""
    print("🚀 Starting PyTorch to Core ML conversion...")
    
    # Create output directory
    os.makedirs("CoreML", exist_ok=True)
    
    try:
        # Step 1: Download models from server (optional)
        download_models_from_server()
        
        # Step 2: Convert physics-based model
        convert_physics_model()
        
        # Step 3: Convert LSTM model (simplified)
        convert_lstm_model()
        
        # Step 4: Create ball tracking model
        create_ball_tracking_model()
        
        # Step 5: Create feature scaler metadata
        create_feature_scaler()
        
        print("\n✅ Model conversion completed!")
        print("📁 Generated files in CoreML/ directory:")
        
        coreml_files = list(Path("CoreML").glob("*"))
        for file in coreml_files:
            size = file.stat().st_size / (1024 * 1024)  # MB
            print(f"   • {file.name} ({size:.1f} MB)")
            
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        raise

if __name__ == "__main__":
    main()