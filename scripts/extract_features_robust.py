import os
import cv2
import json
import numpy as np
from tqdm import tqdm
import mediapipe as mp
import logging
from pathlib import Path

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

mp_pose = mp.solutions.pose
mp_hands = mp.solutions.hands

INPUT_SIZE = 258
SEQ_LEN = 300

def validate_video(video_path):
    """Validate video file before processing"""
    try:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return False, "Cannot open video file"
        
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS)
        duration = frame_count / fps if fps > 0 else 0
        
        cap.release()
        
        if frame_count == 0:
            return False, "No frames found"
        if duration < 1:
            return False, f"Video too short: {duration:.2f}s"
        if duration > 60:
            return False, f"Video too long: {duration:.2f}s (may cause memory issues)"
            
        return True, f"Valid: {frame_count} frames, {duration:.2f}s, {fps:.1f} fps"
    except Exception as e:
        return False, f"Validation error: {str(e)}"

def extract_keypoints_from_video_robust(video_path):
    """Robust keypoint extraction with detailed error handling"""
    logger.info(f"Processing: {video_path}")
    
    # Validate video first
    is_valid, msg = validate_video(video_path)
    if not is_valid:
        logger.error(f"❌ {video_path}: {msg}")
        return np.array([]), msg
    
    logger.info(f"✅ {video_path}: {msg}")
    
    cap = cv2.VideoCapture(video_path)
    
    # Enhanced pose detection settings
    pose = mp_pose.Pose(
        static_image_mode=False,
        min_detection_confidence=0.3,
        min_tracking_confidence=0.3,
        model_complexity=2
    )
    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=2,
        min_detection_confidence=0.3,
        min_tracking_confidence=0.3
    )

    keypoints_array = []
    frame_count = 0
    pose_detection_count = 0
    hand_detection_count = 0
    
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    try:
        while cap.isOpened():
            success, frame = cap.read()
            if not success:
                break
                
            frame_count += 1
            
            # Progress logging for long videos
            if frame_count % 100 == 0:
                logger.info(f"  Processing frame {frame_count}/{total_frames}")
            
            # Resize for consistent processing
            if frame.shape[0] > 720 or frame.shape[1] > 1280:
                height, width = frame.shape[:2]
                scale = min(720/height, 1280/width)
                new_height, new_width = int(height*scale), int(width*scale)
                frame = cv2.resize(frame, (new_width, new_height))
            
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Enhance image quality
            frame_rgb = cv2.convertScaleAbs(frame_rgb, alpha=1.1, beta=10)
            
            # Process pose and hands
            pose_results = pose.process(frame_rgb)
            hands_results = hands.process(frame_rgb)

            keypoints = []

            # Pose landmarks with better error handling
            if pose_results.pose_landmarks:
                pose_detection_count += 1
                for lm in pose_results.pose_landmarks.landmark:
                    keypoints.extend([lm.x, lm.y, lm.z, lm.visibility])
            else:
                # Use previous frame's data if available, otherwise zeros
                if len(keypoints_array) > 0:
                    keypoints.extend(keypoints_array[-1][:132])  # 33 * 4
                else:
                    keypoints.extend([0] * (33 * 4))

            # Hand landmarks
            for handedness in ['Left', 'Right']:
                hand_found = False
                if hands_results.multi_hand_landmarks:
                    for hand, hand_label in zip(hands_results.multi_hand_landmarks, hands_results.multi_handedness):
                        if hand_label.classification[0].label == handedness:
                            hand_detection_count += 1
                            for lm in hand.landmark:
                                keypoints.extend([lm.x, lm.y, lm.z])
                            hand_found = True
                            break
                
                if not hand_found:
                    # Use previous frame's hand data if available
                    if len(keypoints_array) > 0:
                        start_idx = 132 + (0 if handedness == 'Left' else 63)
                        keypoints.extend(keypoints_array[-1][start_idx:start_idx+63])
                    else:
                        keypoints.extend([0] * (21 * 3))

            if len(keypoints) != INPUT_SIZE:
                logger.warning(f"Frame {frame_count}: Expected {INPUT_SIZE} features, got {len(keypoints)}")
                continue
                
            keypoints_array.append(keypoints)

    except Exception as e:
        logger.error(f"❌ Error processing {video_path}: {str(e)}")
        return np.array([]), f"Processing error: {str(e)}"
    finally:
        cap.release()
        pose.close()
        hands.close()

    if len(keypoints_array) == 0:
        return np.array([]), "No valid frames extracted"

    # Log detection statistics
    pose_detection_rate = pose_detection_count / frame_count * 100
    hand_detection_rate = hand_detection_count / (frame_count * 2) * 100  # 2 hands
    
    logger.info(f"  📊 Processed {frame_count} frames")
    logger.info(f"  🏃 Pose detection: {pose_detection_rate:.1f}%")
    logger.info(f"  👋 Hand detection: {hand_detection_rate:.1f}%")

    keypoints_array = np.array(keypoints_array)
    
    # Quality checks
    if pose_detection_rate < 30:
        logger.warning(f"⚠️  Low pose detection rate: {pose_detection_rate:.1f}%")
    
    # Smooth keypoints using moving average
    if keypoints_array.shape[0] > 3:
        smoothed = np.zeros_like(keypoints_array)
        for i in range(keypoints_array.shape[0]):
            start = max(0, i - 1)
            end = min(keypoints_array.shape[0], i + 2)
            smoothed[i] = np.mean(keypoints_array[start:end], axis=0)
        keypoints_array = smoothed

    # Normalize keypoints relative to center of body
    if keypoints_array.shape[0] > 0:
        # Use nose (landmark 0) as reference point
        nose_x = keypoints_array[:, 0]
        nose_y = keypoints_array[:, 1]
        
        # Normalize all x and y coordinates
        for i in range(0, keypoints_array.shape[1], 4):  # Pose landmarks
            if i + 1 < keypoints_array.shape[1]:
                keypoints_array[:, i] -= nose_x
                keypoints_array[:, i + 1] -= nose_y
        
        for i in range(132, keypoints_array.shape[1], 3):  # Hand landmarks
            if i + 1 < keypoints_array.shape[1]:
                keypoints_array[:, i] -= nose_x
                keypoints_array[:, i + 1] -= nose_y

    # Pad or trim to SEQ_LEN
    original_length = keypoints_array.shape[0]
    if keypoints_array.shape[0] < SEQ_LEN:
        pad = np.zeros((SEQ_LEN - keypoints_array.shape[0], keypoints_array.shape[1]))
        keypoints_array = np.vstack((keypoints_array, pad))
    else:
        keypoints_array = keypoints_array[:SEQ_LEN, :]

    logger.info(f"  ✅ Final shape: {keypoints_array.shape} (padded from {original_length} frames)")
    
    return keypoints_array, "Success"

def process_dataset_robust(video_dir, label_file, output_dir):
    """Robust dataset processing with comprehensive error handling"""
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Load labels
    try:
        with open(label_file, 'r') as f:
            labels = json.load(f)
    except Exception as e:
        logger.error(f"❌ Cannot load labels from {label_file}: {str(e)}")
        return
    
    logger.info(f"📁 Processing videos from: {video_dir}")
    logger.info(f"🏷️  Loaded {len(labels)} labels")
    logger.info(f"💾 Output directory: {output_dir}")
    
    # Get all video files (both .mp4 and .MP4)
    video_files = []
    for ext in ['*.mp4', '*.MP4', '*.mov', '*.MOV', '*.avi', '*.AVI']:
        video_files.extend(Path(video_dir).glob(ext))
    
    video_files = [f.name for f in video_files]
    video_files.sort()
    
    logger.info(f"🎬 Found {len(video_files)} video files")
    
    success_count = 0
    failure_count = 0
    error_summary = {}
    
    for file in tqdm(video_files, desc="Processing videos"):
        video_path = os.path.join(video_dir, file)
        
        # Check if file has a label
        if file not in labels:
            logger.warning(f"⚠️  Label missing for {file}, skipping.")
            continue
        
        # Check if already processed
        out_path = os.path.join(output_dir, file.replace('.mp4', '.npz').replace('.MP4', '.npz'))
        if os.path.exists(out_path):
            logger.info(f"⏭️  {file} already processed, skipping.")
            success_count += 1
            continue
        
        # Extract keypoints
        keypoints, status = extract_keypoints_from_video_robust(video_path)
        
        if keypoints.size == 0:
            logger.error(f"❌ Failed to process {file}: {status}")
            failure_count += 1
            error_type = status.split(':')[0] if ':' in status else status
            error_summary[error_type] = error_summary.get(error_type, 0) + 1
            continue
        
        if keypoints.shape != (SEQ_LEN, INPUT_SIZE):
            logger.error(f"❌ Invalid shape for {file}: expected {(SEQ_LEN, INPUT_SIZE)}, got {keypoints.shape}")
            failure_count += 1
            error_summary['Invalid shape'] = error_summary.get('Invalid shape', 0) + 1
            continue
        
        # Save processed data
        try:
            np.savez_compressed(out_path, keypoints=keypoints, label=labels[file])
            logger.info(f"✅ Saved: {out_path}")
            success_count += 1
        except Exception as e:
            logger.error(f"❌ Failed to save {file}: {str(e)}")
            failure_count += 1
            error_summary['Save error'] = error_summary.get('Save error', 0) + 1
    
    # Summary
    logger.info("="*60)
    logger.info("📊 PROCESSING SUMMARY")
    logger.info("="*60)
    logger.info(f"✅ Successful: {success_count}")
    logger.info(f"❌ Failed: {failure_count}")
    logger.info(f"📈 Success rate: {success_count/(success_count+failure_count)*100:.1f}%")
    
    if error_summary:
        logger.info("\n🔍 ERROR BREAKDOWN:")
        for error_type, count in error_summary.items():
            logger.info(f"  {error_type}: {count}")
    
    logger.info("="*60)

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) == 4:
        video_dir, label_file, output_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    else:
        video_dir, label_file, output_dir = "videos", "labels_fixed.json", "training_data"
    
    process_dataset_robust(video_dir, label_file, output_dir)