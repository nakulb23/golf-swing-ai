"""
Golf Swing AI - FastAPI Web Service
Physics-based golf swing plane classification
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import tempfile
import os
import sys
from pathlib import Path

# Add current directory to path for imports
sys.path.append(str(Path(__file__).parent))

from predict_multi_angle import predict_with_multi_angle_model
from predict_physics_based import predict_with_physics_model  # Keep for fallback
from golf_chatbot import CaddieChat
from ball_tracking import GolfBallTracker

# Initialize components
chatbot = CaddieChat()
ball_tracker = GolfBallTracker()

# Pydantic models for request/response
class ChatRequest(BaseModel):
    question: str

class ChatResponse(BaseModel):
    answer: str
    is_golf_related: bool

app = FastAPI(
    title="Golf Swing AI",
    description="Complete golf analysis system with swing classification, ball tracking, and Q&A chatbot",
    version="2.0.0"
)

# Add CORS middleware for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your iOS app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {
        "message": "Golf Swing AI - Complete golf analysis system",
        "version": "2.0.0",
        "features": {
            "swing_analysis": "Physics-based swing plane classification",
            "ball_tracking": "Real-time golf ball trajectory analysis", 
            "chatbot": "CaddieChat - Golf Q&A with PGA tournament data"
        },
        "endpoints": {
            "swing_analysis": "/predict",
            "ball_tracking": "/track-ball",
            "chatbot": "/chat"
        },
        "swing_classes": ["on_plane", "too_steep", "too_flat"]
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": True}

@app.post("/predict")
async def predict_swing(file: UploadFile = File(...)):
    """
    Enhanced multi-angle golf swing plane classification from video file
    
    NEW FEATURES:
    - Automatic camera angle detection (side-on, front-on, behind, angled)
    - View-invariant analysis with coordinate transformation
    - Angle-specific feature weighting for improved accuracy
    - Enhanced insights based on camera perspective
    
    Returns:
    - predicted_label: Classification result (on_plane, too_steep, too_flat)
    - confidence: Prediction confidence (0-1)
    - camera_angle: Detected camera perspective
    - angle_confidence: Camera detection confidence
    - feature_reliability: Reliability scores by feature category
    - physics_insights: Enhanced swing mechanics analysis
    - angle_insights: Camera angle specific analysis
    - recommendations: Personalized improvement suggestions
    """
    
    if not file.content_type.startswith('video/'):
        raise HTTPException(status_code=400, detail="File must be a video")
    
    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as tmp_file:
        content = await file.read()
        tmp_file.write(content)
        tmp_path = tmp_file.name
    
    try:
        # Make prediction with multi-angle model
        result = predict_with_multi_angle_model(tmp_path)
        
        if result is None:
            # Fallback to traditional model if multi-angle fails
            print("⚠️ Multi-angle prediction failed, falling back to traditional model...")
            result = predict_with_physics_model(tmp_path)
            if result is None:
                raise HTTPException(status_code=400, detail="Failed to process video with both models")
        
        # Enhanced response with multi-angle information
        response = {
            "predicted_label": result['predicted_label'],
            "confidence": float(result['confidence']),
            "confidence_gap": float(result.get('confidence_gap', 0)),
            "all_probabilities": {k: float(v) for k, v in result['all_probabilities'].items()},
            
            # New multi-angle features
            "camera_angle": result.get('camera_angle', 'unknown'),
            "angle_confidence": float(result.get('angle_confidence', 0)),
            "feature_reliability": result.get('feature_reliability', {}),
            
            # Enhanced insights
            "physics_insights": result.get('physics_insights', "Analysis completed successfully"),
            "angle_insights": result.get('angle_insights', ""),
            "recommendations": result.get('recommendations', []),
            
            # Status and compatibility
            "extraction_status": result.get('extraction_status', 'success'),
            "analysis_type": "multi_angle" if 'camera_angle' in result else "traditional",
            "model_version": "2.0_multi_angle"
        }
        
        return JSONResponse(content=response)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")
    
    finally:
        # Clean up temporary file
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

@app.post("/detect-camera-angle")
async def detect_camera_angle(file: UploadFile = File(...)):
    """
    Detect camera angle from video without full swing analysis (faster)
    
    Useful for:
    - Real-time camera positioning feedback
    - Pre-analysis angle validation
    - Recording setup guidance
    
    Returns:
    - camera_angle: Detected perspective (side_on, front_on, behind, etc.)
    - confidence: Detection confidence (0-1)
    - reliability_score: Overall detection reliability
    - guidance: Recommendations for optimal camera positioning
    """
    
    if not file.content_type.startswith('video/'):
        raise HTTPException(status_code=400, detail="File must be a video")
    
    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as tmp_file:
        content = await file.read()
        tmp_file.write(content)
        tmp_path = tmp_file.name
    
    try:
        # Extract keypoints for angle detection only
        from scripts.extract_features_robust import extract_keypoints_from_video_robust
        from camera_angle_detector import CameraAngleDetector
        
        keypoints, status = extract_keypoints_from_video_robust(tmp_path)
        
        if keypoints.size == 0:
            raise HTTPException(status_code=400, detail=f"Failed to extract features: {status}")
        
        # Detect camera angle
        detector = CameraAngleDetector()
        angle_result = detector.detect_camera_angle(keypoints)
        
        # Generate guidance based on detected angle
        guidance = generate_camera_guidance(angle_result)
        
        response = {
            "camera_angle": angle_result['angle_type'].value,
            "confidence": float(angle_result['confidence']),
            "reliability_score": float(angle_result['reliability_score']),
            "guidance": guidance,
            "detection_status": "success",
            "frames_analyzed": len(angle_result['frame_analyses'])
        }
        
        return JSONResponse(content=response)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Camera angle detection failed: {str(e)}")
    
    finally:
        # Clean up temporary file
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

def generate_camera_guidance(angle_result):
    """Generate guidance for optimal camera positioning"""
    
    angle_type = angle_result['angle_type']
    confidence = angle_result['confidence']
    
    if confidence < 0.4:
        return {
            "status": "poor",
            "message": "Camera angle could not be determined reliably. Try recording with better lighting and clearer body visibility.",
            "recommendations": [
                "Ensure your full body is visible in the frame",
                "Use good lighting to make pose detection easier",
                "Keep the camera steady during recording",
                "Make sure you're the only person in the frame"
            ]
        }
    
    if angle_type.value == "side_on":
        return {
            "status": "excellent",
            "message": "Perfect! Side-on view provides the best swing plane analysis.",
            "recommendations": [
                "Maintain this camera position for optimal analysis",
                "Ensure you're positioned sideways to the camera",
                "Keep 6-8 feet distance from the camera"
            ]
        }
    
    elif angle_type.value == "front_on":
        return {
            "status": "good",
            "message": "Front-on view is excellent for balance and alignment analysis.",
            "recommendations": [
                "This angle is great for checking your setup and balance",
                "For swing plane analysis, consider recording from the side",
                "Ensure your full swing is visible in the frame"
            ]
        }
    
    elif angle_type.value == "behind":
        return {
            "status": "good", 
            "message": "Behind view is excellent for club path analysis.",
            "recommendations": [
                "This angle shows club path and target line well",
                "For swing plane analysis, consider recording from the side",
                "Make sure your hands and club are clearly visible"
            ]
        }
    
    elif "angled" in angle_type.value:
        return {
            "status": "fair",
            "message": "Angled view detected. Analysis is adjusted but may be less accurate.",
            "recommendations": [
                "Try moving the camera for a direct side-on view",
                "This angle can still provide useful analysis",
                "For best results, position camera directly to your side"
            ]
        }
    
    else:
        return {
            "status": "unknown",
            "message": "Camera angle unclear. Reposition for better analysis.",
            "recommendations": [
                "Try recording from directly to the side (side-on view)",
                "Ensure good lighting and clear body visibility",
                "Keep camera at waist height for best results"
            ]
        }

def get_plane_analysis(avg_plane_angle):
    """Get human-readable plane analysis"""
    if avg_plane_angle > 55:
        return "Swing plane is TOO STEEP (>55° from vertical)"
    elif avg_plane_angle < 35:
        return "Swing plane is TOO FLAT (<35° from vertical)"
    else:
        return "Swing plane is ON-PLANE (35-55° from vertical)"

@app.post("/chat")
async def chat_with_bot(chat_request: ChatRequest):
    """
    CaddieChat - Golf Q&A Chatbot
    
    Ask questions about:
    - PGA tournament winners (2014-2024)
    - Golf swing techniques
    - Equipment and rules
    - Course strategy
    """
    
    try:
        question = chat_request.question
        is_golf_related = chatbot.is_golf_question(question)
        answer = chatbot.answer_question(question)
        
        return ChatResponse(
            answer=answer,
            is_golf_related=is_golf_related
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Chat failed: {str(e)}")

@app.post("/track-ball")
async def track_ball_trajectory(file: UploadFile = File(...)):
    """
    Golf Ball Tracking and Trajectory Analysis
    
    Upload a golf swing video to:
    - Track ball position throughout flight
    - Analyze trajectory physics
    - Predict landing spot
    - Generate trajectory visualization
    
    Returns:
    - Ball detection rate
    - Flight physics analysis
    - Trajectory classification
    - Landing prediction
    """
    
    if not file.content_type.startswith('video/'):
        raise HTTPException(status_code=400, detail="File must be a video")
    
    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as tmp_file:
        content = await file.read()
        tmp_file.write(content)
        tmp_path = tmp_file.name
    
    try:
        # Track ball in video
        ball_positions = ball_tracker.track_ball_in_video(tmp_path)
        
        if not ball_positions:
            raise HTTPException(status_code=400, detail="Failed to process video for ball tracking")
        
        # Analyze trajectory
        trajectory_analysis = ball_tracker.analyze_ball_trajectory(ball_positions)
        
        # Create visualization
        viz_path = tmp_path.replace('.mp4', '_trajectory.png')
        ball_tracker.create_trajectory_visualization(ball_positions, trajectory_analysis, viz_path)
        
        # Format response
        response = {
            "detection_summary": {
                "total_frames": len(ball_positions),
                "ball_detected_frames": len([p for p in ball_positions if p['detected']]),
                "detection_rate": trajectory_analysis.get('detection_rate', 0),
                "trajectory_points": trajectory_analysis.get('trajectory_points', 0)
            },
            "flight_analysis": trajectory_analysis.get('physics_analysis', {}),
            "trajectory_data": {
                "flight_time": trajectory_analysis.get('flight_time', 0),
                "has_valid_trajectory": 'physics_analysis' in trajectory_analysis and 'error' not in trajectory_analysis['physics_analysis']
            },
            "visualization_created": os.path.exists(viz_path)
        }
        
        return JSONResponse(content=response)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ball tracking failed: {str(e)}")
    
    finally:
        # Clean up temporary files
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        viz_path = tmp_path.replace('.mp4', '_trajectory.png')
        if os.path.exists(viz_path):
            # Keep visualization file for now - in production you might upload to cloud storage
            pass

if __name__ == "__main__":
    import uvicorn
    import os
    
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
