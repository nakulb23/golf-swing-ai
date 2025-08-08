import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from sklearn.preprocessing import StandardScaler
import logging
import joblib

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GolfSwingPhysicsExtractor:
    """Extract physics-based features from golf swing keypoints"""
    
    def __init__(self):
        # MediaPipe pose landmark indices
        self.pose_landmarks = {
            'left_shoulder': 11,
            'right_shoulder': 12,
            'left_elbow': 13,
            'right_elbow': 14,
            'left_wrist': 15,
            'right_wrist': 16,
            'left_hip': 23,
            'right_hip': 24,
            'nose': 0
        }
        
        # Expected ideal swing plane characteristics
        # Updated based on modern golf instruction and biomechanics research
        self.ideal_plane_angle = 52  # degrees from vertical (more realistic for average golfer)
        self.ideal_shoulder_turn = 90  # degrees
        self.ideal_hip_turn = 45  # degrees
    
    def extract_swing_plane_features(self, keypoints_sequence):
        """Extract physics-based features from a swing sequence"""
        
        features = {}
        
        # 1. Swing Plane Angle Analysis
        features.update(self._analyze_swing_plane_angle(keypoints_sequence))
        
        # 2. Body Rotation Analysis
        features.update(self._analyze_body_rotation(keypoints_sequence))
        
        # 3. Arm/Club Path Analysis
        features.update(self._analyze_arm_path(keypoints_sequence))
        
        # 4. Swing Tempo and Sequence
        features.update(self._analyze_swing_tempo(keypoints_sequence))
        
        # 5. Balance and Stability
        features.update(self._analyze_balance(keypoints_sequence))
        
        return features
    
    def _analyze_swing_plane_angle(self, keypoints_sequence):
        """Analyze the swing plane angle throughout the swing with backswing focus"""
        
        features = {}
        plane_angles = []
        hand_velocities = []
        
        # Calculate plane angles and hand velocities for each frame
        for i, frame in enumerate(keypoints_sequence):
            # Extract key positions
            left_shoulder = self._get_landmark_3d(frame, 'left_shoulder')
            right_shoulder = self._get_landmark_3d(frame, 'right_shoulder')
            left_wrist = self._get_landmark_3d(frame, 'left_wrist')
            right_wrist = self._get_landmark_3d(frame, 'right_wrist')
            
            # Calculate shoulder center
            shoulder_center = (left_shoulder + right_shoulder) / 2
            
            # Calculate hand center (club grip position)
            hand_center = (left_wrist + right_wrist) / 2
            
            # Calculate swing plane angle
            plane_angle = self._calculate_plane_angle(shoulder_center, hand_center)
            plane_angles.append(plane_angle)
            
            # Calculate hand velocity for swing phase detection
            if i > 0:
                prev_frame = keypoints_sequence[i-1]
                prev_hand = (self._get_landmark_3d(prev_frame, 'left_wrist') + 
                           self._get_landmark_3d(prev_frame, 'right_wrist')) / 2
                velocity = np.linalg.norm(hand_center - prev_hand)
                hand_velocities.append(velocity)
            else:
                hand_velocities.append(0.0)
        
        plane_angles = np.array(plane_angles)
        hand_velocities = np.array(hand_velocities)
        
        # Identify swing phases based on velocity analysis
        swing_phases = self._identify_swing_phases(hand_velocities)
        
        # BACKSWING-FOCUSED ANALYSIS (Most Important)
        backswing_start, backswing_end = swing_phases['backswing']
        backswing_angles = plane_angles[backswing_start:backswing_end]
        
        if len(backswing_angles) > 0:
            # Focus on VERY EARLY BACKSWING (first 1/4 or 5 frames max) - most critical
            very_early_count = min(5, max(3, len(backswing_angles) // 4))
            early_backswing_angles = backswing_angles[:very_early_count]
            
            # EARLY backswing features (most important)
            features['backswing_avg_angle'] = np.mean(early_backswing_angles)
            features['backswing_max_angle'] = np.max(early_backswing_angles)
            features['backswing_consistency'] = 1.0 / (1.0 + np.std(early_backswing_angles))
            
            # Critical: Early backswing plane tendency (weighted heavily)
            # Updated thresholds based on real golf swing data analysis
            early_backswing_avg = np.mean(early_backswing_angles)
            if early_backswing_avg > 62:  # More lenient for steep classification
                features['backswing_tendency'] = 1.0  # too_steep
            elif early_backswing_avg < 42:  # More realistic flat threshold
                features['backswing_tendency'] = -1.0  # too_flat
            else:
                features['backswing_tendency'] = 0.0  # on_plane (42-62 degrees)
        else:
            # Fallback if backswing detection fails
            features['backswing_avg_angle'] = np.mean(plane_angles[:len(plane_angles)//3])
            features['backswing_max_angle'] = np.max(plane_angles[:len(plane_angles)//3])
            features['backswing_consistency'] = 0.5
            features['backswing_tendency'] = 0.0
        
        # Overall swing plane features (secondary importance)
        features['avg_plane_angle'] = np.mean(plane_angles)
        features['max_plane_angle'] = np.max(plane_angles)
        features['min_plane_angle'] = np.min(plane_angles)
        features['plane_angle_range'] = np.max(plane_angles) - np.min(plane_angles)
        features['plane_angle_std'] = np.std(plane_angles)
        
        # Deviation from ideal plane
        features['plane_deviation_from_ideal'] = abs(np.mean(plane_angles) - self.ideal_plane_angle)
        
        # Swing plane consistency
        features['plane_consistency'] = 1.0 / (1.0 + np.std(plane_angles))
        
        # Overall plane tendency (now secondary to backswing)
        # Updated to match new realistic thresholds
        avg_angle = np.mean(plane_angles)
        if avg_angle > 62:  # Consistent with backswing thresholds
            features['plane_tendency'] = 1.0  # too_steep
        elif avg_angle < 42:  # Consistent with backswing thresholds
            features['plane_tendency'] = -1.0  # too_flat
        else:
            features['plane_tendency'] = 0.0  # on_plane (42-62 degrees)
        
        return features
    
    def _identify_swing_phases(self, hand_velocities):
        """Identify key swing phases based on velocity analysis"""
        
        # Smooth velocities to reduce noise
        from scipy.signal import savgol_filter
        try:
            smoothed_velocities = savgol_filter(hand_velocities, 
                                              window_length=min(11, len(hand_velocities)//3*2+1), 
                                              polyorder=2)
        except:
            smoothed_velocities = hand_velocities
        
        # Find key points in the swing
        max_velocity_idx = np.argmax(smoothed_velocities)  # Impact zone
        
        # Find transition point (top of backswing) - local minimum before impact
        backswing_region = smoothed_velocities[:max_velocity_idx]
        if len(backswing_region) > 5:
            # Look for the last significant low point before impact
            transition_candidates = []
            for i in range(5, len(backswing_region)-5):
                if (smoothed_velocities[i] < smoothed_velocities[i-3:i].mean() and 
                    smoothed_velocities[i] < smoothed_velocities[i+1:i+4].mean()):
                    transition_candidates.append(i)
            
            if transition_candidates:
                transition_point = max(transition_candidates)  # Last transition point
            else:
                transition_point = len(backswing_region) // 2
        else:
            transition_point = len(backswing_region) // 2
        
        # Define phase boundaries
        setup_end = max(5, len(hand_velocities) // 10)  # First 10% or at least 5 frames
        backswing_start = setup_end
        backswing_end = min(transition_point + 10, max_velocity_idx - 5)  # Slightly past transition
        downswing_start = backswing_end
        downswing_end = min(max_velocity_idx + 5, len(hand_velocities) - 1)
        
        phases = {
            'setup': (0, setup_end),
            'backswing': (backswing_start, backswing_end),
            'transition': (max(0, transition_point-5), min(len(hand_velocities), transition_point+5)),
            'downswing': (downswing_start, downswing_end),
            'impact': (max(0, max_velocity_idx-3), min(len(hand_velocities), max_velocity_idx+3)),
            'follow_through': (downswing_end, len(hand_velocities))
        }
        
        return phases
    
    def _analyze_body_rotation(self, keypoints_sequence):
        """Analyze body rotation throughout the swing"""
        
        features = {}
        shoulder_angles = []
        hip_angles = []
        
        for frame in keypoints_sequence:
            # Shoulder rotation
            left_shoulder = self._get_landmark_3d(frame, 'left_shoulder')
            right_shoulder = self._get_landmark_3d(frame, 'right_shoulder')
            shoulder_line = right_shoulder - left_shoulder
            shoulder_angle = np.degrees(np.arctan2(shoulder_line[2], shoulder_line[0]))
            shoulder_angles.append(shoulder_angle)
            
            # Hip rotation
            left_hip = self._get_landmark_3d(frame, 'left_hip')
            right_hip = self._get_landmark_3d(frame, 'right_hip')
            hip_line = right_hip - left_hip
            hip_angle = np.degrees(np.arctan2(hip_line[2], hip_line[0]))
            hip_angles.append(hip_angle)
        
        shoulder_angles = np.array(shoulder_angles)
        hip_angles = np.array(hip_angles)
        
        # Shoulder rotation features
        features['max_shoulder_turn'] = np.max(shoulder_angles) - np.min(shoulder_angles)
        features['shoulder_rotation_range'] = np.ptp(shoulder_angles)
        
        # Hip rotation features
        features['max_hip_turn'] = np.max(hip_angles) - np.min(hip_angles)
        features['hip_rotation_range'] = np.ptp(hip_angles)
        
        # X-factor (difference between shoulder and hip rotation)
        x_factor = np.abs(shoulder_angles - hip_angles)
        features['avg_x_factor'] = np.mean(x_factor)
        features['max_x_factor'] = np.max(x_factor)
        
        # Sequence of rotation (hips should lead)
        hip_velocity = np.gradient(hip_angles)
        shoulder_velocity = np.gradient(shoulder_angles)
        features['rotation_sequence_correct'] = np.mean(hip_velocity > shoulder_velocity)
        
        return features
    
    def _analyze_arm_path(self, keypoints_sequence):
        """Analyze arm and club path characteristics"""
        
        features = {}
        hand_positions = []
        
        for frame in keypoints_sequence:
            left_wrist = self._get_landmark_3d(frame, 'left_wrist')
            right_wrist = self._get_landmark_3d(frame, 'right_wrist')
            hand_center = (left_wrist + right_wrist) / 2
            hand_positions.append(hand_center)
        
        hand_positions = np.array(hand_positions)
        
        # Path length and efficiency
        path_distances = np.linalg.norm(np.diff(hand_positions, axis=0), axis=1)
        features['total_path_length'] = np.sum(path_distances)
        
        # Path smoothness
        path_curvature = np.linalg.norm(np.diff(path_distances))
        features['path_smoothness'] = 1.0 / (1.0 + path_curvature)
        
        # Width and height of swing arc
        features['swing_width'] = np.ptp(hand_positions[:, 0])  # X-axis range
        features['swing_height'] = np.ptp(hand_positions[:, 1])  # Y-axis range
        features['swing_depth'] = np.ptp(hand_positions[:, 2])   # Z-axis range
        
        # Swing plane consistency in 3D
        # Fit a plane to the hand positions
        centroid = np.mean(hand_positions, axis=0)
        centered_positions = hand_positions - centroid
        
        # SVD to find plane normal
        _, _, vh = np.linalg.svd(centered_positions)
        plane_normal = vh[2]  # Third component (smallest variance)
        
        # Calculate distances from plane
        distances_from_plane = np.abs(np.dot(centered_positions, plane_normal))
        features['swing_plane_deviation'] = np.mean(distances_from_plane)
        features['swing_plane_consistency'] = 1.0 / (1.0 + np.std(distances_from_plane))
        
        return features
    
    def _analyze_swing_tempo(self, keypoints_sequence):
        """Analyze swing timing and tempo"""
        
        features = {}
        hand_velocities = []
        
        # Calculate hand velocities
        for i in range(1, len(keypoints_sequence)):
            prev_frame = keypoints_sequence[i-1]
            curr_frame = keypoints_sequence[i]
            
            prev_hand = (self._get_landmark_3d(prev_frame, 'left_wrist') + 
                         self._get_landmark_3d(prev_frame, 'right_wrist')) / 2
            curr_hand = (self._get_landmark_3d(curr_frame, 'left_wrist') + 
                         self._get_landmark_3d(curr_frame, 'right_wrist')) / 2
            
            velocity = np.linalg.norm(curr_hand - prev_hand)
            hand_velocities.append(velocity)
        
        hand_velocities = np.array(hand_velocities)
        
        # Tempo features
        features['max_velocity'] = np.max(hand_velocities)
        features['avg_velocity'] = np.mean(hand_velocities)
        features['velocity_consistency'] = 1.0 / (1.0 + np.std(hand_velocities))
        
        # Find impact zone (highest velocity region)
        impact_zone = np.argmax(hand_velocities)
        features['impact_timing'] = impact_zone / len(hand_velocities)
        
        # Acceleration patterns
        accelerations = np.gradient(hand_velocities)
        features['max_acceleration'] = np.max(accelerations)
        features['max_deceleration'] = np.min(accelerations)
        
        return features
    
    def _analyze_balance(self, keypoints_sequence):
        """Analyze balance and weight distribution"""
        
        features = {}
        center_of_mass_positions = []
        
        for frame in keypoints_sequence:
            # Calculate approximate center of mass from key body points
            left_hip = self._get_landmark_3d(frame, 'left_hip')
            right_hip = self._get_landmark_3d(frame, 'right_hip')
            left_shoulder = self._get_landmark_3d(frame, 'left_shoulder')
            right_shoulder = self._get_landmark_3d(frame, 'right_shoulder')
            
            # Approximate center of mass
            com = (left_hip + right_hip + left_shoulder + right_shoulder) / 4
            center_of_mass_positions.append(com)
        
        center_of_mass_positions = np.array(center_of_mass_positions)
        
        # Balance stability
        com_movement = np.linalg.norm(np.diff(center_of_mass_positions, axis=0), axis=1)
        features['balance_stability'] = 1.0 / (1.0 + np.mean(com_movement))
        
        # Weight shift patterns
        lateral_movement = np.ptp(center_of_mass_positions[:, 0])
        features['lateral_weight_shift'] = lateral_movement
        
        # Forward/backward balance
        sagittal_movement = np.ptp(center_of_mass_positions[:, 2])
        features['sagittal_balance'] = sagittal_movement
        
        return features
    
    def _get_landmark_3d(self, frame, landmark_name):
        """Extract 3D coordinates of a specific landmark"""
        idx = self.pose_landmarks[landmark_name]
        x = frame[idx * 4]
        y = frame[idx * 4 + 1]
        z = frame[idx * 4 + 2]
        return np.array([x, y, z])
    
    def _calculate_plane_angle(self, shoulder_pos, hand_pos):
        """Calculate swing plane angle from shoulder to hand vector"""
        
        # Vector from shoulder to hand
        swing_vector = hand_pos - shoulder_pos
        
        # Project onto vertical plane
        vertical_component = swing_vector[1]  # Y component
        horizontal_component = np.sqrt(swing_vector[0]**2 + swing_vector[2]**2)
        
        # Calculate angle from vertical
        angle = np.degrees(np.arctan2(horizontal_component, vertical_component))
        
        return angle
    
    def extract_feature_vector(self, keypoints_sequence):
        """Extract a comprehensive feature vector for machine learning"""
        
        features_dict = self.extract_swing_plane_features(keypoints_sequence)
        
        # Convert to ordered feature vector (backswing features first - most important)
        feature_names = [
            # BACKSWING FEATURES (Priority 1 - Most Important)
            'backswing_avg_angle', 'backswing_max_angle', 'backswing_consistency', 'backswing_tendency',
            # OVERALL PLANE FEATURES (Priority 2)
            'avg_plane_angle', 'max_plane_angle', 'min_plane_angle', 'plane_angle_range',
            'plane_angle_std', 'plane_deviation_from_ideal', 'plane_consistency', 'plane_tendency',
            # BODY ROTATION FEATURES (Priority 3)
            'max_shoulder_turn', 'shoulder_rotation_range', 'max_hip_turn', 'hip_rotation_range',
            'avg_x_factor', 'max_x_factor', 'rotation_sequence_correct',
            # SWING PATH FEATURES (Priority 4)
            'total_path_length', 'path_smoothness', 'swing_width', 'swing_height', 'swing_depth',
            'swing_plane_deviation', 'swing_plane_consistency',
            # TEMPO & TIMING FEATURES (Priority 5)
            'max_velocity', 'avg_velocity', 'velocity_consistency', 'impact_timing',
            'max_acceleration', 'max_deceleration',
            # BALANCE FEATURES (Priority 6)
            'balance_stability', 'lateral_weight_shift', 'sagittal_balance'
        ]
        
        feature_vector = []
        for name in feature_names:
            if name in features_dict:
                feature_vector.append(features_dict[name])
            else:
                feature_vector.append(0.0)  # Default value for missing features
        
        return np.array(feature_vector), feature_names

class PhysicsBasedSwingClassifier(nn.Module):
    """Neural network that uses physics-based features for swing classification"""
    
    def __init__(self, num_features=35, num_classes=3):
        super().__init__()
        
        self.feature_processor = nn.Sequential(
            nn.Linear(num_features, 64),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(64, 32),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(32, 16),
            nn.ReLU(),
            nn.Linear(16, num_classes)
        )
    
    def forward(self, x):
        return self.feature_processor(x)

def process_dataset_with_physics_features(data_dir, output_file="physics_features.npz"):
    """Process a dataset to extract physics-based features"""
    
    logger.info(f"🔬 Extracting physics-based features from {data_dir}...")
    
    extractor = GolfSwingPhysicsExtractor()
    
    feature_vectors = []
    labels = []
    filenames = []
    
    # Process all .npz files
    import os
    npz_files = [f for f in os.listdir(data_dir) if f.endswith('.npz')]
    
    for npz_file in npz_files:
        try:
            file_path = os.path.join(data_dir, npz_file)
            data = np.load(file_path)
            keypoints = data['keypoints']
            label = data['label'].item()
            
            # Extract physics features
            feature_vector, feature_names = extractor.extract_feature_vector(keypoints)
            
            feature_vectors.append(feature_vector)
            labels.append(label)
            filenames.append(npz_file)
            
        except Exception as e:
            logger.warning(f"Error processing {npz_file}: {str(e)}")
    
    feature_vectors = np.array(feature_vectors)
    
    # Save processed features
    np.savez_compressed(output_file, 
                       features=feature_vectors, 
                       labels=labels, 
                       filenames=filenames,
                       feature_names=feature_names)
    
    logger.info(f"✅ Extracted {len(feature_vectors)} feature vectors")
    logger.info(f"💾 Saved to {output_file}")
    
    return feature_vectors, labels, feature_names

def main():
    """Extract physics features from real data"""
    
    logger.info("🔬 PHYSICS-BASED FEATURE EXTRACTION")
    logger.info("="*50)
    
    # Process real training data
    logger.info("Processing real training data...")
    real_features, real_labels, feature_names = process_dataset_with_physics_features(
        "training_data", "real_physics_features.npz"
    )
    
    # Process synthetic data
    logger.info("Processing synthetic training data...")
    synthetic_features, synthetic_labels, _ = process_dataset_with_physics_features(
        "synthetic_data", "synthetic_physics_features.npz"
    )
    
    logger.info(f"\n📊 FEATURE EXTRACTION SUMMARY:")
    logger.info(f"Real data: {len(real_features)} samples")
    logger.info(f"Synthetic data: {len(synthetic_features)} samples")
    logger.info(f"Features per sample: {len(feature_names)}")
    
    logger.info(f"\nFeature names: {feature_names}")
    
    # MARK: - Enhanced Temporal Feature Extraction Methods
    def extract_feature_sequence(self, keypoints_sequence):
        """
        Extract temporal feature sequences for LSTM processing
        Returns features for each frame to capture swing dynamics
        """
        if len(keypoints_sequence) == 0:
            return np.array([]), []
        
        feature_sequence = []
        feature_names = self.get_feature_names()
        
        for frame_idx in range(len(keypoints_sequence)):
            # Extract features for each frame
            frame_keypoints = keypoints_sequence[frame_idx]
            
            # Ensure we have enough frames for derivatives
            prev_frame = frame_keypoints if frame_idx == 0 else keypoints_sequence[frame_idx-1]
            next_frame = frame_keypoints if frame_idx >= len(keypoints_sequence)-1 else keypoints_sequence[frame_idx+1]
            
            frame_features = self._extract_single_frame_features(
                frame_keypoints, prev_frame, next_frame, frame_idx, len(keypoints_sequence)
            )
            
            feature_sequence.append(frame_features)
        
        return np.array(feature_sequence), feature_names
    
    def _extract_single_frame_features(self, current_frame, prev_frame, next_frame, frame_idx, total_frames):
        """Extract comprehensive features for a single frame with temporal context"""
        
        features = []
        
        # 1. Basic pose features (consistent with existing model)
        pose_features = self._extract_basic_pose_features(current_frame)
        features.extend(pose_features)
        
        # 2. Temporal derivatives (velocity and acceleration)
        if frame_idx > 0:
            velocity_features = self._calculate_velocity_features(current_frame, prev_frame)
            features.extend(velocity_features)
        else:
            features.extend([0.0] * 10)  # Zero velocity at start
        
        # 3. Phase-aware features
        swing_phase = self._estimate_swing_phase(frame_idx, total_frames)
        phase_features = self._extract_phase_features(current_frame, swing_phase)
        features.extend(phase_features)
        
        # 4. Temporal consistency features
        consistency_features = self._calculate_consistency_features(
            current_frame, prev_frame, next_frame
        )
        features.extend(consistency_features)
        
        return features[:35]  # Ensure consistent feature count
    
    def _extract_basic_pose_features(self, keypoints):
        """Extract basic pose features (compatible with existing model)"""
        try:
            # Reuse existing feature extraction logic
            features_dict = self.extract_swing_plane_features(np.array([keypoints]))
            
            # Convert to ordered feature vector
            features = [
                features_dict.get('avg_plane_angle', 0),
                features_dict.get('plane_consistency', 0),
                features_dict.get('shoulder_turn_range', 0),
                features_dict.get('hip_turn_range', 0),
                features_dict.get('shoulder_hip_separation', 0),
                features_dict.get('arm_extension_ratio', 0),
                features_dict.get('club_path_deviation', 0),
                features_dict.get('swing_width', 0),
                features_dict.get('tempo_ratio', 0),
                features_dict.get('transition_smoothness', 0)
            ]
            
            # Pad to ensure we have enough features
            while len(features) < 25:
                features.append(0.0)
                
            return features[:25]
            
        except:
            return [0.0] * 25
    
    def _calculate_velocity_features(self, current_frame, prev_frame):
        """Calculate velocity-based features between frames"""
        velocities = []
        
        try:
            key_points = ['left_wrist', 'right_wrist', 'left_shoulder', 'right_shoulder']
            
            for point_name in key_points:
                if point_name in self.pose_landmarks:
                    idx = self.pose_landmarks[point_name]
                    if idx < len(current_frame) and idx < len(prev_frame):
                        current_pos = current_frame[idx][:2]  # x, y
                        prev_pos = prev_frame[idx][:2]
                        
                        # Calculate velocity magnitude
                        velocity = np.linalg.norm(np.array(current_pos) - np.array(prev_pos))
                        velocities.append(velocity)
                    else:
                        velocities.append(0.0)
                else:
                    velocities.append(0.0)
            
            # Add derived velocity features
            if len(velocities) >= 4:
                velocities.extend([
                    max(velocities),  # Peak velocity
                    np.mean(velocities),  # Average velocity
                ])
            
            # Pad to 10 features
            while len(velocities) < 10:
                velocities.append(0.0)
                
            return velocities[:10]
            
        except:
            return [0.0] * 10
    
    def _estimate_swing_phase(self, frame_idx, total_frames):
        """Estimate swing phase based on frame position"""
        progress = frame_idx / max(total_frames - 1, 1)
        
        if progress < 0.15:
            return "setup"
        elif progress < 0.35:
            return "takeaway"
        elif progress < 0.55:
            return "backswing"
        elif progress < 0.65:
            return "transition"
        elif progress < 0.85:
            return "downswing"
        else:
            return "impact"
    
    def _extract_phase_features(self, keypoints, phase):
        """Extract phase-specific features"""
        # Phase encoding (one-hot style)
        phases = ["setup", "takeaway", "backswing", "transition", "downswing", "impact"]
        phase_encoding = [1.0 if p == phase else 0.0 for p in phases]
        return phase_encoding
    
    def _calculate_consistency_features(self, current_frame, prev_frame, next_frame):
        """Calculate temporal consistency features"""
        consistency = []
        
        try:
            # Calculate smoothness of key joint trajectories
            key_joints = ['left_wrist', 'right_wrist', 'left_shoulder', 'right_shoulder']
            
            for joint_name in key_joints:
                if joint_name in self.pose_landmarks:
                    idx = self.pose_landmarks[joint_name]
                    if all(idx < len(frame) for frame in [current_frame, prev_frame, next_frame]):
                        # Get positions
                        positions = [
                            frame[idx][:2] for frame in [prev_frame, current_frame, next_frame]
                        ]
                        
                        # Calculate second derivative (acceleration/jerk indicator)
                        if len(positions) == 3:
                            p1, p2, p3 = [np.array(pos) for pos in positions]
                            accel = np.linalg.norm((p1 - 2*p2 + p3))
                            consistency.append(accel)
                        else:
                            consistency.append(0.0)
                    else:
                        consistency.append(0.0)
                else:
                    consistency.append(0.0)
            
            # Pad to expected size
            while len(consistency) < 4:
                consistency.append(0.0)
                
            return consistency[:4]
            
        except:
            return [0.0] * 4

# Enhanced methods are already embedded in the main() function
# This section handles the modular function definitions when needed

if __name__ == "__main__":
    main()