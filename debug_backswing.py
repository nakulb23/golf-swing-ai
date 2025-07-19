#!/usr/bin/env python3
"""
Debug script to analyze backswing detection and angles
"""

import numpy as np
import matplotlib.pyplot as plt
from physics_based_features import GolfSwingPhysicsExtractor
from scripts.extract_features_robust import extract_keypoints_from_video_robust

def debug_backswing_analysis(video_path):
    """Debug the backswing detection and angle calculation"""
    
    print(f"🔍 DEBUGGING BACKSWING ANALYSIS: {video_path}")
    print("=" * 60)
    
    # Extract keypoints
    keypoints, status = extract_keypoints_from_video_robust(video_path)
    print(f"📊 Extracted keypoints shape: {keypoints.shape}")
    
    # Create extractor and analyze
    extractor = GolfSwingPhysicsExtractor()
    
    # Manual analysis to debug
    plane_angles = []
    hand_velocities = []
    
    for i, frame in enumerate(keypoints):
        # Extract positions
        left_shoulder = extractor._get_landmark_3d(frame, 'left_shoulder')
        right_shoulder = extractor._get_landmark_3d(frame, 'right_shoulder')
        left_wrist = extractor._get_landmark_3d(frame, 'left_wrist')
        right_wrist = extractor._get_landmark_3d(frame, 'right_wrist')
        
        # Calculate positions
        shoulder_center = (left_shoulder + right_shoulder) / 2
        hand_center = (left_wrist + right_wrist) / 2
        
        # Calculate plane angle
        plane_angle = extractor._calculate_plane_angle(shoulder_center, hand_center)
        plane_angles.append(plane_angle)
        
        # Calculate velocity
        if i > 0:
            prev_frame = keypoints[i-1]
            prev_hand = (extractor._get_landmark_3d(prev_frame, 'left_wrist') + 
                        extractor._get_landmark_3d(prev_frame, 'right_wrist')) / 2
            velocity = np.linalg.norm(hand_center - prev_hand)
            hand_velocities.append(velocity)
        else:
            hand_velocities.append(0.0)
    
    plane_angles = np.array(plane_angles)
    hand_velocities = np.array(hand_velocities)
    
    # Identify swing phases
    swing_phases = extractor._identify_swing_phases(hand_velocities)
    
    print(f"\n📈 SWING PHASE ANALYSIS:")
    for phase_name, (start, end) in swing_phases.items():
        print(f"  {phase_name.upper()}: frames {start}-{end} ({end-start} frames)")
    
    # Analyze backswing specifically
    backswing_start, backswing_end = swing_phases['backswing']
    backswing_angles = plane_angles[backswing_start:backswing_end]
    
    print(f"\n🏌️ BACKSWING DETAILED ANALYSIS:")
    print(f"  Backswing frames: {backswing_start} to {backswing_end}")
    print(f"  Backswing angles: {backswing_angles}")
    print(f"  Average backswing angle: {np.mean(backswing_angles):.1f}°")
    print(f"  Min backswing angle: {np.min(backswing_angles):.1f}°")
    print(f"  Max backswing angle: {np.max(backswing_angles):.1f}°")
    
    print(f"\n📊 OVERALL SWING ANALYSIS:")
    print(f"  All plane angles range: {np.min(plane_angles):.1f}° to {np.max(plane_angles):.1f}°")
    print(f"  Average overall angle: {np.mean(plane_angles):.1f}°")
    
    # Create visualization
    plt.figure(figsize=(12, 8))
    
    # Plot 1: Plane angles over time
    plt.subplot(2, 1, 1)
    frame_numbers = range(len(plane_angles))
    plt.plot(frame_numbers, plane_angles, 'b-', alpha=0.7, label='Plane Angle')
    
    # Highlight swing phases
    colors = {'setup': 'green', 'backswing': 'red', 'transition': 'orange', 
              'downswing': 'purple', 'impact': 'black', 'follow_through': 'blue'}
    
    for phase_name, (start, end) in swing_phases.items():
        if phase_name in colors:
            plt.axvspan(start, end, alpha=0.3, color=colors[phase_name], label=phase_name)
    
    plt.axhline(y=35, color='g', linestyle='--', alpha=0.5, label='Too Flat Threshold')
    plt.axhline(y=55, color='r', linestyle='--', alpha=0.5, label='Too Steep Threshold')
    plt.ylabel('Plane Angle (degrees)')
    plt.title('Golf Swing Plane Angles Over Time')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # Plot 2: Hand velocity over time
    plt.subplot(2, 1, 2)
    plt.plot(range(len(hand_velocities)), hand_velocities, 'g-', alpha=0.7)
    plt.ylabel('Hand Velocity')
    plt.xlabel('Frame Number')
    plt.title('Hand Velocity Over Time (for phase detection)')
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('debug_backswing_analysis.png', dpi=300, bbox_inches='tight')
    print(f"\n📊 Visualization saved to: debug_backswing_analysis.png")
    
    return {
        'plane_angles': plane_angles,
        'hand_velocities': hand_velocities,
        'swing_phases': swing_phases,
        'backswing_angles': backswing_angles
    }

if __name__ == "__main__":
    debug_backswing_analysis("../test_swing4.MP4")