"""
GolfSwingAI Authentication API Endpoints
FastAPI router for user authentication and management
"""

from fastapi import APIRouter, HTTPException, Depends, status, File, UploadFile
from fastapi.responses import JSONResponse
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
import secrets
import os
from pathlib import Path

# Import authentication modules
from golfai_auth import (
    GolfAIDatabase, get_db,
    UserRegister, UserLogin, UserProfile, TokenResponse, UserUpdate,
    PasswordChange, PasswordReset, SwingRecord,
    create_access_token, create_refresh_token, decode_token,
    get_current_user, create_user, authenticate_user,
    get_user_by_id, update_user, save_swing_record,
    get_user_swing_history, get_user_progress,
    create_session, invalidate_session, refresh_session,
    hash_password, verify_password
)

# Create router for GolfSwingAI authentication
router = APIRouter(prefix="/auth", tags=["Authentication"])

# File storage for profile photos
PROFILE_PHOTOS_PATH = Path.home() / "Documents" / "GolfSwingAI_Data" / "profile_photos"
PROFILE_PHOTOS_PATH.mkdir(parents=True, exist_ok=True)

@router.post("/register", response_model=TokenResponse)
async def register(user_data: UserRegister):
    """
    Register a new user account
    
    Creates a new user profile and returns JWT tokens for immediate login.
    The app should store these tokens securely for persistent login.
    """
    db = get_db()
    
    try:
        # Create user
        user_info = create_user(db, user_data)
        
        # Generate tokens
        access_token = create_access_token(user_info['id'])
        refresh_token = create_refresh_token(user_info['id'])
        
        # Create session
        create_session(db, user_info['id'], access_token, refresh_token)
        
        # Get full user profile
        user = get_user_by_id(db, user_info['id'])
        
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=24 * 30 * 3600,  # 30 days in seconds
            user=UserProfile(
                id=user['id'],
                email=user['email'],
                username=user['username'],
                full_name=user.get('full_name'),
                handicap=user.get('handicap'),
                skill_level=user.get('skill_level'),
                preferred_hand=user.get('preferred_hand'),
                profile_photo_url=user.get('profile_photo_url'),
                created_at=str(user['created_at']),
                last_login=str(user.get('last_login')) if user.get('last_login') else None,
                is_verified=user['is_verified'],
                preferences=user.get('preferences', {}),
                stats=user.get('stats', {})
            )
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}"
        )

@router.post("/login", response_model=TokenResponse)
async def login(login_data: UserLogin):
    """
    Login with username/email and password
    
    Returns JWT tokens for authenticated access.
    The app should store these tokens securely for persistent login.
    """
    db = get_db()
    
    # Authenticate user
    user = authenticate_user(db, login_data)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username/email or password"
        )
    
    # Generate tokens
    access_token = create_access_token(user['id'])
    refresh_token = create_refresh_token(user['id'])
    
    # Create session
    create_session(db, user['id'], access_token, refresh_token, login_data.device_info)
    
    # Get full user profile
    user_profile = get_user_by_id(db, user['id'])
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=24 * 30 * 3600,  # 30 days in seconds
        user=UserProfile(
            id=user_profile['id'],
            email=user_profile['email'],
            username=user_profile['username'],
            full_name=user_profile.get('full_name'),
            handicap=user_profile.get('handicap'),
            skill_level=user_profile.get('skill_level'),
            preferred_hand=user_profile.get('preferred_hand'),
            profile_photo_url=user_profile.get('profile_photo_url'),
            created_at=str(user_profile['created_at']),
            last_login=str(user_profile.get('last_login')) if user_profile.get('last_login') else None,
            is_verified=user_profile['is_verified'],
            preferences=user_profile.get('preferences', {}),
            stats=user_profile.get('stats', {})
        )
    )

@router.post("/refresh")
async def refresh_token(refresh_token: str):
    """
    Refresh access token using refresh token
    
    When the access token expires, use this endpoint with the refresh token
    to get a new access token without requiring the user to login again.
    """
    db = get_db()
    
    # Decode refresh token
    try:
        payload = decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type"
            )
    except:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    # Refresh session
    result = refresh_session(db, refresh_token)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired or invalid"
        )
    
    return {
        "access_token": result['access_token'],
        "refresh_token": result['refresh_token'],
        "token_type": "Bearer",
        "expires_in": 24 * 30 * 3600  # 30 days
    }

@router.post("/logout")
async def logout(current_user: str = Depends(get_current_user)):
    """
    Logout and invalidate session
    
    Invalidates the current access token. The app should clear stored tokens.
    """
    # In production, you would invalidate the token in the database
    # For now, the client should just discard the token
    
    return {"message": "Successfully logged out"}

@router.get("/profile", response_model=UserProfile)
async def get_profile(current_user: str = Depends(get_current_user)):
    """
    Get current user profile
    
    Returns the authenticated user's profile information.
    """
    db = get_db()
    
    user = get_user_by_id(db, current_user)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return UserProfile(
        id=user['id'],
        email=user['email'],
        username=user['username'],
        full_name=user.get('full_name'),
        handicap=user.get('handicap'),
        skill_level=user.get('skill_level'),
        preferred_hand=user.get('preferred_hand'),
        profile_photo_url=user.get('profile_photo_url'),
        created_at=str(user['created_at']),
        last_login=str(user.get('last_login')) if user.get('last_login') else None,
        is_verified=user['is_verified'],
        preferences=user.get('preferences', {}),
        stats=user.get('stats', {})
    )

@router.put("/profile")
async def update_profile(
    update_data: UserUpdate,
    current_user: str = Depends(get_current_user)
):
    """
    Update user profile
    
    Updates the authenticated user's profile information.
    """
    db = get_db()
    
    success = update_user(db, current_user, update_data)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to update profile"
        )
    
    # Return updated profile
    user = get_user_by_id(db, current_user)
    
    return {
        "message": "Profile updated successfully",
        "user": UserProfile(
            id=user['id'],
            email=user['email'],
            username=user['username'],
            full_name=user.get('full_name'),
            handicap=user.get('handicap'),
            skill_level=user.get('skill_level'),
            preferred_hand=user.get('preferred_hand'),
            profile_photo_url=user.get('profile_photo_url'),
            created_at=str(user['created_at']),
            last_login=str(user.get('last_login')) if user.get('last_login') else None,
            is_verified=user['is_verified'],
            preferences=user.get('preferences', {}),
            stats=user.get('stats', {})
        )
    }

@router.post("/profile/photo")
async def upload_profile_photo(
    file: UploadFile = File(...),
    current_user: str = Depends(get_current_user)
):
    """
    Upload profile photo
    
    Uploads a new profile photo for the authenticated user.
    """
    db = get_db()
    
    # Validate file type
    allowed_types = ['image/jpeg', 'image/png', 'image/jpg']
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid file type. Only JPEG and PNG are allowed."
        )
    
    # Save file
    file_extension = file.filename.split('.')[-1]
    filename = f"{current_user}_{secrets.token_urlsafe(8)}.{file_extension}"
    file_path = PROFILE_PHOTOS_PATH / filename
    
    content = await file.read()
    with open(file_path, 'wb') as f:
        f.write(content)
    
    # Update user profile with photo URL
    photo_url = f"/profile_photos/{filename}"
    
    cursor = db.conn.cursor()
    cursor.execute(
        "UPDATE users SET profile_photo_url = ? WHERE id = ?",
        (photo_url, current_user)
    )
    db.conn.commit()
    
    return {
        "message": "Profile photo uploaded successfully",
        "photo_url": photo_url
    }

@router.post("/password/change")
async def change_password(
    password_data: PasswordChange,
    current_user: str = Depends(get_current_user)
):
    """
    Change user password
    
    Allows authenticated users to change their password.
    """
    db = get_db()
    
    # Verify current password
    cursor = db.conn.cursor()
    cursor.execute(
        "SELECT password_hash FROM users WHERE id = ?",
        (current_user,)
    )
    user = cursor.fetchone()
    
    if not user or not verify_password(password_data.current_password, user['password_hash']):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect"
        )
    
    # Update password
    new_hash = hash_password(password_data.new_password)
    cursor.execute(
        "UPDATE users SET password_hash = ? WHERE id = ?",
        (new_hash, current_user)
    )
    db.conn.commit()
    
    return {"message": "Password changed successfully"}

@router.post("/password/reset")
async def request_password_reset(reset_data: PasswordReset):
    """
    Request password reset
    
    Sends a password reset token to the user's email.
    (Email sending would be implemented in production)
    """
    db = get_db()
    
    cursor = db.conn.cursor()
    cursor.execute(
        "SELECT id FROM users WHERE email = ?",
        (reset_data.email,)
    )
    user = cursor.fetchone()
    
    if user:
        # Generate reset token
        reset_token = secrets.token_urlsafe(32)
        expires_at = datetime.utcnow() + timedelta(hours=1)
        
        cursor.execute(
            "UPDATE users SET reset_token = ?, reset_token_expires = ? WHERE id = ?",
            (reset_token, expires_at, user['id'])
        )
        db.conn.commit()
        
        # In production, send email with reset link
        # For now, return token (only for development)
        return {
            "message": "Password reset instructions sent to your email",
            "reset_token": reset_token  # Remove this in production
        }
    
    # Don't reveal if email exists
    return {"message": "If the email exists, password reset instructions have been sent"}

@router.post("/swing/save")
async def save_swing_analysis(
    swing_data: SwingRecord,
    current_user: str = Depends(get_current_user)
):
    """
    Save swing analysis result
    
    Saves the swing analysis result to the user's history for tracking progress.
    """
    db = get_db()
    
    record_id = save_swing_record(db, current_user, swing_data)
    
    return {
        "message": "Swing analysis saved successfully",
        "record_id": record_id
    }

@router.get("/swing/history")
async def get_swing_history(
    limit: int = 50,
    current_user: str = Depends(get_current_user)
):
    """
    Get user's swing history
    
    Returns the user's swing analysis history for tracking improvement.
    """
    db = get_db()
    
    history = get_user_swing_history(db, current_user, limit)
    
    return {
        "total": len(history),
        "history": history
    }

@router.get("/progress")
async def get_progress(
    days: int = 30,
    current_user: str = Depends(get_current_user)
):
    """
    Get user's progress over time
    
    Returns analytics on the user's swing improvement over the specified period.
    """
    db = get_db()
    
    progress = get_user_progress(db, current_user, days)
    
    # Calculate improvement metrics
    if len(progress) >= 2:
        recent = progress[:7]  # Last 7 days
        older = progress[-7:]  # 7 days from the start of the period
        
        recent_on_plane = sum(p['on_plane_count'] for p in recent)
        recent_total = sum(p['swings_analyzed'] for p in recent)
        older_on_plane = sum(p['on_plane_count'] for p in older)
        older_total = sum(p['swings_analyzed'] for p in older)
        
        if recent_total > 0 and older_total > 0:
            recent_percentage = (recent_on_plane / recent_total) * 100
            older_percentage = (older_on_plane / older_total) * 100
            improvement = recent_percentage - older_percentage
        else:
            improvement = 0
    else:
        improvement = 0
    
    return {
        "days": days,
        "improvement_percentage": round(improvement, 2),
        "progress": progress
    }

@router.get("/preferences")
async def get_preferences(current_user: str = Depends(get_current_user)):
    """
    Get user preferences
    
    Returns the user's app preferences and settings.
    """
    db = get_db()
    
    cursor = db.conn.cursor()
    cursor.execute(
        "SELECT * FROM user_preferences WHERE user_id = ?",
        (current_user,)
    )
    preferences = cursor.fetchone()
    
    if preferences:
        return dict(preferences)
    else:
        return {
            "units": "imperial",
            "receive_tips": True,
            "share_data_for_improvement": False,
            "notification_enabled": True
        }

@router.put("/preferences")
async def update_preferences(
    preferences: Dict[str, Any],
    current_user: str = Depends(get_current_user)
):
    """
    Update user preferences
    
    Updates the user's app preferences and settings.
    """
    db = get_db()
    
    cursor = db.conn.cursor()
    
    # Update preferences
    cursor.execute('''
        UPDATE user_preferences 
        SET units = ?, receive_tips = ?, share_data_for_improvement = ?, 
            notification_enabled = ?
        WHERE user_id = ?
    ''', (
        preferences.get('units', 'imperial'),
        preferences.get('receive_tips', True),
        preferences.get('share_data_for_improvement', False),
        preferences.get('notification_enabled', True),
        current_user
    ))
    
    db.conn.commit()
    
    return {
        "message": "Preferences updated successfully",
        "preferences": preferences
    }

@router.delete("/account")
async def delete_account(
    password: str,
    current_user: str = Depends(get_current_user)
):
    """
    Delete user account
    
    Permanently deletes the user's account and all associated data.
    Requires password confirmation.
    """
    db = get_db()
    
    # Verify password
    cursor = db.conn.cursor()
    cursor.execute(
        "SELECT password_hash FROM users WHERE id = ?",
        (current_user,)
    )
    user = cursor.fetchone()
    
    if not user or not verify_password(password, user['password_hash']):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Password is incorrect"
        )
    
    # Soft delete (mark as inactive)
    cursor.execute(
        "UPDATE users SET is_active = 0 WHERE id = ?",
        (current_user,)
    )
    
    # Invalidate all sessions
    cursor.execute(
        "UPDATE sessions SET is_active = 0 WHERE user_id = ?",
        (current_user,)
    )
    
    db.conn.commit()
    
    return {"message": "Account deleted successfully"}