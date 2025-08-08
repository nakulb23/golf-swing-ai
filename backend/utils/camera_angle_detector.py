import numpy as np
import cv2
import math
import logging
from typing import Dict, Tuple, List, Optional
from enum import Enum

logger = logging.getLogger(__name__)

class CameraAngle(Enum):
    """Enumeration of supported camera angles"""
    SIDE_ON = "side_on"          # Down-the-line view (optimal for swing plane)
    FRONT_ON = "front_on"        # Face-on view (optimal for alignment)
    BEHIND = "behind"            # Behind golfer (optimal for club path)
    ANGLED_SIDE = "angled_side"  # 30-60° from side-on
    ANGLED_FRONT = "angled_front" # 30-60° from front-on
    OVERHEAD = "overhead"        # High angle/overhead view
    UNKNOWN = "unknown"          # Cannot determine angle

class CameraAngleDetector:
    """
    Detects camera angle relative to golfer using pose landmarks.
    
    Key principles:
    - Side-on: Shoulders appear as a line, body width is minimal
    - Front-on: Shoulders appear wide, body depth is minimal  
    - Behind: Similar to front but club/hands positioned differently
    - Angled: Intermediate shoulder orientations
    """
    
    def __init__(self):
        # MediaPipe pose landmark indices
        self.landmarks = {
            'nose': 0,
            'left_shoulder': 11, 'right_shoulder': 12,
            'left_elbow': 13, 'right_elbow': 14,
            'left_wrist': 15, 'right_wrist': 16,
            'left_hip': 23, 'right_hip': 24,
            'left_knee': 25, 'right_knee': 26,
            'left_ankle': 27, 'right_ankle': 28
        }
        
        # Confidence thresholds for angle classification
        self.confidence_thresholds = {
            'high': 0.8,
            'medium': 0.6,
            'low': 0.4
        }
        
    def detect_camera_angle(self, keypoints_sequence: np.ndarray) -> Dict:
        """
        Detect camera angle from a sequence of pose keypoints.
        
        Args:
            keypoints_sequence: Array of shape (frames, 258) containing pose landmarks
            
        Returns:
            Dictionary containing:
            - angle_type: CameraAngle enum
            - confidence: float [0-1]
            - metrics: dict of calculated geometric metrics
            - frame_analysis: per-frame angle estimates
        """
        if len(keypoints_sequence) == 0:
            return self._create_result(CameraAngle.UNKNOWN, 0.0, {}, [])
            
        frame_analyses = []
        valid_frames = 0
        
        # Analyze each frame
        for frame_idx, frame in enumerate(keypoints_sequence):
            frame_result = self._analyze_single_frame(frame)
            if frame_result['valid']:
                frame_analyses.append(frame_result)
                valid_frames += 1
        
        if valid_frames == 0:
            return self._create_result(CameraAngle.UNKNOWN, 0.0, {}, [])
            
        # Aggregate results across all valid frames
        aggregated_metrics = self._aggregate_frame_metrics(frame_analyses)
        
        # Classify camera angle based on aggregated metrics
        angle_type, confidence = self._classify_camera_angle(aggregated_metrics)
        
        logger.info(f"Camera angle detected: {angle_type.value} (confidence: {confidence:.3f})")
        
        return self._create_result(angle_type, confidence, aggregated_metrics, frame_analyses)
    
    def _analyze_single_frame(self, frame: np.ndarray) -> Dict:
        """Analyze camera angle for a single frame"""
        
        # Extract key landmarks
        landmarks_3d = self._extract_landmarks_3d(frame)
        
        if not self._validate_landmarks(landmarks_3d):
            return {'valid': False}
            
        # Calculate geometric metrics
        metrics = {}
        
        # 1. Shoulder orientation analysis
        metrics.update(self._analyze_shoulder_orientation(landmarks_3d))
        
        # 2. Body width vs depth analysis  
        metrics.update(self._analyze_body_proportions(landmarks_3d))
        
        # 3. Hip orientation analysis
        metrics.update(self._analyze_hip_orientation(landmarks_3d))
        
        # 4. Asymmetry analysis (left vs right visibility)
        metrics.update(self._analyze_body_asymmetry(landmarks_3d))
        
        # 5. Hand/club positioning relative to body
        metrics.update(self._analyze_hand_positioning(landmarks_3d))
        
        return {
            'valid': True,
            'metrics': metrics
        }
    
    def _analyze_shoulder_orientation(self, landmarks: Dict) -> Dict:
        """Analyze shoulder line orientation to determine viewing angle"""
        
        left_shoulder = landmarks['left_shoulder']
        right_shoulder = landmarks['right_shoulder']
        
        # Calculate shoulder vector
        shoulder_vector = right_shoulder - left_shoulder
        
        # Shoulder width (apparent width in camera view)
        shoulder_width = np.linalg.norm(shoulder_vector[:2])  # x-y plane only
        
        # Shoulder depth (z-component indicates rotation from camera)
        shoulder_depth = abs(shoulder_vector[2]) if len(shoulder_vector) > 2 else 0
        
        # Shoulder angle relative to camera
        # Side-on: shoulders form line perpendicular to camera (high width, low depth)
        # Front-on: shoulders face camera directly (high width, variable depth)
        shoulder_angle = math.atan2(shoulder_vector[1], shoulder_vector[0]) * 180 / math.pi
        
        return {
            'shoulder_width': shoulder_width,
            'shoulder_depth': shoulder_depth,
            'shoulder_angle': shoulder_angle,
            'shoulder_ratio': shoulder_width / (shoulder_depth + 0.001)  # Avoid division by zero
        }
    
    def _analyze_body_proportions(self, landmarks: Dict) -> Dict:
        """Analyze apparent body proportions to determine viewing angle"""
        
        # Calculate body width (shoulder span)
        left_shoulder = landmarks['left_shoulder']
        right_shoulder = landmarks['right_shoulder']
        body_width = np.linalg.norm(right_shoulder[:2] - left_shoulder[:2])
        
        # Calculate apparent body depth (hip to shoulder center projection)
        left_hip = landmarks['left_hip']
        right_hip = landmarks['right_hip']
        hip_center = (left_hip + right_hip) / 2
        shoulder_center = (left_shoulder + right_shoulder) / 2
        
        # Project torso vector onto camera plane
        torso_vector = shoulder_center - hip_center
        torso_depth = abs(torso_vector[2]) if len(torso_vector) > 2 else 0
        torso_height = abs(torso_vector[1])
        
        # Width-to-depth ratio indicates viewing angle
        # Side-on: high width, low depth (high ratio)
        # Front-on: moderate width, moderate depth (medium ratio)
        width_depth_ratio = body_width / (torso_depth + 0.001)
        
        return {
            'body_width': body_width,
            'torso_depth': torso_depth,
            'torso_height': torso_height,
            'width_depth_ratio': width_depth_ratio
        }
    
    def _analyze_hip_orientation(self, landmarks: Dict) -> Dict:
        """Analyze hip orientation as secondary indicator"""
        
        left_hip = landmarks['left_hip']
        right_hip = landmarks['right_hip']
        
        hip_vector = right_hip - left_hip
        hip_width = np.linalg.norm(hip_vector[:2])
        hip_depth = abs(hip_vector[2]) if len(hip_vector) > 2 else 0
        
        hip_angle = math.atan2(hip_vector[1], hip_vector[0]) * 180 / math.pi
        
        return {
            'hip_width': hip_width,
            'hip_depth': hip_depth,
            'hip_angle': hip_angle,
            'hip_ratio': hip_width / (hip_depth + 0.001)
        }
    
    def _analyze_body_asymmetry(self, landmarks: Dict) -> Dict:
        """Analyze left/right body asymmetry to detect viewing angle"""
        
        # Calculate visibility scores for left vs right side
        left_visibility = self._calculate_side_visibility(landmarks, 'left')
        right_visibility = self._calculate_side_visibility(landmarks, 'right')
        
        # Asymmetry indicates angled view
        asymmetry_score = abs(left_visibility - right_visibility)
        dominant_side = 'left' if left_visibility > right_visibility else 'right'
        
        return {
            'left_visibility': left_visibility,
            'right_visibility': right_visibility,
            'asymmetry_score': asymmetry_score,
            'dominant_side': dominant_side
        }
    
    def _analyze_hand_positioning(self, landmarks: Dict) -> Dict:
        """Analyze hand/wrist positioning relative to body center"""
        
        # Body center reference
        nose = landmarks['nose']
        
        # Hand positions
        left_wrist = landmarks['left_wrist']
        right_wrist = landmarks['right_wrist']
        hand_center = (left_wrist + right_wrist) / 2
        
        # Hand offset from body center
        hand_offset = hand_center - nose
        
        # Lateral offset (x-axis) vs forward/back offset (z-axis)
        lateral_offset = abs(hand_offset[0])
        depth_offset = abs(hand_offset[2]) if len(hand_offset) > 2 else 0
        
        return {
            'hand_lateral_offset': lateral_offset,
            'hand_depth_offset': depth_offset,
            'hand_offset_ratio': lateral_offset / (depth_offset + 0.001)
        }
    
    def _calculate_side_visibility(self, landmarks: Dict, side: str) -> float:
        """Calculate visibility score for left or right side of body"""
        
        side_landmarks = [
            f'{side}_shoulder', f'{side}_elbow', f'{side}_wrist',
            f'{side}_hip', f'{side}_knee', f'{side}_ankle'
        ]
        
        visibility_scores = []
        for landmark_name in side_landmarks:
            if landmark_name in landmarks:
                # MediaPipe provides visibility score as 4th component
                landmark = landmarks[landmark_name]
                if len(landmark) > 3:
                    visibility_scores.append(landmark[3])
                else:
                    visibility_scores.append(1.0)  # Assume visible if no visibility score
        
        return np.mean(visibility_scores) if visibility_scores else 0.0
    
    def _aggregate_frame_metrics(self, frame_analyses: List[Dict]) -> Dict:
        """Aggregate metrics across all valid frames"""
        
        if not frame_analyses:
            return {}
            
        aggregated = {}
        
        # Get all metric keys from first frame
        metric_keys = frame_analyses[0]['metrics'].keys()
        
        # Calculate statistics for each metric
        for key in metric_keys:
            values = [frame['metrics'][key] for frame in frame_analyses if key in frame['metrics']]
            if values:
                aggregated[key] = {
                    'mean': np.mean(values),
                    'std': np.std(values),
                    'median': np.median(values),
                    'min': np.min(values),
                    'max': np.max(values)
                }
        
        return aggregated
    
    def _classify_camera_angle(self, metrics: Dict) -> Tuple[CameraAngle, float]:
        """Classify camera angle based on aggregated metrics"""
        
        if not metrics:
            return CameraAngle.UNKNOWN, 0.0
            
        # Initialize confidence scores for each angle type
        angle_scores = {
            CameraAngle.SIDE_ON: 0.0,
            CameraAngle.FRONT_ON: 0.0,
            CameraAngle.BEHIND: 0.0,
            CameraAngle.ANGLED_SIDE: 0.0,
            CameraAngle.ANGLED_FRONT: 0.0,
            CameraAngle.OVERHEAD: 0.0
        }
        
        # Scoring based on shoulder ratio (primary indicator)
        if 'shoulder_ratio' in metrics:
            shoulder_ratio = metrics['shoulder_ratio']['mean']
            
            # Side-on: Very high shoulder ratio (>5)
            if shoulder_ratio > 5:
                angle_scores[CameraAngle.SIDE_ON] += 0.4
            elif shoulder_ratio > 3:
                angle_scores[CameraAngle.ANGLED_SIDE] += 0.3
            
            # Front-on: Lower shoulder ratio (1-3)
            if 1 < shoulder_ratio < 3:
                angle_scores[CameraAngle.FRONT_ON] += 0.3
                angle_scores[CameraAngle.BEHIND] += 0.2
            elif 3 <= shoulder_ratio <= 5:
                angle_scores[CameraAngle.ANGLED_FRONT] += 0.3
        
        # Scoring based on width-depth ratio
        if 'width_depth_ratio' in metrics:
            width_ratio = metrics['width_depth_ratio']['mean']
            
            if width_ratio > 4:
                angle_scores[CameraAngle.SIDE_ON] += 0.3
            elif width_ratio > 2:
                angle_scores[CameraAngle.ANGLED_SIDE] += 0.2
            else:
                angle_scores[CameraAngle.FRONT_ON] += 0.2
                angle_scores[CameraAngle.BEHIND] += 0.2
        
        # Scoring based on asymmetry
        if 'asymmetry_score' in metrics:
            asymmetry = metrics['asymmetry_score']['mean']
            
            # High asymmetry suggests angled view
            if asymmetry > 0.3:
                angle_scores[CameraAngle.ANGLED_SIDE] += 0.2
                angle_scores[CameraAngle.ANGLED_FRONT] += 0.2
            else:
                # Low asymmetry suggests straight-on view
                angle_scores[CameraAngle.SIDE_ON] += 0.1
                angle_scores[CameraAngle.FRONT_ON] += 0.1
                angle_scores[CameraAngle.BEHIND] += 0.1
        
        # Distinguish front-on vs behind based on hand positioning
        if 'hand_offset_ratio' in metrics:
            hand_ratio = metrics['hand_offset_ratio']['mean']
            
            # Behind view: hands typically more centered
            if hand_ratio < 1:
                angle_scores[CameraAngle.BEHIND] += 0.2
            else:
                angle_scores[CameraAngle.FRONT_ON] += 0.1
        
        # Find best angle and confidence
        best_angle = max(angle_scores.keys(), key=lambda k: angle_scores[k])
        confidence = angle_scores[best_angle]
        
        # Ensure minimum confidence threshold
        if confidence < 0.3:
            return CameraAngle.UNKNOWN, confidence
            
        return best_angle, min(confidence, 1.0)
    
    def _extract_landmarks_3d(self, frame: np.ndarray) -> Dict:
        """Extract 3D landmarks from frame data"""
        landmarks = {}
        
        try:
            # MediaPipe frame format: 258 features (33 pose * 4 + 21*2 hands * 3)
            pose_data = frame[:132]  # First 132 elements are pose (33 * 4)
            
            for name, idx in self.landmarks.items():
                start_idx = idx * 4
                if start_idx + 3 < len(pose_data):
                    landmarks[name] = pose_data[start_idx:start_idx+4]  # x, y, z, visibility
                    
        except Exception as e:
            logger.warning(f"Error extracting landmarks: {e}")
            
        return landmarks
    
    def _validate_landmarks(self, landmarks: Dict) -> bool:
        """Validate that essential landmarks are present and valid"""
        
        essential_landmarks = ['nose', 'left_shoulder', 'right_shoulder', 'left_hip', 'right_hip']
        
        for landmark_name in essential_landmarks:
            if landmark_name not in landmarks:
                return False
                
            landmark = landmarks[landmark_name]
            
            # Check visibility score (4th component)
            if len(landmark) > 3 and landmark[3] < 0.3:
                return False
                
            # Check for reasonable coordinate values
            if np.any(np.isnan(landmark[:3])) or np.any(np.abs(landmark[:3]) > 2.0):
                return False
                
        return True
        
    def _get_landmark_3d(self, frame: np.ndarray, landmark_name: str) -> np.ndarray:
        """Extract 3D coordinates for a specific landmark"""
        if landmark_name not in self.landmarks:
            return np.array([0, 0, 0])
            
        idx = self.landmarks[landmark_name]
        start_idx = idx * 4
        
        if start_idx + 2 < len(frame):
            return frame[start_idx:start_idx+3]  # x, y, z only
        else:
            return np.array([0, 0, 0])
    
    def _create_result(self, angle_type: CameraAngle, confidence: float, 
                      metrics: Dict, frame_analyses: List) -> Dict:
        """Create standardized result dictionary"""
        return {
            'angle_type': angle_type,
            'confidence': confidence,
            'metrics': metrics,
            'frame_analyses': frame_analyses,
            'transformation_needed': angle_type != CameraAngle.SIDE_ON,
            'reliability_score': self._calculate_reliability_score(confidence, len(frame_analyses))
        }
    
    def _calculate_reliability_score(self, confidence: float, frame_count: int) -> float:
        """Calculate overall reliability score for the detection"""
        
        # Base score from confidence
        base_score = confidence
        
        # Boost score for more frames analyzed
        frame_boost = min(0.2, frame_count / 100)  # Up to 0.2 boost for 100+ frames
        
        # Penalty for very few frames
        frame_penalty = max(0, 0.3 - frame_count / 10) if frame_count < 10 else 0
        
        reliability = base_score + frame_boost - frame_penalty
        
        return max(0.0, min(1.0, reliability))

def get_rotation_matrix_for_angle(camera_angle: CameraAngle) -> np.ndarray:
    """
    Get rotation matrix to transform from detected angle to canonical side-on view.
    
    Returns 3x3 rotation matrix for coordinate transformation.
    """
    
    if camera_angle == CameraAngle.SIDE_ON:
        return np.eye(3)  # No transformation needed
    
    elif camera_angle == CameraAngle.FRONT_ON:
        # Rotate 90 degrees around Y-axis
        return np.array([
            [0, 0, 1],
            [0, 1, 0],
            [-1, 0, 0]
        ])
    
    elif camera_angle == CameraAngle.BEHIND:
        # Rotate 90 degrees around Y-axis (opposite direction)
        return np.array([
            [0, 0, -1],
            [0, 1, 0],
            [1, 0, 0]
        ])
    
    elif camera_angle == CameraAngle.ANGLED_SIDE:
        # Rotate 45 degrees around Y-axis
        cos45 = np.cos(np.pi / 4)
        sin45 = np.sin(np.pi / 4)
        return np.array([
            [cos45, 0, sin45],
            [0, 1, 0],
            [-sin45, 0, cos45]
        ])
    
    elif camera_angle == CameraAngle.ANGLED_FRONT:
        # Rotate 135 degrees around Y-axis
        cos135 = np.cos(3 * np.pi / 4)
        sin135 = np.sin(3 * np.pi / 4)
        return np.array([
            [cos135, 0, sin135],
            [0, 1, 0],
            [-sin135, 0, cos135]
        ])
    
    else:
        # Unknown or overhead - return identity
        return np.eye(3)