import numpy as np
import math
import logging
from typing import Dict, Tuple, List, Optional
from camera_angle_detector import CameraAngleDetector, CameraAngle, get_rotation_matrix_for_angle

logger = logging.getLogger(__name__)

class ViewInvariantFeatureExtractor:
    """
    Enhanced physics-based feature extractor that normalizes for different camera angles.
    
    Key innovations:
    1. Camera angle detection and coordinate transformation
    2. View-invariant feature weighting based on angle reliability
    3. Multi-angle fusion for enhanced accuracy
    4. Angle-specific feature emphasis
    """
    
    def __init__(self):
        self.camera_detector = CameraAngleDetector()
        
        # MediaPipe pose landmark indices
        self.pose_landmarks = {
            'left_shoulder': 11, 'right_shoulder': 12,
            'left_elbow': 13, 'right_elbow': 14,
            'left_wrist': 15, 'right_wrist': 16,
            'left_hip': 23, 'right_hip': 24,
            'left_knee': 25, 'right_knee': 26,
            'nose': 0
        }
        
        # Feature reliability by camera angle
        self.feature_reliability = {
            CameraAngle.SIDE_ON: {
                'swing_plane': 1.0,      # Best for swing plane analysis
                'body_rotation': 0.8,    # Good shoulder turn visibility
                'balance': 0.9,          # Good weight shift visibility
                'tempo': 1.0,            # Excellent for timing
                'club_path': 0.7         # Moderate club path visibility
            },
            CameraAngle.FRONT_ON: {
                'swing_plane': 0.6,      # Limited plane angle accuracy
                'body_rotation': 0.9,    # Excellent shoulder turn visibility
                'balance': 1.0,          # Best for balance/alignment
                'tempo': 0.8,            # Good for timing
                'club_path': 0.9         # Excellent for club path
            },
            CameraAngle.BEHIND: {
                'swing_plane': 0.7,      # Moderate plane visibility
                'body_rotation': 0.7,    # Limited shoulder visibility
                'balance': 0.8,          # Good for balance
                'tempo': 0.9,            # Good for timing
                'club_path': 1.0         # Best for club path analysis
            },
            CameraAngle.ANGLED_SIDE: {
                'swing_plane': 0.8,      # Good but not optimal
                'body_rotation': 0.9,    # Good visibility
                'balance': 0.8,          # Good balance analysis
                'tempo': 0.9,            # Good timing
                'club_path': 0.8         # Good club path
            },
            CameraAngle.ANGLED_FRONT: {
                'swing_plane': 0.7,      # Moderate accuracy
                'body_rotation': 0.8,    # Good visibility
                'balance': 0.9,          # Good balance analysis
                'tempo': 0.8,            # Good timing
                'club_path': 0.9         # Good club path
            }
        }
    
    def extract_view_invariant_features(self, keypoints_sequence: np.ndarray) -> Dict:
        """
        Extract physics-based features that are normalized for camera angle.
        
        Args:
            keypoints_sequence: Array of shape (frames, 258) containing pose landmarks
            
        Returns:
            Dictionary containing:
            - features: 35 normalized physics features
            - camera_analysis: detected camera angle and confidence
            - feature_weights: reliability weights for each feature category
            - raw_features: features before angle normalization
        """
        
        if len(keypoints_sequence) == 0:
            return self._create_empty_result()
        
        # Step 1: Detect camera angle
        camera_analysis = self.camera_detector.detect_camera_angle(keypoints_sequence)
        camera_angle = camera_analysis['angle_type']
        confidence = camera_analysis['confidence']
        
        logger.info(f"Camera angle: {camera_angle.value}, confidence: {confidence:.3f}")
        
        # Step 2: Transform coordinates to canonical view if needed
        if camera_analysis['transformation_needed']:
            normalized_sequence = self._transform_to_canonical_view(
                keypoints_sequence, camera_angle
            )
        else:
            normalized_sequence = keypoints_sequence.copy()
        
        # Step 3: Extract features from normalized coordinates
        features = self._extract_physics_features(normalized_sequence, camera_angle)
        
        # Step 4: Apply angle-specific feature weighting
        weighted_features = self._apply_feature_weights(features, camera_angle, confidence)
        
        # Step 5: Calculate feature reliability scores
        feature_weights = self._calculate_feature_weights(camera_angle, confidence)
        
        return {
            'features': weighted_features,
            'camera_analysis': camera_analysis,
            'feature_weights': feature_weights,
            'raw_features': features,
            'normalized_sequence': normalized_sequence
        }
    
    def _transform_to_canonical_view(self, keypoints_sequence: np.ndarray, 
                                   camera_angle: CameraAngle) -> np.ndarray:
        """Transform keypoints to canonical side-on view"""
        
        rotation_matrix = get_rotation_matrix_for_angle(camera_angle)
        transformed_sequence = keypoints_sequence.copy()
        
        for frame_idx in range(len(keypoints_sequence)):
            # Transform pose landmarks (first 132 elements: 33 landmarks * 4 components)
            pose_data = keypoints_sequence[frame_idx][:132].reshape(33, 4)
            
            for landmark_idx in range(33):
                # Extract x, y, z coordinates (skip visibility score)
                coords_3d = pose_data[landmark_idx][:3]
                
                # Apply rotation transformation
                transformed_coords = rotation_matrix @ coords_3d
                
                # Update the transformed sequence
                start_idx = landmark_idx * 4
                transformed_sequence[frame_idx][start_idx:start_idx+3] = transformed_coords
        
        logger.info(f"Applied {camera_angle.value} transformation to {len(keypoints_sequence)} frames")
        
        return transformed_sequence
    
    def _extract_physics_features(self, keypoints_sequence: np.ndarray, 
                                 camera_angle: CameraAngle) -> Dict:
        """Extract physics features optimized for the detected camera angle"""
        
        features = {}
        
        # 1. Swing Plane Analysis (enhanced for angle)
        features.update(self._analyze_swing_plane_enhanced(keypoints_sequence, camera_angle))
        
        # 2. Body Rotation Analysis (angle-aware)
        features.update(self._analyze_body_rotation_enhanced(keypoints_sequence, camera_angle))
        
        # 3. Balance and Weight Shift (angle-optimized)
        features.update(self._analyze_balance_enhanced(keypoints_sequence, camera_angle))
        
        # 4. Swing Tempo and Sequence (universal)
        features.update(self._analyze_tempo_enhanced(keypoints_sequence, camera_angle))
        
        # 5. Club Path Analysis (angle-specific)
        features.update(self._analyze_club_path_enhanced(keypoints_sequence, camera_angle))
        
        return features
    
    def _analyze_swing_plane_enhanced(self, keypoints_sequence: np.ndarray, 
                                    camera_angle: CameraAngle) -> Dict:
        """Enhanced swing plane analysis considering camera angle"""
        
        features = {}
        plane_angles = []
        hand_velocities = []
        
        for i, frame in enumerate(keypoints_sequence):
            # Extract key positions using transformed coordinates
            left_shoulder = self._get_landmark_3d(frame, 'left_shoulder')
            right_shoulder = self._get_landmark_3d(frame, 'right_shoulder')
            left_wrist = self._get_landmark_3d(frame, 'left_wrist')
            right_wrist = self._get_landmark_3d(frame, 'right_wrist')
            
            # Calculate shoulder center
            shoulder_center = (left_shoulder + right_shoulder) / 2
            hand_center = (left_wrist + right_wrist) / 2
            
            # Enhanced plane angle calculation based on camera angle
            if camera_angle in [CameraAngle.SIDE_ON, CameraAngle.ANGLED_SIDE]:
                # Use traditional plane angle calculation
                plane_angle = self._calculate_plane_angle_traditional(shoulder_center, hand_center)
            else:
                # Use modified calculation for front/behind views
                plane_angle = self._calculate_plane_angle_modified(shoulder_center, hand_center, camera_angle)
            
            plane_angles.append(plane_angle)
            
            # Calculate hand velocity
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
        
        # Identify swing phases
        swing_phases = self._identify_swing_phases(hand_velocities)
        
        # Extract plane features with angle-specific weighting
        backswing_start, backswing_end = swing_phases['backswing']
        backswing_angles = plane_angles[backswing_start:backswing_end]
        
        if len(backswing_angles) > 0:
            features['avg_backswing_plane_angle'] = np.mean(backswing_angles)
            features['backswing_plane_consistency'] = 1.0 / (np.std(backswing_angles) + 0.1)
            features['early_backswing_angle'] = backswing_angles[0] if len(backswing_angles) > 0 else 45.0
        else:
            features['avg_backswing_plane_angle'] = 45.0
            features['backswing_plane_consistency'] = 0.5
            features['early_backswing_angle'] = 45.0
        
        # Overall plane statistics
        features['overall_plane_angle'] = np.mean(plane_angles)
        features['plane_angle_range'] = np.max(plane_angles) - np.min(plane_angles)
        features['plane_angle_std'] = np.std(plane_angles)
        
        return features
    
    def _analyze_body_rotation_enhanced(self, keypoints_sequence: np.ndarray, 
                                      camera_angle: CameraAngle) -> Dict:
        """Enhanced body rotation analysis optimized for camera angle"""
        
        features = {}
        shoulder_rotations = []
        hip_rotations = []
        
        for frame in keypoints_sequence:
            # Extract landmarks
            left_shoulder = self._get_landmark_3d(frame, 'left_shoulder')
            right_shoulder = self._get_landmark_3d(frame, 'right_shoulder')
            left_hip = self._get_landmark_3d(frame, 'left_hip')
            right_hip = self._get_landmark_3d(frame, 'right_hip')
            
            # Calculate rotation angles based on camera perspective
            if camera_angle == CameraAngle.FRONT_ON:
                # Front view: best for measuring shoulder turn
                shoulder_rotation = self._calculate_rotation_front_view(left_shoulder, right_shoulder)
                hip_rotation = self._calculate_rotation_front_view(left_hip, right_hip)
            elif camera_angle == CameraAngle.SIDE_ON:
                # Side view: use depth changes for rotation estimation
                shoulder_rotation = self._calculate_rotation_side_view(left_shoulder, right_shoulder)
                hip_rotation = self._calculate_rotation_side_view(left_hip, right_hip)
            else:
                # Angled views: hybrid approach
                shoulder_rotation = self._calculate_rotation_hybrid(left_shoulder, right_shoulder)
                hip_rotation = self._calculate_rotation_hybrid(left_hip, right_hip)
            
            shoulder_rotations.append(shoulder_rotation)
            hip_rotations.append(hip_rotation)
        
        shoulder_rotations = np.array(shoulder_rotations)
        hip_rotations = np.array(hip_rotations)
        
        # Extract rotation features
        features['max_shoulder_rotation'] = np.max(np.abs(shoulder_rotations))
        features['max_hip_rotation'] = np.max(np.abs(hip_rotations))
        features['avg_shoulder_rotation'] = np.mean(np.abs(shoulder_rotations))
        features['avg_hip_rotation'] = np.mean(np.abs(hip_rotations))
        
        # X-factor (shoulder-hip separation)
        x_factor = np.abs(shoulder_rotations - hip_rotations)
        features['max_x_factor'] = np.max(x_factor)
        features['avg_x_factor'] = np.mean(x_factor)
        
        return features
    
    def _analyze_balance_enhanced(self, keypoints_sequence: np.ndarray, 
                                camera_angle: CameraAngle) -> Dict:
        """Enhanced balance analysis considering camera angle"""
        
        features = {}
        com_positions = []
        
        for frame in keypoints_sequence:
            # Calculate center of mass using key landmarks
            landmarks = {name: self._get_landmark_3d(frame, name) for name in self.pose_landmarks.keys()}
            
            # Weight different body parts for COM calculation
            com = self._calculate_center_of_mass(landmarks)
            com_positions.append(com)
        
        com_positions = np.array(com_positions)
        
        # Balance metrics optimized for camera angle
        if camera_angle in [CameraAngle.FRONT_ON, CameraAngle.ANGLED_FRONT]:
            # Front view: excellent for lateral balance
            features['lateral_sway'] = np.std(com_positions[:, 0])  # X-axis movement
            features['forward_sway'] = np.std(com_positions[:, 2])  # Z-axis movement
        elif camera_angle in [CameraAngle.SIDE_ON, CameraAngle.ANGLED_SIDE]:
            # Side view: excellent for forward/back movement
            features['lateral_sway'] = np.std(com_positions[:, 2])  # Z-axis as lateral
            features['forward_sway'] = np.std(com_positions[:, 0])  # X-axis as forward/back
        else:
            # Behind or unknown: moderate accuracy
            features['lateral_sway'] = np.std(com_positions[:, 0])
            features['forward_sway'] = np.std(com_positions[:, 1])
        
        # Universal balance metrics
        features['total_com_movement'] = np.sum(np.sqrt(np.sum(np.diff(com_positions, axis=0)**2, axis=1)))
        features['balance_stability'] = 1.0 / (features['total_com_movement'] + 0.1)
        
        return features
    
    def _analyze_tempo_enhanced(self, keypoints_sequence: np.ndarray, 
                              camera_angle: CameraAngle) -> Dict:
        """Enhanced tempo analysis (universal across angles)"""
        
        features = {}
        hand_velocities = []
        
        for i in range(1, len(keypoints_sequence)):
            current_frame = keypoints_sequence[i]
            prev_frame = keypoints_sequence[i-1]
            
            # Calculate hand velocity
            current_hand = (self._get_landmark_3d(current_frame, 'left_wrist') + 
                          self._get_landmark_3d(current_frame, 'right_wrist')) / 2
            prev_hand = (self._get_landmark_3d(prev_frame, 'left_wrist') + 
                        self._get_landmark_3d(prev_frame, 'right_wrist')) / 2
            
            velocity = np.linalg.norm(current_hand - prev_hand)
            hand_velocities.append(velocity)
        
        hand_velocities = np.array(hand_velocities)
        
        # Tempo features (universal)
        features['max_hand_velocity'] = np.max(hand_velocities)
        features['avg_hand_velocity'] = np.mean(hand_velocities)
        features['velocity_smoothness'] = 1.0 / (np.std(hand_velocities) + 0.1)
        
        # Swing rhythm analysis
        velocity_peaks = self._find_velocity_peaks(hand_velocities)
        features['tempo_consistency'] = 1.0 / (np.std(np.diff(velocity_peaks)) + 0.1) if len(velocity_peaks) > 1 else 0.5
        
        return features
    
    def _analyze_club_path_enhanced(self, keypoints_sequence: np.ndarray, 
                                  camera_angle: CameraAngle) -> Dict:
        """Enhanced club path analysis optimized for camera angle"""
        
        features = {}
        hand_positions = []
        
        for frame in keypoints_sequence:
            left_wrist = self._get_landmark_3d(frame, 'left_wrist')
            right_wrist = self._get_landmark_3d(frame, 'right_wrist')
            hand_center = (left_wrist + right_wrist) / 2
            hand_positions.append(hand_center)
        
        hand_positions = np.array(hand_positions)
        
        # Club path features based on camera angle
        if camera_angle == CameraAngle.BEHIND:
            # Behind view: best for club path analysis
            features['club_path_deviation'] = self._calculate_path_deviation_behind(hand_positions)
            features['inside_out_tendency'] = self._calculate_inside_out_behind(hand_positions)
        elif camera_angle == CameraAngle.SIDE_ON:
            # Side view: good for up/down path
            features['club_path_deviation'] = self._calculate_path_deviation_side(hand_positions)
            features['inside_out_tendency'] = 0.0  # Not visible from side
        else:
            # Other angles: moderate accuracy
            features['club_path_deviation'] = self._calculate_path_deviation_general(hand_positions)
            features['inside_out_tendency'] = self._calculate_inside_out_general(hand_positions)
        
        # Universal path features
        features['path_length'] = np.sum(np.sqrt(np.sum(np.diff(hand_positions, axis=0)**2, axis=1)))
        features['path_smoothness'] = self._calculate_path_smoothness(hand_positions)
        
        return features
    
    def _apply_feature_weights(self, features: Dict, camera_angle: CameraAngle, 
                             confidence: float) -> Dict:
        """Apply angle-specific weights to features based on reliability"""
        
        if camera_angle not in self.feature_reliability:
            return features
        
        reliability_weights = self.feature_reliability[camera_angle]
        weighted_features = features.copy()
        
        # Apply weights to feature categories
        for feature_name, value in features.items():
            category_weight = 1.0
            
            # Determine feature category and apply weight
            if 'plane' in feature_name or 'backswing' in feature_name:
                category_weight = reliability_weights['swing_plane']
            elif 'rotation' in feature_name or 'shoulder' in feature_name or 'hip' in feature_name:
                category_weight = reliability_weights['body_rotation']
            elif 'sway' in feature_name or 'balance' in feature_name or 'com' in feature_name:
                category_weight = reliability_weights['balance']
            elif 'velocity' in feature_name or 'tempo' in feature_name:
                category_weight = reliability_weights['tempo']
            elif 'path' in feature_name or 'club' in feature_name:
                category_weight = reliability_weights['club_path']
            
            # Apply confidence-adjusted weight
            final_weight = category_weight * confidence
            weighted_features[feature_name] = value * final_weight
        
        return weighted_features
    
    def _calculate_feature_weights(self, camera_angle: CameraAngle, confidence: float) -> Dict:
        """Calculate reliability weights for each feature category"""
        
        if camera_angle not in self.feature_reliability:
            return {category: 0.5 for category in ['swing_plane', 'body_rotation', 'balance', 'tempo', 'club_path']}
        
        base_weights = self.feature_reliability[camera_angle]
        confidence_adjusted_weights = {}
        
        for category, weight in base_weights.items():
            confidence_adjusted_weights[category] = weight * confidence
        
        return confidence_adjusted_weights
    
    # Helper methods for specific calculations
    def _calculate_plane_angle_traditional(self, shoulder_center: np.ndarray, hand_center: np.ndarray) -> float:
        """Traditional plane angle calculation for side views"""
        swing_vector = hand_center - shoulder_center
        vertical_vector = np.array([0, 1, 0])
        
        # Calculate angle from vertical
        dot_product = np.dot(swing_vector, vertical_vector)
        magnitude = np.linalg.norm(swing_vector)
        
        if magnitude > 0:
            angle = math.acos(np.clip(dot_product / magnitude, -1, 1)) * 180 / math.pi
            return angle
        return 45.0
    
    def _calculate_plane_angle_modified(self, shoulder_center: np.ndarray, hand_center: np.ndarray, 
                                      camera_angle: CameraAngle) -> float:
        """Modified plane angle calculation for non-side views"""
        swing_vector = hand_center - shoulder_center
        
        if camera_angle == CameraAngle.FRONT_ON:
            # Use X-Z plane projection
            projected_vector = np.array([swing_vector[0], 0, swing_vector[2]])
            vertical_ref = np.array([0, 0, 1])
        else:
            # Use traditional calculation with lower confidence
            return self._calculate_plane_angle_traditional(shoulder_center, hand_center)
        
        magnitude = np.linalg.norm(projected_vector)
        if magnitude > 0:
            dot_product = np.dot(projected_vector, vertical_ref)
            angle = math.acos(np.clip(dot_product / magnitude, -1, 1)) * 180 / math.pi
            return angle
        return 45.0
    
    def _get_landmark_3d(self, frame: np.ndarray, landmark_name: str) -> np.ndarray:
        """Extract 3D coordinates for a specific landmark"""
        if landmark_name not in self.pose_landmarks:
            return np.array([0, 0, 0])
        
        idx = self.pose_landmarks[landmark_name]
        start_idx = idx * 4
        
        if start_idx + 2 < len(frame):
            return frame[start_idx:start_idx+3]  # x, y, z only
        else:
            return np.array([0, 0, 0])
    
    def _identify_swing_phases(self, velocities: np.ndarray) -> Dict:
        """Identify swing phases based on velocity patterns"""
        
        if len(velocities) == 0:
            return {'backswing': (0, 1), 'downswing': (1, 2), 'follow_through': (2, 3)}
        
        # Simple peak detection for swing phases
        peak_idx = np.argmax(velocities)
        
        # Backswing: start to 70% of peak
        backswing_end = max(1, int(peak_idx * 0.7))
        
        # Downswing: 70% to peak
        downswing_start = backswing_end
        downswing_end = peak_idx
        
        # Follow-through: peak to end
        follow_start = peak_idx
        
        return {
            'backswing': (0, backswing_end),
            'downswing': (downswing_start, downswing_end),
            'follow_through': (follow_start, len(velocities))
        }
    
    def _create_empty_result(self) -> Dict:
        """Create empty result when no valid keypoints"""
        return {
            'features': {},
            'camera_analysis': {
                'angle_type': CameraAngle.UNKNOWN,
                'confidence': 0.0,
                'metrics': {},
                'frame_analyses': []
            },
            'feature_weights': {},
            'raw_features': {},
            'normalized_sequence': np.array([])
        }
    
    # Additional helper methods for specific calculations would go here...
    # (Simplified for brevity - can be expanded based on specific needs)
    
    def _calculate_rotation_front_view(self, left_point: np.ndarray, right_point: np.ndarray) -> float:
        """Calculate rotation angle from front view"""
        vector = right_point - left_point
        angle = math.atan2(vector[1], vector[0]) * 180 / math.pi
        return angle
    
    def _calculate_rotation_side_view(self, left_point: np.ndarray, right_point: np.ndarray) -> float:
        """Calculate rotation angle from side view using depth"""
        z_diff = abs(right_point[2] - left_point[2])
        return z_diff * 90  # Convert to angle approximation
    
    def _calculate_rotation_hybrid(self, left_point: np.ndarray, right_point: np.ndarray) -> float:
        """Calculate rotation angle using hybrid approach"""
        return (self._calculate_rotation_front_view(left_point, right_point) + 
                self._calculate_rotation_side_view(left_point, right_point)) / 2
    
    def _calculate_center_of_mass(self, landmarks: Dict) -> np.ndarray:
        """Calculate approximate center of mass from landmarks"""
        # Simplified COM calculation using key landmarks
        key_points = ['nose', 'left_shoulder', 'right_shoulder', 'left_hip', 'right_hip']
        weights = [0.1, 0.2, 0.2, 0.25, 0.25]  # Approximate body mass distribution
        
        com = np.zeros(3)
        total_weight = 0
        
        for point, weight in zip(key_points, weights):
            if point in landmarks:
                com += landmarks[point][:3] * weight
                total_weight += weight
        
        if total_weight > 0:
            com /= total_weight
        
        return com
    
    def _find_velocity_peaks(self, velocities: np.ndarray) -> List[int]:
        """Find velocity peaks for tempo analysis"""
        peaks = []
        for i in range(1, len(velocities) - 1):
            if velocities[i] > velocities[i-1] and velocities[i] > velocities[i+1]:
                peaks.append(i)
        return peaks
    
    def _calculate_path_deviation_behind(self, positions: np.ndarray) -> float:
        """Calculate club path deviation from behind view"""
        if len(positions) < 2:
            return 0.0
        
        # Use X-axis deviation (left-right from behind)
        x_positions = positions[:, 0]
        return np.std(x_positions)
    
    def _calculate_path_deviation_side(self, positions: np.ndarray) -> float:
        """Calculate club path deviation from side view"""
        if len(positions) < 2:
            return 0.0
        
        # Use Z-axis deviation (in-out from side)
        z_positions = positions[:, 2]
        return np.std(z_positions)
    
    def _calculate_path_deviation_general(self, positions: np.ndarray) -> float:
        """Calculate general path deviation"""
        if len(positions) < 2:
            return 0.0
        
        # Use combined X-Z deviation
        lateral_positions = positions[:, [0, 2]]
        deviations = np.std(lateral_positions, axis=0)
        return np.mean(deviations)
    
    def _calculate_inside_out_behind(self, positions: np.ndarray) -> float:
        """Calculate inside-out tendency from behind view"""
        if len(positions) < 2:
            return 0.0
        
        # Analyze X-axis movement pattern
        x_diff = np.diff(positions[:, 0])
        return np.mean(x_diff)  # Positive = out-to-in, Negative = in-to-out
    
    def _calculate_inside_out_general(self, positions: np.ndarray) -> float:
        """Calculate general inside-out tendency"""
        if len(positions) < 2:
            return 0.0
        
        # Simplified calculation
        lateral_diff = np.diff(positions[:, 0])
        return np.mean(lateral_diff)
    
    def _calculate_path_smoothness(self, positions: np.ndarray) -> float:
        """Calculate path smoothness (universal metric)"""
        if len(positions) < 3:
            return 1.0
        
        # Calculate second derivatives (acceleration)
        velocities = np.diff(positions, axis=0)
        accelerations = np.diff(velocities, axis=0)
        
        # Smoothness is inverse of acceleration variance
        acceleration_magnitudes = np.sqrt(np.sum(accelerations**2, axis=1))
        smoothness = 1.0 / (np.std(acceleration_magnitudes) + 0.1)
        
        return smoothness