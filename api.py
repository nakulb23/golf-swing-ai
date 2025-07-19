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

from predict_physics_based import predict_with_physics_model
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
    Predict golf swing plane classification from video file
    
    Returns:
    - predicted_label: Classification result (on_plane, too_steep, too_flat)
    - confidence: Prediction confidence (0-1)
    - physics_insights: Key swing mechanics analysis
    """
    
    if not file.content_type.startswith('video/'):
        raise HTTPException(status_code=400, detail="File must be a video")
    
    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as tmp_file:
        content = await file.read()
        tmp_file.write(content)
        tmp_path = tmp_file.name
    
    try:
        # Make prediction
        result = predict_with_physics_model(tmp_path)
        
        if result is None:
            raise HTTPException(status_code=400, detail="Failed to process video")
        
        # Format response
        response = {
            "predicted_label": result['predicted_label'],
            "confidence": float(result['confidence']),
            "confidence_gap": float(result['confidence_gap']),
            "all_probabilities": {k: float(v) for k, v in result['all_probabilities'].items()},
            "physics_insights": {
                "avg_plane_angle": float(result['physics_features'][0]),
                "plane_analysis": get_plane_analysis(result['physics_features'][0])
            },
            "extraction_status": result['extraction_status']
        }
        
        return JSONResponse(content=response)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")
    
    finally:
        # Clean up temporary file
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

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
