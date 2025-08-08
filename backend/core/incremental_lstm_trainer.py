"""
Incremental LSTM Training System
Continuously improves the enhanced temporal model as users contribute swing data
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import json
import os
import logging
from datetime import datetime, timedelta
import threading
import time
from pathlib import Path
import sys

# Add backend directories to path
backend_root = Path(__file__).parent.parent
sys.path.append(str(backend_root / "scripts"))
sys.path.append(str(backend_root / "utils"))

from predict_enhanced_lstm import EnhancedTemporalSwingClassifier
from physics_based_features import GolfSwingPhysicsExtractor
from extract_features_robust import extract_keypoints_from_video_robust

def get_model_path(filename):
    """Get the correct path to model files"""
    models_dir = backend_root / "models"
    return str(models_dir / filename)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SwingDataset(Dataset):
    """Dataset for temporal swing sequences"""
    
    def __init__(self, sequences, labels, sequence_length=200):
        self.sequences = sequences
        self.labels = labels
        self.sequence_length = sequence_length
        
    def __len__(self):
        return len(self.sequences)
    
    def __getitem__(self, idx):
        sequence = self.sequences[idx]
        label = self.labels[idx]
        
        # Ensure consistent sequence length
        if len(sequence) < self.sequence_length:
            # Pad with last frame
            last_frame = sequence[-1:] if len(sequence) > 0 else np.zeros((1, 35))
            padding_needed = self.sequence_length - len(sequence)
            padding = np.repeat(last_frame, padding_needed, axis=0)
            sequence = np.concatenate([sequence, padding], axis=0)
        elif len(sequence) > self.sequence_length:
            # Downsample intelligently
            indices = np.linspace(0, len(sequence)-1, self.sequence_length, dtype=int)
            sequence = sequence[indices]
            
        return torch.FloatTensor(sequence), torch.LongTensor([label])

class IncrementalLSTMTrainer:
    """Manages incremental training of the LSTM model"""
    
    def __init__(self, model_path=None,
                 scaler_path=None,
                 encoder_path=None,
                 data_cache_path=None):
        
        # Set default model paths
        if model_path is None:
            model_path = get_model_path("enhanced_temporal_model.pt")
        if scaler_path is None:
            scaler_path = get_model_path("physics_scaler.pkl")
        if encoder_path is None:
            encoder_path = get_model_path("physics_label_encoder.pkl")
        if data_cache_path is None:
            data_cache_path = get_model_path("training_cache.json")
        
        self.model_path = model_path
        self.scaler_path = scaler_path  
        self.encoder_path = encoder_path
        self.data_cache_path = data_cache_path
        
        # Training parameters
        self.batch_size = 8
        self.learning_rate = 1e-4
        self.min_samples_for_training = 50
        self.training_interval_hours = 24
        
        # Load or initialize model
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.model = None
        self.optimizer = None
        self.criterion = None
        
        # Data storage
        self.training_data = self._load_cached_data()
        self.last_training_time = datetime.now() - timedelta(days=1)  # Allow immediate training
        
        # Background training thread
        self.training_thread = None
        self.should_stop = False
        
        logger.info(f"🎓 Incremental LSTM Trainer initialized")
        logger.info(f"📊 Current training cache: {len(self.training_data['sequences'])} samples")
        
    def _load_cached_data(self):
        """Load previously cached training data"""
        if os.path.exists(self.data_cache_path):
            try:
                with open(self.data_cache_path, 'r') as f:
                    data = json.load(f)
                logger.info(f"📁 Loaded {len(data['sequences'])} cached training samples")
                return data
            except Exception as e:
                logger.warning(f"Failed to load cached data: {e}")
        
        return {'sequences': [], 'labels': [], 'metadata': []}
    
    def _save_cached_data(self):
        """Save training data to cache"""
        try:
            # Ensure directory exists
            os.makedirs(os.path.dirname(self.data_cache_path), exist_ok=True)
            
            with open(self.data_cache_path, 'w') as f:
                json.dump(self.training_data, f, indent=2, default=self._json_serializer)
            logger.info(f"💾 Saved {len(self.training_data['sequences'])} samples to cache")
        except Exception as e:
            logger.error(f"Failed to save cached data: {e}")
    
    def _json_serializer(self, obj):
        """Handle numpy arrays in JSON serialization"""
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        elif isinstance(obj, np.integer):
            return int(obj)
        elif isinstance(obj, np.floating):
            return float(obj)
        elif isinstance(obj, datetime):
            return obj.isoformat()
        raise TypeError(f"Object of type {type(obj)} is not JSON serializable")
    
    def add_training_sample(self, video_path, true_label, user_feedback=None):
        """Add a new training sample from user contribution"""
        
        try:
            logger.info(f"🎬 Processing new training sample: {video_path}")
            
            # Extract temporal features from video
            keypoints, status = extract_keypoints_from_video_robust(video_path)
            
            if keypoints.size == 0:
                logger.warning(f"Failed to extract features from {video_path}: {status}")
                return False
            
            # Extract temporal sequence
            extractor = GolfSwingPhysicsExtractor()
            feature_sequence, feature_names = extractor.extract_feature_sequence(keypoints)
            
            if len(feature_sequence) == 0:
                logger.warning(f"No temporal features extracted from {video_path}")
                return False
            
            # Convert label to index
            label_map = {'too_steep': 0, 'on_plane': 1, 'too_flat': 2}
            label_idx = label_map.get(true_label, 1)  # Default to on_plane
            
            # Add to training data
            self.training_data['sequences'].append(feature_sequence.tolist())
            self.training_data['labels'].append(label_idx)
            self.training_data['metadata'].append({
                'video_path': video_path,
                'true_label': true_label,
                'timestamp': datetime.now().isoformat(),
                'user_feedback': user_feedback,
                'extraction_status': status,
                'sequence_length': len(feature_sequence)
            })
            
            # Save to cache
            self._save_cached_data()
            
            logger.info(f"✅ Added training sample: {true_label} ({len(feature_sequence)} frames)")
            logger.info(f"📊 Total training samples: {len(self.training_data['sequences'])}")
            
            # Check if we should trigger training
            self._check_training_trigger()
            
            return True
            
        except Exception as e:
            logger.error(f"Error processing training sample: {e}")
            return False
    
    def _check_training_trigger(self):
        """Check if conditions are met to trigger incremental training"""
        
        sample_count = len(self.training_data['sequences'])
        time_since_training = datetime.now() - self.last_training_time
        
        should_train = (
            sample_count >= self.min_samples_for_training and
            time_since_training.total_seconds() > self.training_interval_hours * 3600
        )
        
        if should_train and (not self.training_thread or not self.training_thread.is_alive()):
            logger.info(f"🎓 Triggering incremental training with {sample_count} samples")
            self.training_thread = threading.Thread(target=self._run_incremental_training)
            self.training_thread.daemon = True
            self.training_thread.start()
    
    def _run_incremental_training(self):
        """Run incremental training in background thread"""
        
        try:
            logger.info("🚀 Starting incremental LSTM training...")
            
            # Prepare data
            sequences = [np.array(seq) for seq in self.training_data['sequences']]
            labels = self.training_data['labels']
            
            if len(sequences) < self.min_samples_for_training:
                logger.warning(f"Insufficient samples: {len(sequences)} < {self.min_samples_for_training}")
                return
            
            # Create dataset and dataloader
            dataset = SwingDataset(sequences, labels)
            dataloader = DataLoader(dataset, batch_size=self.batch_size, shuffle=True)
            
            # Initialize or load model
            if self.model is None:
                self._initialize_model()
            
            # Training loop
            self.model.train()
            total_loss = 0
            num_batches = 0
            
            for batch_sequences, batch_labels in dataloader:
                if self.should_stop:
                    break
                
                batch_sequences = batch_sequences.to(self.device)
                batch_labels = batch_labels.to(self.device).squeeze()
                
                # Forward pass
                self.optimizer.zero_grad()
                swing_logits, phase_logits, confidence = self.model(batch_sequences)
                
                # Multi-task loss (focus on swing classification)
                swing_loss = self.criterion(swing_logits, batch_labels)
                
                # Phase loss (auxiliary task - use estimated phases)
                estimated_phases = self._estimate_phases(batch_sequences.shape[1])
                phase_loss = self.criterion(phase_logits, estimated_phases.to(self.device))
                
                total_loss_batch = swing_loss + 0.3 * phase_loss  # Weight phase loss less
                
                # Backward pass
                total_loss_batch.backward()
                
                # Gradient clipping for stability
                torch.nn.utils.clip_grad_norm_(self.model.parameters(), max_norm=1.0)
                
                self.optimizer.step()
                
                total_loss += total_loss_batch.item()
                num_batches += 1
            
            avg_loss = total_loss / num_batches if num_batches > 0 else 0
            
            # Save updated model
            self._save_model()
            self.last_training_time = datetime.now()
            
            logger.info(f"✅ Incremental training complete!")
            logger.info(f"📊 Average Loss: {avg_loss:.4f}")
            logger.info(f"🎯 Trained on {len(sequences)} samples")
            logger.info(f"💾 Model saved to {self.model_path}")
            
            # Log training statistics
            self._log_training_stats(len(sequences), avg_loss)
            
        except Exception as e:
            logger.error(f"Error during incremental training: {e}")
    
    def _initialize_model(self):
        """Initialize model, optimizer, and criterion"""
        
        self.model = EnhancedTemporalSwingClassifier(
            input_size=35,
            hidden_size=128,
            num_classes=3,
            num_layers=2,
            dropout=0.3
        )
        
        # Load existing weights if available
        if os.path.exists(self.model_path):
            try:
                self.model.load_state_dict(torch.load(self.model_path, map_location=self.device))
                logger.info(f"🧠 Loaded existing model weights from {self.model_path}")
            except Exception as e:
                logger.warning(f"Failed to load existing weights: {e}")
                logger.info("🧠 Starting with fresh model weights")
        
        self.model.to(self.device)
        
        # Initialize optimizer with lower learning rate for fine-tuning
        self.optimizer = optim.Adam(self.model.parameters(), lr=self.learning_rate, weight_decay=1e-5)
        self.criterion = nn.CrossEntropyLoss()
        
        logger.info(f"🎓 Model initialized on {self.device}")
    
    def _estimate_phases(self, sequence_length):
        """Estimate swing phases for auxiliary training (simple heuristic)"""
        phases = []
        
        for i in range(sequence_length):
            progress = i / max(sequence_length - 1, 1)
            
            if progress < 0.15:
                phase = 0  # setup
            elif progress < 0.35:
                phase = 1  # takeaway
            elif progress < 0.55:
                phase = 2  # backswing
            elif progress < 0.65:
                phase = 3  # transition
            elif progress < 0.85:
                phase = 4  # downswing
            else:
                phase = 5  # impact
                
            phases.append(phase)
        
        return torch.LongTensor(phases)
    
    def _save_model(self):
        """Save the trained model"""
        try:
            os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
            torch.save(self.model.state_dict(), self.model_path)
            
            # Also save a backup with timestamp
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_path = self.model_path.replace('.pt', f'_backup_{timestamp}.pt')
            torch.save(self.model.state_dict(), backup_path)
            
        except Exception as e:
            logger.error(f"Failed to save model: {e}")
    
    def _log_training_stats(self, sample_count, avg_loss):
        """Log training statistics"""
        stats = {
            'timestamp': datetime.now().isoformat(),
            'sample_count': sample_count,
            'average_loss': avg_loss,
            'model_version': 'enhanced_temporal_incremental'
        }
        
        stats_path = get_model_path("training_stats.json")
        
        try:
            # Load existing stats
            if os.path.exists(stats_path):
                with open(stats_path, 'r') as f:
                    all_stats = json.load(f)
            else:
                all_stats = []
            
            # Append new stats
            all_stats.append(stats)
            
            # Keep only last 100 training sessions
            if len(all_stats) > 100:
                all_stats = all_stats[-100:]
            
            # Save updated stats
            os.makedirs(os.path.dirname(stats_path), exist_ok=True)
            with open(stats_path, 'w') as f:
                json.dump(all_stats, f, indent=2)
                
        except Exception as e:
            logger.error(f"Failed to log training stats: {e}")
    
    def get_training_status(self):
        """Get current training status"""
        return {
            'total_samples': len(self.training_data['sequences']),
            'last_training': self.last_training_time.isoformat(),
            'min_samples_required': self.min_samples_for_training,
            'training_interval_hours': self.training_interval_hours,
            'is_training': self.training_thread and self.training_thread.is_alive(),
            'model_exists': os.path.exists(self.model_path)
        }
    
    def force_training(self):
        """Force immediate training (for testing/admin use)"""
        if len(self.training_data['sequences']) > 0:
            logger.info("🔨 Forcing immediate training...")
            self._run_incremental_training()
            return True
        else:
            logger.warning("No training data available")
            return False
    
    def stop(self):
        """Stop the trainer gracefully"""
        self.should_stop = True
        if self.training_thread and self.training_thread.is_alive():
            self.training_thread.join(timeout=30)
        logger.info("🛑 Incremental trainer stopped")

# Global trainer instance
_trainer_instance = None

def get_trainer():
    """Get singleton trainer instance"""
    global _trainer_instance
    if _trainer_instance is None:
        _trainer_instance = IncrementalLSTMTrainer()
    return _trainer_instance

def add_user_contribution(video_path, true_label, user_feedback=None):
    """Public API for adding user contributions"""
    trainer = get_trainer()
    return trainer.add_training_sample(video_path, true_label, user_feedback)

def get_training_status():
    """Public API for getting training status"""
    trainer = get_trainer()
    return trainer.get_training_status()

if __name__ == "__main__":
    # Test the incremental training system
    trainer = IncrementalLSTMTrainer()
    
    print("🎓 Incremental LSTM Training System")
    print("=" * 50)
    
    status = trainer.get_training_status()
    print(f"📊 Training Status:")
    for key, value in status.items():
        print(f"   {key}: {value}")
    
    # Simulate adding training data (in real use, this comes from user uploads)
    print(f"\n💡 To add training data:")
    print(f"   trainer.add_training_sample('video.mp4', 'too_steep', user_feedback)")
    print(f"   trainer.force_training()  # For immediate training")