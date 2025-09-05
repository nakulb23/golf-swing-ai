"""
Minimal Golf Swing AI API - Debug Version
"""

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import tempfile
import os
import sys
from pathlib import Path

# Add current directory to path for imports
sys.path.append(str(Path(__file__).parent))

# Import only the essential prediction function
from predict_physics_based import predict_with_physics_model

app = FastAPI(
    title="Golf Swing AI - Minimal",
    description="Minimal golf swing analysis",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
    return {"status": "healthy", "minimal": True}

from pydantic import BaseModel

class ChatRequest(BaseModel):
    question: str

class ChatResponse(BaseModel):
    answer: str
    is_golf_related: bool

@app.post("/chat")
async def chat_endpoint(chat_request: ChatRequest):
    try:
        print(f"=== CHAT ENDPOINT CALLED ===")
        print(f"Question: {chat_request.question}")
        
        # Dynamic response based on question
        question_lower = chat_request.question.lower()
        
        if "handicap" in question_lower:
            answer = "A handicap is a numerical measure of a golfer's playing ability. It allows players of different skill levels to compete fairly by adjusting scores. Lower numbers indicate better players - a 10 handicap player typically shoots around 82 on a par-72 course."
        elif "swing" in question_lower:
            answer = "A good golf swing involves proper setup, takeaway, backswing, downswing, and follow-through. Key fundamentals include maintaining balance, proper grip, and consistent tempo throughout the motion."
        elif "club" in question_lower:
            answer = "Golf clubs are designed for different distances and situations. Drivers for long tee shots, irons for accuracy and distance control, wedges for short shots and bunkers, and putters for the green."
        elif "score" in question_lower or "par" in question_lower:
            answer = "Par represents the standard number of strokes for each hole. Birdie is one under par, eagle is two under, bogey is one over par. Your total score compared to par determines how well you played."
        else:
            answer = f"Thanks for your golf question about '{chat_request.question}'. CaddieChat is working! I can help with golf swing tips, rules, equipment, and general golf knowledge."
        
        response = ChatResponse(
            answer=answer,
            is_golf_related=True
        )
        
        print(f"Chat Response: {response.dict()}")
        print("=== CHAT RESPONSE SENT SUCCESSFULLY ===")
        return response
        
    except Exception as e:
        print(f"=== CHAT ERROR ===")
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Chat error: {str(e)}")

@app.post("/predict")
async def predict_swing(file: UploadFile = File(...)):
    print("=== PREDICT ENDPOINT CALLED ===")
    print(f"File: {file.filename}")
    print(f"Content-Type: {file.content_type}")
    print(f"File size: {file.size if hasattr(file, 'size') else 'unknown'}")
    
    if not file.content_type.startswith('video/'):
        raise HTTPException(status_code=400, detail="File must be a video")
    
    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as tmp_file:
        content = await file.read()
        tmp_file.write(content)
        tmp_path = tmp_file.name
    
    try:
        print(f"Processing: {file.filename}")
        
        # Make prediction
        result = predict_with_physics_model(tmp_path)
        
        if result is None:
            raise HTTPException(status_code=400, detail="Failed to process video")
        
        # Simple response
        response = {
            "predicted_label": result['predicted_label'],
            "confidence": float(result['confidence']),
            "confidence_gap": float(result.get('confidence_gap', 0)),
            "all_probabilities": {str(k): float(v) for k, v in result['all_probabilities'].items()},
            "physics_insights": {
                "avg_plane_angle": float(result['physics_features'][0]),
                "plane_analysis": get_plane_analysis(result['physics_features'][0])
            },
            "extraction_status": result['extraction_status']
        }
        
        print(f"=== RESPONSE SENT ===")
        print(f"Response: {response}")
        
        return JSONResponse(content=response)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
    
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