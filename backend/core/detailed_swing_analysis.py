"""
Enhanced Swing Analysis with Detailed Biomechanics
Extracts specific flaw data for dynamic UI generation
"""

import cv2
import numpy as np
import mediapipe as mp
import json
from typing import Dict, List, Tuple, Optional
from enum import Enum
from dataclasses import dataclass, asdict

class SwingFlaw(Enum):
    LEAD_ARM_BEND = "lead_arm_bend"
    SPINE_ANGLE = "spine_angle"
    HEAD_MOVEMENT = "head_movement"
    HIP_ROTATION = "hip_rotation"
    WEIGHT_SHIFT = "weight_shift"
    CLUB_PATH = "club_path"
    TEMPO = "tempo"
    BALANCE = "balance"

class SwingPhase(Enum):
    SETUP = "setup"
    BACKSWING = "backswing" 
    IMPACT = "impact"
    FOLLOW_THROUGH = "follow_through"

@dataclass
class BiomechanicMeasurement:
    """Individual biomechanic measurement with reference values"""
    name: str
    current_value: float
    optimal_range: Tuple[float, float]  # (min, max)
    unit: str
    severity: str  # "pass", "minor", "major", "critical"
    description: str
    frame_indices: List[int]  # Frames where this issue occurs

@dataclass
class PoseLandmark:
    """3D pose landmark with confidence"""
    x: float
    y: float
    z: float
    confidence: float

@dataclass
class SwingFrameAnalysis:
    """Analysis of a single frame"""
    frame_index: int
    timestamp: float
    pose_landmarks: Dict[str, PoseLandmark]
    measurements: Dict[str, float]
    phase: SwingPhase
    issues: List[str]

@dataclass
class DetailedSwingAnalysis:
    """Complete detailed swing analysis"""
    overall_classification: str
    confidence: float
    frame_analyses: List[SwingFrameAnalysis]
    biomechanic_measurements: List[BiomechanicMeasurement]
    priority_flaws: List[Dict]
    pose_sequence: List[Dict]  # For video overlay
    optimal_pose_reference: List[Dict]  # Ideal swing sequence
    comparison_data: Dict  # Frame-by-frame comparison

class DetailedSwingAnalyzer:
    def __init__(self):
        self.mp_pose = mp.solutions.pose
        self.pose = self.mp_pose.Pose(
            static_image_mode=False,
            model_complexity=2,
            enable_segmentation=False,
            min_detection_confidence=0.7,
            min_tracking_confidence=0.5
        )
        
        # Define ideal swing biomechanics
        self.optimal_measurements = {
            "lead_arm_angle": (170, 180),  # degrees - should be straight
            "spine_angle": (25, 35),       # degrees - forward lean
            "head_movement": (0, 5),       # cm - minimal movement
            "hip_rotation": (45, 60),      # degrees - good rotation
            "weight_shift": (60, 80),      # % to front foot at impact
            "club_path": (-2, 2),          # degrees - neutral path
            "tempo_ratio": (2.5, 3.5),     # backswing:downswing ratio
        }
    
    def analyze_swing_detailed(self, video_path: str) -> DetailedSwingAnalysis:
        """Perform detailed swing analysis with biomechanics extraction"""
        
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        
        frame_analyses = []
        pose_sequence = []
        frame_index = 0
        
        print(f"🎯 Starting detailed swing analysis...")
        
        while cap.read()[0]:
            ret, frame = cap.read()
            if not ret:
                break
                
            # Process pose
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = self.pose.process(frame_rgb)
            
            if results.pose_landmarks:
                # Extract landmarks
                landmarks = self._extract_landmarks(results.pose_landmarks)
                
                # Calculate measurements
                measurements = self._calculate_frame_measurements(landmarks)
                
                # Determine swing phase
                phase = self._determine_swing_phase(measurements, frame_index, fps)
                
                # Detect issues in this frame
                issues = self._detect_frame_issues(measurements, phase)
                
                # Create frame analysis
                frame_analysis = SwingFrameAnalysis(
                    frame_index=frame_index,
                    timestamp=frame_index / fps,
                    pose_landmarks=landmarks,
                    measurements=measurements,
                    phase=phase,
                    issues=issues
                )
                
                frame_analyses.append(frame_analysis)
                
                # Store pose for overlay
                pose_data = self._pose_to_overlay_data(landmarks, frame.shape)
                pose_sequence.append({
                    'frame': frame_index,
                    'landmarks': pose_data,
                    'issues': issues
                })
            
            frame_index += 1
        
        cap.release()
        
        # Analyze biomechanics across all frames
        biomechanic_measurements = self._analyze_biomechanics(frame_analyses)
        
        # Generate priority flaws
        priority_flaws = self._generate_priority_flaws(biomechanic_measurements)
        
        # Create optimal reference
        optimal_pose_reference = self._generate_optimal_reference(len(frame_analyses))
        
        # Generate comparison data
        comparison_data = self._generate_comparison_data(frame_analyses, optimal_pose_reference)
        
        # Overall classification (integrate with existing model)
        overall_classification = self._classify_overall_swing(biomechanic_measurements)
        confidence = self._calculate_overall_confidence(biomechanic_measurements)
        
        return DetailedSwingAnalysis(
            overall_classification=overall_classification,
            confidence=confidence,
            frame_analyses=frame_analyses,
            biomechanic_measurements=biomechanic_measurements,
            priority_flaws=priority_flaws,
            pose_sequence=pose_sequence,
            optimal_pose_reference=optimal_pose_reference,
            comparison_data=comparison_data
        )
    
    def _extract_landmarks(self, pose_landmarks) -> Dict[str, PoseLandmark]:
        """Extract key landmarks for golf swing analysis"""
        landmarks = {}
        
        # Key landmarks for golf swing
        key_points = {
            'nose': 0,
            'left_shoulder': 11, 'right_shoulder': 12,
            'left_elbow': 13, 'right_elbow': 14,
            'left_wrist': 15, 'right_wrist': 16,
            'left_hip': 23, 'right_hip': 24,
            'left_knee': 25, 'right_knee': 26,
            'left_ankle': 27, 'right_ankle': 28
        }
        
        for name, idx in key_points.items():
            lm = pose_landmarks.landmark[idx]
            landmarks[name] = PoseLandmark(
                x=lm.x, y=lm.y, z=lm.z, confidence=lm.visibility
            )
        
        return landmarks
    
    def _calculate_frame_measurements(self, landmarks: Dict[str, PoseLandmark]) -> Dict[str, float]:
        """Calculate biomechanic measurements for a single frame"""
        measurements = {}
        
        # Lead arm angle (assuming right-handed golfer)
        lead_arm_angle = self._calculate_arm_angle(
            landmarks['left_shoulder'], landmarks['left_elbow'], landmarks['left_wrist']
        )
        measurements['lead_arm_angle'] = lead_arm_angle
        
        # Spine angle
        spine_angle = self._calculate_spine_angle(
            landmarks['nose'], landmarks['left_hip'], landmarks['right_hip']
        )
        measurements['spine_angle'] = spine_angle
        
        # Head position (for stability tracking)
        measurements['head_x'] = landmarks['nose'].x
        measurements['head_y'] = landmarks['nose'].y
        
        # Hip rotation angle
        hip_rotation = self._calculate_hip_rotation(
            landmarks['left_hip'], landmarks['right_hip']
        )
        measurements['hip_rotation'] = hip_rotation
        
        # Weight distribution (based on shoulder and hip alignment)
        weight_shift = self._calculate_weight_shift(landmarks)
        measurements['weight_shift'] = weight_shift
        
        return measurements
    
    def _calculate_arm_angle(self, shoulder: PoseLandmark, elbow: PoseLandmark, wrist: PoseLandmark) -> float:
        """Calculate angle at elbow joint"""
        # Vector from elbow to shoulder
        v1 = np.array([shoulder.x - elbow.x, shoulder.y - elbow.y])
        # Vector from elbow to wrist  
        v2 = np.array([wrist.x - elbow.x, wrist.y - elbow.y])
        
        # Calculate angle
        cos_angle = np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2))
        angle = np.arccos(np.clip(cos_angle, -1.0, 1.0))
        
        return np.degrees(angle)
    
    def _calculate_spine_angle(self, nose: PoseLandmark, left_hip: PoseLandmark, right_hip: PoseLandmark) -> float:
        """Calculate spine forward lean angle"""
        # Hip center
        hip_center_x = (left_hip.x + right_hip.x) / 2
        hip_center_y = (left_hip.y + right_hip.y) / 2
        
        # Spine vector (from hip center to nose)
        spine_vector = np.array([nose.x - hip_center_x, nose.y - hip_center_y])
        vertical = np.array([0, -1])  # Negative because y increases downward
        
        cos_angle = np.dot(spine_vector, vertical) / (np.linalg.norm(spine_vector) * np.linalg.norm(vertical))
        angle = np.arccos(np.clip(cos_angle, -1.0, 1.0))
        
        return np.degrees(angle)
    
    def _calculate_hip_rotation(self, left_hip: PoseLandmark, right_hip: PoseLandmark) -> float:
        """Calculate hip rotation relative to camera"""
        hip_line = np.array([right_hip.x - left_hip.x, right_hip.y - left_hip.y])
        horizontal = np.array([1, 0])
        
        cos_angle = np.dot(hip_line, horizontal) / (np.linalg.norm(hip_line) * np.linalg.norm(horizontal))
        angle = np.arccos(np.clip(cos_angle, -1.0, 1.0))
        
        return np.degrees(angle)
    
    def _calculate_weight_shift(self, landmarks: Dict[str, PoseLandmark]) -> float:
        """Estimate weight distribution based on body alignment"""
        # Simplified weight shift calculation based on shoulder and hip positions
        left_side = (landmarks['left_shoulder'].x + landmarks['left_hip'].x) / 2
        right_side = (landmarks['right_shoulder'].x + landmarks['right_hip'].x) / 2
        center = (left_side + right_side) / 2
        
        # Convert to percentage (50% = centered, >50% = weight forward)
        weight_forward = 50 + (center - 0.5) * 100
        
        return np.clip(weight_forward, 0, 100)
    
    def _determine_swing_phase(self, measurements: Dict[str, float], frame_index: int, fps: float) -> SwingPhase:
        """Determine which phase of the swing this frame represents"""
        # Simplified phase detection based on arm position and time
        # In a real implementation, this would use more sophisticated analysis
        
        timestamp = frame_index / fps
        
        if timestamp < 0.5:
            return SwingPhase.SETUP
        elif timestamp < 1.5:
            return SwingPhase.BACKSWING
        elif timestamp < 2.0:
            return SwingPhase.IMPACT
        else:
            return SwingPhase.FOLLOW_THROUGH
    
    def _detect_frame_issues(self, measurements: Dict[str, float], phase: SwingPhase) -> List[str]:
        """Detect specific issues in this frame"""
        issues = []
        
        # Lead arm bend check
        if measurements.get('lead_arm_angle', 180) < 160:
            issues.append('excessive_lead_arm_bend')
        
        # Spine angle check
        spine_angle = measurements.get('spine_angle', 30)
        if spine_angle < 20 or spine_angle > 40:
            issues.append('poor_spine_angle')
        
        # Phase-specific checks
        if phase == SwingPhase.IMPACT:
            if measurements.get('weight_shift', 50) < 60:
                issues.append('insufficient_weight_shift')
        
        return issues
    
    def _analyze_biomechanics(self, frame_analyses: List[SwingFrameAnalysis]) -> List[BiomechanicMeasurement]:
        """Analyze biomechanics across all frames"""
        measurements = []
        
        # Lead arm analysis
        lead_arm_angles = [fa.measurements.get('lead_arm_angle', 180) for fa in frame_analyses]
        min_lead_arm = min(lead_arm_angles)
        frames_with_bend = [i for i, angle in enumerate(lead_arm_angles) if angle < 160]
        
        severity = "pass"
        if min_lead_arm < 140:
            severity = "critical"
        elif min_lead_arm < 150:
            severity = "major"
        elif min_lead_arm < 160:
            severity = "minor"
        
        measurements.append(BiomechanicMeasurement(
            name="Lead Arm",
            current_value=min_lead_arm,
            optimal_range=self.optimal_measurements["lead_arm_angle"],
            unit="degrees",
            severity=severity,
            description="Your lead arm bends excessively in your backswing making it harder to hit solid shots" if severity != "pass" else "Good lead arm extension",
            frame_indices=frames_with_bend
        ))
        
        # Spine angle analysis
        spine_angles = [fa.measurements.get('spine_angle', 30) for fa in frame_analyses]
        avg_spine_angle = np.mean(spine_angles)
        
        spine_severity = "pass"
        if avg_spine_angle < 20 or avg_spine_angle > 40:
            spine_severity = "major"
        elif avg_spine_angle < 25 or avg_spine_angle > 35:
            spine_severity = "minor"
        
        measurements.append(BiomechanicMeasurement(
            name="Spine Angle",
            current_value=avg_spine_angle,
            optimal_range=self.optimal_measurements["spine_angle"],
            unit="degrees",
            severity=spine_severity,
            description="Maintain proper spine angle for consistent contact" if spine_severity != "pass" else "Good spine angle maintained",
            frame_indices=list(range(len(frame_analyses)))
        ))
        
        # Add more biomechanic measurements...
        # Head movement, hip rotation, weight shift, etc.
        
        return measurements
    
    def _generate_priority_flaws(self, biomechanic_measurements: List[BiomechanicMeasurement]) -> List[Dict]:
        """Generate priority-ordered list of flaws"""
        # Sort by severity and impact
        severity_order = {"critical": 4, "major": 3, "minor": 2, "pass": 1}
        
        flaws = []
        priority = 1
        
        for measurement in sorted(biomechanic_measurements, 
                                key=lambda x: severity_order[x.severity], 
                                reverse=True):
            if measurement.severity != "pass":
                flaws.append({
                    "priority": priority,
                    "flaw": measurement.name,
                    "result": "Improve",
                    "severity": measurement.severity,
                    "description": measurement.description,
                    "current_value": measurement.current_value,
                    "optimal_range": measurement.optimal_range,
                    "frame_indices": measurement.frame_indices
                })
                priority += 1
        
        return flaws
    
    def _pose_to_overlay_data(self, landmarks: Dict[str, PoseLandmark], frame_shape: Tuple[int, int, int]) -> Dict:
        """Convert pose landmarks to overlay data for UI"""
        height, width = frame_shape[:2]
        
        overlay_data = {}
        for name, landmark in landmarks.items():
            overlay_data[name] = {
                'x': landmark.x * width,
                'y': landmark.y * height,
                'confidence': landmark.confidence
            }
        
        return overlay_data
    
    def _generate_optimal_reference(self, num_frames: int) -> List[Dict]:
        """Generate optimal swing pose sequence for comparison"""
        # This would ideally load from a database of professional swings
        # For now, generate a simplified reference
        
        optimal_sequence = []
        for frame_idx in range(num_frames):
            # Generate ideal pose based on swing phase
            phase_progress = frame_idx / num_frames
            
            optimal_pose = self._generate_ideal_pose_for_progress(phase_progress)
            optimal_sequence.append({
                'frame': frame_idx,
                'landmarks': optimal_pose,
                'phase': self._progress_to_phase(phase_progress)
            })
        
        return optimal_sequence
    
    def _generate_ideal_pose_for_progress(self, progress: float) -> Dict:
        """Generate ideal pose landmarks for a given swing progress"""
        # Simplified ideal pose generation
        # In practice, this would be based on biomechanical models
        
        return {
            'left_shoulder': {'x': 300 + progress * 50, 'y': 200, 'confidence': 1.0},
            'right_shoulder': {'x': 400 - progress * 30, 'y': 200, 'confidence': 1.0},
            'left_elbow': {'x': 250 + progress * 100, 'y': 250, 'confidence': 1.0},
            'right_elbow': {'x': 450 - progress * 80, 'y': 250, 'confidence': 1.0},
            # ... more landmarks
        }
    
    def _progress_to_phase(self, progress: float) -> str:
        """Convert progress (0-1) to swing phase"""
        if progress < 0.2:
            return "setup"
        elif progress < 0.6:
            return "backswing"
        elif progress < 0.8:
            return "impact"
        else:
            return "follow_through"
    
    def _generate_comparison_data(self, frame_analyses: List[SwingFrameAnalysis], 
                                optimal_reference: List[Dict]) -> Dict:
        """Generate frame-by-frame comparison between user and optimal"""
        comparison = {
            'frame_comparisons': [],
            'deviation_summary': {},
            'improvement_areas': []
        }
        
        for i, frame_analysis in enumerate(frame_analyses):
            if i < len(optimal_reference):
                optimal_frame = optimal_reference[i]
                
                # Calculate deviations
                deviations = self._calculate_pose_deviations(
                    frame_analysis.pose_landmarks, 
                    optimal_frame['landmarks']
                )
                
                comparison['frame_comparisons'].append({
                    'frame': i,
                    'deviations': deviations,
                    'issues': frame_analysis.issues
                })
        
        return comparison
    
    def _calculate_pose_deviations(self, user_pose: Dict[str, PoseLandmark], 
                                 optimal_pose: Dict) -> Dict:
        """Calculate deviations between user pose and optimal pose"""
        deviations = {}
        
        for landmark_name in user_pose:
            if landmark_name in optimal_pose:
                user_lm = user_pose[landmark_name]
                optimal_lm = optimal_pose[landmark_name]
                
                # Calculate distance deviation
                distance = np.sqrt(
                    (user_lm.x - optimal_lm['x']/640)**2 + 
                    (user_lm.y - optimal_lm['y']/480)**2
                )
                
                deviations[landmark_name] = {
                    'distance': distance,
                    'x_diff': abs(user_lm.x - optimal_lm['x']/640),
                    'y_diff': abs(user_lm.y - optimal_lm['y']/480)
                }
        
        return deviations
    
    def _classify_overall_swing(self, biomechanic_measurements: List[BiomechanicMeasurement]) -> str:
        """Classify overall swing based on biomechanic analysis"""
        # Count severity levels
        critical_count = sum(1 for m in biomechanic_measurements if m.severity == "critical")
        major_count = sum(1 for m in biomechanic_measurements if m.severity == "major")
        
        if critical_count > 0:
            return "needs_major_improvement"
        elif major_count > 2:
            return "too_steep"  # or other specific classification
        else:
            return "on_plane"
    
    def _calculate_overall_confidence(self, biomechanic_measurements: List[BiomechanicMeasurement]) -> float:
        """Calculate overall confidence in the analysis"""
        # Base confidence on measurement quality and consistency
        return 0.85  # Placeholder


def analyze_swing_with_details(video_path: str) -> Dict:
    """Main function to analyze swing with detailed biomechanics"""
    
    analyzer = DetailedSwingAnalyzer()
    detailed_analysis = analyzer.analyze_swing_detailed(video_path)
    
    # Convert to dictionary for API response
    result = {
        "predicted_label": detailed_analysis.overall_classification,
        "confidence": detailed_analysis.confidence,
        "detailed_biomechanics": [asdict(bm) for bm in detailed_analysis.biomechanic_measurements],
        "priority_flaws": detailed_analysis.priority_flaws,
        "pose_sequence": detailed_analysis.pose_sequence,
        "optimal_reference": detailed_analysis.optimal_pose_reference,
        "comparison_data": detailed_analysis.comparison_data,
        "frame_count": len(detailed_analysis.frame_analyses)
    }
    
    return result


if __name__ == "__main__":
    # Test the detailed analysis
    video_path = "test_swing.mp4"
    result = analyze_swing_with_details(video_path)
    
    print("Detailed Analysis Results:")
    print(f"Classification: {result['predicted_label']}")
    print(f"Confidence: {result['confidence']}")
    print(f"Priority Flaws: {len(result['priority_flaws'])}")
    print(f"Frames Analyzed: {result['frame_count']}")