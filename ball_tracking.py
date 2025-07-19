#!/usr/bin/env python3
"""
Physics-Based Ball Tracking System
Automatically detects golf ball and predicts trajectory based on swing analysis
"""

import cv2
import numpy as np
import matplotlib.pyplot as plt
from typing import Tuple, List, Optional, Dict
import math
from scipy.optimize import curve_fit
from scipy.signal import savgol_filter

class GolfBallTracker:
    """Advanced golf ball detection and trajectory analysis"""
    
    def __init__(self):
        # Ball detection parameters
        self.ball_size_range = (5, 50)  # Min/max radius in pixels
        self.white_threshold = (200, 255, 200, 255, 200, 255)  # BGR ranges for white ball
        self.detection_confidence = 0.7
        
        # Physics constants
        self.gravity = 9.81  # m/s²
        self.air_resistance = 0.5  # Drag coefficient
        self.ball_mass = 0.0459  # kg (regulation golf ball)
        self.ball_diameter = 0.04267  # meters
        
        # Conversion factors (will be calibrated from video)
        self.pixels_per_meter = 100  # Default, should be calibrated
        self.fps = 30  # Frames per second
        
    def detect_ball_in_frame(self, frame: np.ndarray) -> Optional[Tuple[int, int, int]]:
        """
        Detect golf ball in a single frame
        Returns: (x, y, radius) or None if not found
        """
        
        # Convert to HSV for better white detection
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        
        # Create mask for white objects
        lower_white = np.array([0, 0, 200])
        upper_white = np.array([180, 30, 255])
        white_mask = cv2.inRange(hsv, lower_white, upper_white)
        
        # Apply morphological operations to clean up mask
        kernel = np.ones((3, 3), np.uint8)
        white_mask = cv2.morphologyEx(white_mask, cv2.MORPH_OPEN, kernel)
        white_mask = cv2.morphologyEx(white_mask, cv2.MORPH_CLOSE, kernel)
        
        # Find contours
        contours, _ = cv2.findContours(white_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        # Filter contours by size and circularity
        ball_candidates = []
        
        for contour in contours:
            area = cv2.contourArea(contour)
            if area < 20:  # Too small
                continue
                
            # Check circularity
            perimeter = cv2.arcLength(contour, True)
            if perimeter == 0:
                continue
                
            circularity = 4 * np.pi * area / (perimeter * perimeter)
            
            if circularity > 0.6:  # Reasonably circular
                # Get bounding circle
                (x, y), radius = cv2.minEnclosingCircle(contour)
                
                if self.ball_size_range[0] <= radius <= self.ball_size_range[1]:
                    ball_candidates.append({
                        'center': (int(x), int(y)),
                        'radius': int(radius),
                        'circularity': circularity,
                        'area': area
                    })
        
        # Return the most circular candidate with reasonable size
        if ball_candidates:
            best_candidate = max(ball_candidates, key=lambda x: x['circularity'])
            return (best_candidate['center'][0], best_candidate['center'][1], best_candidate['radius'])
        
        return None
    
    def track_ball_in_video(self, video_path: str) -> List[Dict]:
        """
        Track golf ball throughout entire video
        Returns list of ball positions with timestamps
        """
        
        cap = cv2.VideoCapture(video_path)
        
        if not cap.isOpened():
            raise ValueError(f"Could not open video: {video_path}")
        
        # Get video properties
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        print(f"📹 Processing video: {total_frames} frames at {fps} FPS")
        
        ball_positions = []
        frame_number = 0
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            timestamp = frame_number / fps
            
            # Detect ball in current frame
            ball_detection = self.detect_ball_in_frame(frame)
            
            if ball_detection:
                x, y, radius = ball_detection
                ball_positions.append({
                    'frame': frame_number,
                    'timestamp': timestamp,
                    'x': x,
                    'y': y,
                    'radius': radius,
                    'detected': True
                })
            else:
                ball_positions.append({
                    'frame': frame_number,
                    'timestamp': timestamp,
                    'x': None,
                    'y': None,
                    'radius': None,
                    'detected': False
                })
            
            frame_number += 1
            
            # Progress indicator
            if frame_number % 30 == 0:
                progress = (frame_number / total_frames) * 100
                print(f"  Processing frame {frame_number}/{total_frames} ({progress:.1f}%)")
        
        cap.release()
        
        # Filter and smooth ball positions
        valid_positions = [pos for pos in ball_positions if pos['detected']]
        
        print(f"✅ Ball detected in {len(valid_positions)}/{total_frames} frames ({len(valid_positions)/total_frames*100:.1f}%)")
        
        return ball_positions
    
    def analyze_ball_trajectory(self, ball_positions: List[Dict]) -> Dict:
        """
        Analyze ball flight trajectory and predict physics
        """
        
        # Extract valid positions
        valid_positions = [pos for pos in ball_positions if pos['detected']]
        
        if len(valid_positions) < 5:
            return {"error": "Insufficient ball detections for trajectory analysis"}
        
        # Extract coordinates and timestamps
        times = np.array([pos['timestamp'] for pos in valid_positions])
        x_coords = np.array([pos['x'] for pos in valid_positions])
        y_coords = np.array([pos['y'] for pos in valid_positions])
        
        # Smooth trajectories
        if len(times) > 5:
            window_length = min(5, len(times) if len(times) % 2 == 1 else len(times) - 1)
            x_smooth = savgol_filter(x_coords, window_length, 2)
            y_smooth = savgol_filter(y_coords, window_length, 2)
        else:
            x_smooth = x_coords
            y_smooth = y_coords
        
        # Calculate velocities (pixels per second)
        dt = np.diff(times)
        vx = np.diff(x_smooth) / dt
        vy = np.diff(y_smooth) / dt
        
        # Calculate accelerations
        if len(vx) > 1:
            ax = np.diff(vx) / dt[:-1]
            ay = np.diff(vy) / dt[:-1]
        else:
            ax = np.array([0])
            ay = np.array([0])
        
        # Physics analysis
        trajectory_analysis = self._analyze_physics(
            times, x_smooth, y_smooth, vx, vy, ax, ay
        )
        
        return {
            'detection_rate': len(valid_positions) / len(ball_positions),
            'trajectory_points': len(valid_positions),
            'flight_time': times[-1] - times[0] if len(times) > 1 else 0,
            'physics_analysis': trajectory_analysis,
            'raw_data': {
                'times': times.tolist(),
                'x_coords': x_coords.tolist(),
                'y_coords': y_coords.tolist(),
                'x_smooth': x_smooth.tolist(),
                'y_smooth': y_smooth.tolist(),
                'velocities_x': vx.tolist(),
                'velocities_y': vy.tolist()
            }
        }
    
    def _analyze_physics(self, times, x, y, vx, vy, ax, ay) -> Dict:
        """Analyze ball flight physics"""
        
        if len(times) < 3:
            return {"error": "Insufficient data for physics analysis"}
        
        # Initial velocity estimate (first few frames)
        initial_vx = np.mean(vx[:3]) if len(vx) >= 3 else vx[0] if len(vx) > 0 else 0
        initial_vy = np.mean(vy[:3]) if len(vy) >= 3 else vy[0] if len(vy) > 0 else 0
        
        # Convert pixel velocities to real-world (rough estimate)
        # This would need calibration in a real system
        scale_factor = 0.1  # meters per pixel (rough estimate)
        real_vx = initial_vx * scale_factor
        real_vy = -initial_vy * scale_factor  # Negative because Y increases downward in images
        
        # Calculate launch angle and speed
        launch_speed = math.sqrt(real_vx**2 + real_vy**2)
        launch_angle = math.degrees(math.atan2(real_vy, real_vx))
        
        # Estimate trajectory parameters (simplified physics)
        try:
            # Maximum height (assuming parabolic trajectory)
            if real_vy > 0:
                max_height_time = real_vy / self.gravity
                max_height = real_vy * max_height_time - 0.5 * self.gravity * max_height_time**2
            else:
                max_height_time = 0
                max_height = 0
            
            # Range estimate (ignoring air resistance)
            if launch_angle > 0:
                range_estimate = (real_vx * real_vy * 2) / self.gravity
            else:
                range_estimate = 0
            
            # Flight time estimate
            if real_vy > 0:
                flight_time_estimate = 2 * real_vy / self.gravity
            else:
                flight_time_estimate = times[-1] - times[0]
            
        except:
            max_height = 0
            range_estimate = 0
            flight_time_estimate = 0
            max_height_time = 0
        
        return {
            'launch_speed_ms': abs(launch_speed),
            'launch_angle_degrees': launch_angle,
            'initial_velocity_x': real_vx,
            'initial_velocity_y': real_vy,
            'estimated_max_height': max_height,
            'estimated_range': range_estimate,
            'estimated_flight_time': flight_time_estimate,
            'actual_flight_time': times[-1] - times[0],
            'trajectory_type': self._classify_trajectory(launch_angle, launch_speed)
        }
    
    def _classify_trajectory(self, launch_angle: float, speed: float) -> str:
        """Classify the type of golf shot based on trajectory"""
        
        if speed < 10:
            return "Short game shot (chip/pitch)"
        elif launch_angle < 5:
            return "Low trajectory (punch shot or topped ball)"
        elif launch_angle < 15:
            return "Low-medium trajectory (driving iron or long iron)"
        elif launch_angle < 25:
            return "Medium trajectory (mid iron)"
        elif launch_angle < 35:
            return "High trajectory (short iron or wedge)"
        elif launch_angle > 45:
            return "Very high trajectory (possible mishit or lob shot)"
        else:
            return "Standard trajectory"
    
    def predict_landing_spot(self, ball_positions: List[Dict], frame_shape: Tuple[int, int]) -> Optional[Tuple[int, int]]:
        """
        Predict where the ball will land based on current trajectory
        """
        
        valid_positions = [pos for pos in ball_positions if pos['detected']]
        
        if len(valid_positions) < 5:
            return None
        
        # Get recent trajectory points
        recent_points = valid_positions[-5:]
        
        x_coords = [pos['x'] for pos in recent_points]
        y_coords = [pos['y'] for pos in recent_points]
        times = [pos['timestamp'] for pos in recent_points]
        
        # Fit polynomial to recent trajectory
        try:
            # Fit parabola to Y coordinates vs X coordinates
            z = np.polyfit(x_coords, y_coords, 2)
            poly = np.poly1d(z)
            
            # Find where trajectory intersects with ground level
            # Assume ground is at bottom of frame
            ground_level = frame_shape[0] - 50  # 50 pixels from bottom
            
            # Solve for x when y = ground_level
            # poly(x) = ax² + bx + c = ground_level
            # ax² + bx + (c - ground_level) = 0
            a, b, c = z
            discriminant = b**2 - 4*a*(c - ground_level)
            
            if discriminant >= 0 and a != 0:
                x1 = (-b + math.sqrt(discriminant)) / (2*a)
                x2 = (-b - math.sqrt(discriminant)) / (2*a)
                
                # Choose the solution that's ahead of current position
                current_x = x_coords[-1]
                landing_x = x1 if x1 > current_x else x2
                
                # Ensure landing point is within frame
                if 0 <= landing_x <= frame_shape[1]:
                    return (int(landing_x), int(ground_level))
            
        except:
            pass
        
        return None
    
    def create_trajectory_visualization(self, ball_positions: List[Dict], 
                                      analysis: Dict, output_path: str):
        """Create visualization of ball trajectory and analysis"""
        
        valid_positions = [pos for pos in ball_positions if pos['detected']]
        
        if len(valid_positions) < 3:
            print("⚠️ Insufficient data for visualization")
            return
        
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        
        times = [pos['timestamp'] for pos in valid_positions]
        x_coords = [pos['x'] for pos in valid_positions]
        y_coords = [pos['y'] for pos in valid_positions]
        
        # Plot 1: 2D trajectory
        ax1.plot(x_coords, y_coords, 'bo-', markersize=3, linewidth=1)
        ax1.set_xlabel('X Position (pixels)')
        ax1.set_ylabel('Y Position (pixels)')
        ax1.set_title('Ball Trajectory (2D Path)')
        ax1.grid(True, alpha=0.3)
        ax1.invert_yaxis()  # Invert Y axis to match image coordinates
        
        # Plot 2: X position vs time
        ax2.plot(times, x_coords, 'r-', linewidth=2)
        ax2.set_xlabel('Time (seconds)')
        ax2.set_ylabel('X Position (pixels)')
        ax2.set_title('Horizontal Movement')
        ax2.grid(True, alpha=0.3)
        
        # Plot 3: Y position vs time
        ax3.plot(times, y_coords, 'g-', linewidth=2)
        ax3.set_xlabel('Time (seconds)')
        ax3.set_ylabel('Y Position (pixels)')
        ax3.set_title('Vertical Movement')
        ax3.grid(True, alpha=0.3)
        ax3.invert_yaxis()
        
        # Plot 4: Physics analysis text
        ax4.axis('off')
        if 'physics_analysis' in analysis and 'error' not in analysis['physics_analysis']:
            physics = analysis['physics_analysis']
            analysis_text = f"""
🏌️ BALL FLIGHT ANALYSIS

Launch Speed: {physics['launch_speed_ms']:.1f} m/s
Launch Angle: {physics['launch_angle_degrees']:.1f}°
Trajectory Type: {physics['trajectory_type']}

Estimated Max Height: {physics['estimated_max_height']:.1f} m
Estimated Range: {physics['estimated_range']:.1f} m
Flight Time: {physics['actual_flight_time']:.2f} s

Detection Rate: {analysis['detection_rate']*100:.1f}%
Total Points: {analysis['trajectory_points']}
            """
        else:
            analysis_text = "❌ Insufficient data for physics analysis"
        
        ax4.text(0.1, 0.9, analysis_text, transform=ax4.transAxes, 
                fontsize=12, verticalalignment='top', fontfamily='monospace')
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        print(f"📊 Trajectory visualization saved to: {output_path}")

def main():
    """Test ball tracking system"""
    
    print("🏌️ Golf Ball Tracking System Test")
    print("=" * 50)
    
    tracker = GolfBallTracker()
    
    # This would normally be run on a real golf swing video
    print("📹 Ball tracking system ready!")
    print("To use: tracker.track_ball_in_video('path/to/golf_video.mp4')")
    
    # Create a simple test
    print("\n🧪 Creating synthetic test data...")
    
    # Simulate ball trajectory data
    test_positions = []
    for i in range(30):
        t = i * 0.1  # 10 FPS
        x = 100 + 50 * t  # Moving right
        y = 200 + 20 * t - 4.9 * t**2  # Parabolic motion
        
        test_positions.append({
            'frame': i,
            'timestamp': t,
            'x': int(x),
            'y': int(y),
            'radius': 8,
            'detected': True
        })
    
    # Analyze synthetic trajectory
    analysis = tracker.analyze_ball_trajectory(test_positions)
    
    print(f"\n📊 Synthetic Test Results:")
    print(f"Detection Rate: {analysis['detection_rate']*100:.1f}%")
    print(f"Flight Time: {analysis['flight_time']:.2f}s")
    
    if 'physics_analysis' in analysis:
        physics = analysis['physics_analysis']
        print(f"Launch Angle: {physics['launch_angle_degrees']:.1f}°")
        print(f"Launch Speed: {physics['launch_speed_ms']:.1f} m/s")
        print(f"Trajectory: {physics['trajectory_type']}")
    
    # Create visualization
    tracker.create_trajectory_visualization(
        test_positions, analysis, 'test_trajectory.png'
    )

if __name__ == "__main__":
    main()