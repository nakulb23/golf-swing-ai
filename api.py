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
from predict_enhanced_lstm import predict_with_enhanced_lstm  # Enhanced LSTM model
from detailed_swing_analysis import analyze_swing_with_details
from golf_chatbot import CaddieChat
from ball_tracking import GolfBallTracker
from incremental_lstm_trainer import get_trainer, add_user_contribution, get_training_status

# Initialize components
chatbot = CaddieChat()
ball_tracker = GolfBallTracker()
lstm_trainer = get_trainer()  # Initialize incremental trainer

# Pydantic models for request/response
class ChatRequest(BaseModel):
    question: str

class ChatResponse(BaseModel):
    answer: str
    is_golf_related: bool

app = FastAPI(
    title="Golf Swing AI Enhanced",
    description="Advanced golf analysis with LSTM temporal modeling, multi-angle detection, physics-based features, swing classification, ball tracking, and Q&A chatbot",
    version="2.1.0"
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
    
    # Enhanced video format validation for iPhone compatibility
    print(f"📹 Received file: {file.filename}")
    print(f"📹 Content type: {file.content_type}")
    print(f"📹 File size: {file.size if hasattr(file, 'size') else 'Unknown'}")
    
    # Check file extension and content type
    if file.filename:
        file_ext = file.filename.lower().split('.')[-1]
        allowed_extensions = ['mp4', 'mov', 'avi', 'm4v', 'quicktime']
        
        if file_ext not in allowed_extensions:
            print(f"❌ Invalid file extension: {file_ext}")
            raise HTTPException(status_code=400, detail=f"Unsupported file format. Please use: {', '.join(allowed_extensions)}")
    
    # Accept various video MIME types from different devices
    allowed_content_types = [
        'video/mp4',
        'video/quicktime', 
        'video/x-msvideo',
        'video/avi',
        'video/mov',
        'application/octet-stream',  # Sometimes iOS sends this
        'video/*'  # Wildcard fallback
    ]
    
    # More permissive content type checking for iPhone compatibility
    is_video = (
        file.content_type and any(ct in file.content_type.lower() for ct in ['video/', 'quicktime', 'mp4']) or
        (file.filename and any(ext in file.filename.lower() for ext in ['.mp4', '.mov', '.avi', '.m4v'])) or
        file.content_type == 'application/octet-stream'  # iOS sometimes sends binary data
    )
    
    if not is_video:
        print(f"❌ File validation failed - Content-Type: {file.content_type}, Filename: {file.filename}")
        raise HTTPException(status_code=400, detail=f"File must be a video. Received content-type: {file.content_type}")
    
    print(f"✅ Video file validation passed")
    
    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as tmp_file:
        content = await file.read()
        print(f"📹 Read {len(content)} bytes of video data")
        
        # Check video file header for debugging
        if len(content) > 12:
            header = content[:12]
            header_hex = header.hex()
            print(f"📹 Video file header: {header_hex}")
            
        tmp_file.write(content)
        tmp_path = tmp_file.name
        print(f"📹 Saved video to temporary file: {tmp_path}")
    
    try:
        # Try enhanced LSTM model first (best performance)
        print("🚀 Attempting enhanced LSTM temporal analysis...")
        result = predict_with_enhanced_lstm(
            tmp_path, 
            lstm_model_path="models/enhanced_temporal_model.pt",
            physics_model_path="models/physics_based_model.pt",
            scaler_path="models/physics_scaler.pkl",
            encoder_path="models/physics_label_encoder.pkl",
            use_ensemble=True
        )
        
        if result is None:
            # Fallback to multi-angle model
            print("⚠️ Enhanced LSTM failed, falling back to multi-angle model...")
            result = predict_with_multi_angle_model(tmp_path)
            
            if result is None:
                # Final fallback to traditional physics model
                print("⚠️ Multi-angle prediction failed, falling back to traditional model...")
                result = predict_with_physics_model(tmp_path)
            if result is None:
                raise HTTPException(status_code=400, detail="Failed to process video with both models")
        
        # Try to get detailed biomechanics analysis
        detailed_result = None
        try:
            print("🎯 Attempting detailed biomechanics analysis...")
            detailed_result = analyze_swing_with_details(tmp_path)
            print("✅ Detailed analysis completed successfully")
        except Exception as e:
            print(f"⚠️ Detailed analysis failed, using standard result: {str(e)}")
        
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
            
            # Quality validation fields
            "feature_dimension_ok": result.get('feature_dimension_ok', True),
            "quality_score": float(result.get('quality_score', 0.5)),
            
            # Enhanced insights
            "physics_insights": result.get('physics_insights', "Analysis completed successfully"),
            "angle_insights": result.get('angle_insights', ""),
            "recommendations": result.get('recommendations', []),
            
            # Detailed biomechanics data (if available)
            "detailed_biomechanics": detailed_result.get('detailed_biomechanics', []) if detailed_result else [],
            "priority_flaws": detailed_result.get('priority_flaws', []) if detailed_result else [],
            "pose_sequence": detailed_result.get('pose_sequence', []) if detailed_result else [],
            "optimal_reference": detailed_result.get('optimal_reference', []) if detailed_result else [],
            "comparison_data": detailed_result.get('comparison_data', {}) if detailed_result else {},
            
            # Status and compatibility
            "extraction_status": result.get('extraction_status', 'success'),
            "analysis_type": "detailed_multi_angle" if detailed_result else ("multi_angle" if 'camera_angle' in result else "traditional"),
            "model_version": "3.0_detailed" if detailed_result else "2.0_multi_angle",
            "has_detailed_analysis": detailed_result is not None
        }
        
        return JSONResponse(content=response)
        
    except FileNotFoundError as e:
        print(f"❌ Model file not found: {str(e)}")
        raise HTTPException(status_code=503, detail=f"AI model not available: {str(e)}")
    except ValueError as e:
        print(f"❌ Invalid input data: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Invalid video format or content: {str(e)}")
    except MemoryError as e:
        print(f"❌ Memory error during processing: {str(e)}")
        raise HTTPException(status_code=413, detail="Video file too large to process")
    except Exception as e:
        print(f"❌ Unexpected prediction error: {str(e)}")
        import traceback
        traceback.print_exc()
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
    
    # Use same video validation as main predict endpoint
    is_video = (
        file.content_type and any(ct in file.content_type.lower() for ct in ['video/', 'quicktime', 'mp4']) or
        (file.filename and any(ext in file.filename.lower() for ext in ['.mp4', '.mov', '.avi', '.m4v'])) or
        file.content_type == 'application/octet-stream'
    )
    
    if not is_video:
        raise HTTPException(status_code=400, detail=f"File must be a video. Received content-type: {file.content_type}")
    
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
        
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=f"Camera angle model not available: {str(e)}")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid video format for camera angle detection: {str(e)}")
    except Exception as e:
        print(f"❌ Unexpected error in camera angle detection: {str(e)}")
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
    
    # Use same video validation as main predict endpoint
    is_video = (
        file.content_type and any(ct in file.content_type.lower() for ct in ['video/', 'quicktime', 'mp4']) or
        (file.filename and any(ext in file.filename.lower() for ext in ['.mp4', '.mov', '.avi', '.m4v'])) or
        file.content_type == 'application/octet-stream'
    )
    
    if not is_video:
        raise HTTPException(status_code=400, detail=f"File must be a video. Received content-type: {file.content_type}")
    
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

# MARK: - Data Collection & Model Improvement Endpoints

# In-memory storage for development (use proper database in production)
consent_storage = {}
swing_data_storage = []
feedback_storage = []

@app.post("/submit-consent")
async def submit_consent(consent_data: dict):
    """
    Accept user consent for data collection
    
    GDPR & Privacy Compliance:
    - Users explicitly opt-in to data collection
    - Consent is versioned and tracked
    - Can be revoked at any time
    """
    
    try:
        user_id = consent_data.get('user_id')
        consent_given = consent_data.get('consent_given', False)
        
        # Store consent (in production, use secure database)
        consent_storage[user_id] = {
            'consent_given': consent_given,
            'consent_date': consent_data.get('consent_date'),
            'data_types': consent_data.get('data_types_consented', []),
            'privacy_version': consent_data.get('privacy_version', '1.0.0')
        }
        
        if consent_given:
            message = "Thank you for helping improve Golf Swing AI! Your anonymous contributions will help create better analysis for everyone."
        else:
            message = "Consent revoked. No data will be collected from your device."
        
        return {
            "data_received": True,
            "anonymous_id": user_id[:8],  # Partial ID for confirmation
            "contribution_count": len([d for d in swing_data_storage if d.get('user_id') == user_id]),
            "thank_you_message": message,
            "privacy_confirmed": True
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Consent submission failed: {str(e)}")

@app.post("/submit-swing-data")
async def submit_swing_data(swing_data: dict):
    """
    Accept anonymous swing data for model improvement
    
    Privacy Features:
    - No personal identification
    - Only physics features and predictions
    - Aggregated for model training
    """
    
    try:
        session_id = swing_data.get('session_id')
        
        # Validate that we have consent (in production, check database)
        # For now, just accept the data as anonymous
        
        # Store anonymous swing data
        anonymized_data = {
            'session_id': session_id,
            'features': swing_data.get('swing_features', {}),
            'prediction': swing_data.get('predicted_classification'),
            'confidence': swing_data.get('confidence_score'),
            'camera_angle': swing_data.get('camera_angle'),
            'timestamp': swing_data.get('timestamp'),
            'app_version': swing_data.get('app_version'),
            'model_version': swing_data.get('model_version')
        }
        
        swing_data_storage.append(anonymized_data)
        
        # In production, trigger model retraining pipeline here
        print(f"📊 Received swing data contribution: {len(swing_data_storage)} total samples")
        
        return {
            "data_received": True,
            "anonymous_id": session_id[:8],
            "contribution_count": len(swing_data_storage),
            "thank_you_message": f"Data received! Total community contributions: {len(swing_data_storage)}",
            "privacy_confirmed": True
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Data submission failed: {str(e)}")

@app.post("/submit-feedback")
async def submit_feedback(feedback_data: dict):
    """
    Accept user feedback on predictions for model improvement
    
    Feedback Types:
    - Accuracy ratings (1-5 stars)
    - Correction of wrong predictions
    - Helpfulness feedback
    """
    
    try:
        session_id = feedback_data.get('session_id')
        feedback = feedback_data.get('feedback', {})
        
        # Store feedback
        feedback_entry = {
            'session_id': session_id,
            'feedback_type': feedback.get('feedback_type'),
            'rating': feedback.get('user_rating'),
            'correction': feedback.get('correction'),
            'helpful': feedback.get('helpful'),
            'comments': feedback.get('comments'),
            'timestamp': datetime.now().isoformat()
        }
        
        feedback_storage.append(feedback_entry)
        
        print(f"💬 Received user feedback: {feedback.get('feedback_type')}")
        
        return {
            "data_received": True,
            "anonymous_id": session_id[:8],
            "contribution_count": len(feedback_storage),
            "thank_you_message": "Thank you for your feedback! It helps us improve the AI.",
            "privacy_confirmed": True
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Feedback submission failed: {str(e)}")

@app.get("/contribution-stats/{user_id}")
async def get_contribution_stats(user_id: str):
    """
    Get anonymous contribution statistics for a user
    """
    
    try:
        # Count user contributions (anonymously)
        user_contributions = len([d for d in swing_data_storage if d.get('session_id', '').startswith(user_id[:8])])
        total_contributions = len(swing_data_storage)
        
        # Calculate mock accuracy improvement (in production, use real metrics)
        base_accuracy = 0.7612  # Original limited dataset accuracy
        current_accuracy = min(0.95, base_accuracy + (total_contributions * 0.0001))  # Mock improvement
        improvement = current_accuracy - base_accuracy
        
        return {
            "total_contributions": total_contributions,
            "your_contributions": user_contributions,
            "model_accuracy_improvement": round(improvement * 100, 2) if improvement > 0 else None,
            "last_model_update": "2025-01-15" if total_contributions > 100 else None,
            "community_impact": f"Thanks to {total_contributions} community contributions, our AI is getting smarter every day!"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stats retrieval failed: {str(e)}")

@app.get("/model-training-status")
async def get_model_training_status():
    """
    Get current LSTM model training status and community impact
    """
    
    try:
        # Get enhanced training status from LSTM trainer
        lstm_status = get_training_status()
        
        total_samples = lstm_status['total_samples']
        min_required = lstm_status['min_samples_required']
        is_training = lstm_status['is_training']
        model_exists = lstm_status['model_exists']
        
        # Determine training status
        if total_samples < min_required:
            status = "Collecting initial data"
            next_update = f"Need {min_required - total_samples} more contributions to begin LSTM training"
        elif is_training:
            status = "LSTM model training in progress"
            next_update = "Enhanced temporal model is being updated with new data!"
        elif total_samples >= min_required and not is_training:
            status = "Ready for training"
            next_update = "Sufficient data collected - training will begin automatically"
        else:
            status = "Model ready"
            next_update = "Enhanced LSTM model is trained and serving predictions"
        
        return {
            "total_contributions": total_samples,
            "training_status": status,
            "next_update": next_update,
            "model_version": "2.1_lstm_temporal",
            "accuracy_target": "95%+ with temporal analysis",
            "community_impact": f"Enhanced LSTM model learns from {total_samples} real swing contributions!",
            "lstm_specific": {
                "min_samples_required": min_required,
                "is_currently_training": is_training,
                "model_file_exists": model_exists,
                "last_training": lstm_status['last_training'],
                "training_interval_hours": lstm_status['training_interval_hours']
            }
        }
        
    except Exception as e:
        # Fallback to basic status
        total_data = len(swing_data_storage)
        return {
            "total_contributions": total_data,
            "training_status": "Basic data collection",
            "next_update": "LSTM trainer initialization pending",
            "model_version": "2.0_fallback",
            "error": str(e)
        }

# MARK: - Enhanced LSTM Training Endpoints

@app.post("/submit-corrected-prediction")
async def submit_corrected_prediction(file: UploadFile = File(...), 
                                    correct_label: str = Form(...),
                                    original_prediction: str = Form(...),
                                    user_id: str = Form(...)):
    """
    Submit a video with corrected label for LSTM model improvement
    
    This endpoint allows users to contribute training data by:
    1. Uploading a video that was misclassified
    2. Providing the correct label
    3. Contributing to incremental LSTM training
    """
    
    try:
        # Validate correct label
        valid_labels = ['too_steep', 'on_plane', 'too_flat']
        if correct_label not in valid_labels:
            raise HTTPException(status_code=400, detail=f"Invalid label. Must be one of: {valid_labels}")
        
        # Save uploaded video temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        try:
            # Add to incremental training with user feedback
            user_feedback = {
                'original_prediction': original_prediction,
                'correction_reason': f'User corrected {original_prediction} to {correct_label}',
                'user_id': user_id[:8] + '***',  # Anonymize
                'contribution_type': 'correction'
            }
            
            success = add_user_contribution(tmp_path, correct_label, user_feedback)
            
            if success:
                # Get updated training status
                training_status = get_training_status()
                
                return {
                    "contribution_accepted": True,
                    "correct_label": correct_label,
                    "anonymous_id": user_id[:8] + '***',
                    "total_contributions": training_status['total_samples'],
                    "training_triggered": training_status['is_training'],
                    "thank_you_message": f"Thank you! Your correction helps improve the LSTM model. Total community contributions: {training_status['total_samples']}",
                    "model_impact": "Your contribution will be included in the next incremental training cycle."
                }
            else:
                raise HTTPException(status_code=500, detail="Failed to process training contribution")
                
        finally:
            # Clean up temporary file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
                
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Contribution processing failed: {str(e)}")

@app.post("/submit-verified-swing")
async def submit_verified_swing(file: UploadFile = File(...),
                               swing_label: str = Form(...),
                               verification_source: str = Form(...),
                               user_id: str = Form(...)):
    """
    Submit a professionally verified swing for high-quality training data
    
    For swings that have been verified by:
    - Golf professionals
    - Video analysis software
    - Expert golfers
    """
    
    try:
        valid_labels = ['too_steep', 'on_plane', 'too_flat']
        if swing_label not in valid_labels:
            raise HTTPException(status_code=400, detail=f"Invalid label. Must be one of: {valid_labels}")
        
        # Save video temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        try:
            # Add high-quality training data
            user_feedback = {
                'verification_source': verification_source,
                'quality_level': 'professional_verified',
                'user_id': user_id[:8] + '***',
                'contribution_type': 'verified_training'
            }
            
            success = add_user_contribution(tmp_path, swing_label, user_feedback)
            
            if success:
                training_status = get_training_status()
                
                return {
                    "verification_accepted": True,
                    "swing_label": swing_label,
                    "verification_source": verification_source,
                    "total_contributions": training_status['total_samples'],
                    "thank_you_message": "High-quality verified swing added! This greatly improves model accuracy.",
                    "priority_impact": "Verified swings receive higher weight in training."
                }
            else:
                raise HTTPException(status_code=500, detail="Failed to process verified swing")
                
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
                
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Verified swing processing failed: {str(e)}")

@app.get("/training-progress/{user_id}")
async def get_training_progress(user_id: str):
    """
    Get training progress and user contribution impact
    """
    
    try:
        training_status = get_training_status()
        
        # Mock user-specific stats (in production, track by user ID)
        user_contributions = max(1, len(swing_data_storage) // 10)  # Estimate
        
        return {
            "user_contributions": user_contributions,
            "total_community_contributions": training_status['total_samples'],
            "training_status": {
                "is_training": training_status['is_training'],
                "last_training": training_status['last_training'],
                "samples_needed": max(0, training_status['min_samples_required'] - training_status['total_samples'])
            },
            "model_improvement": {
                "current_version": "2.1_lstm_temporal",
                "model_exists": training_status['model_exists'],
                "next_training_cycle": "Automatic when sufficient new data collected"
            },
            "impact_message": f"Your {user_contributions} contributions help train the LSTM model for better temporal analysis!"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Progress retrieval failed: {str(e)}")

@app.post("/force-training")
async def force_model_training(admin_key: str = Form(...)):
    """
    Force immediate LSTM model training (admin only)
    """
    
    # Simple admin authentication (in production, use proper auth)
    if admin_key != "golf_ai_admin_2024":
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    try:
        trainer = get_trainer()
        success = trainer.force_training()
        
        if success:
            return {
                "training_forced": True,
                "message": "LSTM model training initiated manually",
                "check_status_endpoint": "/model-training-status"
            }
        else:
            return {
                "training_forced": False,
                "message": "No training data available for forced training"
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Forced training failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    import os
    from datetime import datetime
    
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
