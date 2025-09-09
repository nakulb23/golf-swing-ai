"""
Simplified Google Authentication
Just receives user info from app after Google Sign-In
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
from typing import Optional
import secrets
from datetime import datetime
from golfai_auth import (
    get_db, create_access_token, create_refresh_token,
    create_session, get_user_by_email, hash_password
)

router = APIRouter()

class GoogleUserInfo(BaseModel):
    """User info from Google Sign-In"""
    google_id: str  # Unique Google user ID
    email: EmailStr
    name: str
    given_name: Optional[str] = None
    family_name: Optional[str] = None
    picture: Optional[str] = None
    verified_email: bool = True

class AuthResponse(BaseModel):
    """Response after successful authentication"""
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int = 2592000  # 30 days
    is_new_user: bool
    user_profile: dict

@router.post("/auth/google", response_model=AuthResponse)
async def google_auth(user_info: GoogleUserInfo):
    """
    Authenticate user with Google info
    
    The app handles Google Sign-In directly and sends us the user info.
    We create/update the user profile and return JWT tokens.
    """
    db = get_db()
    
    try:
        # Check if user exists
        existing_user = get_user_by_email(db, user_info.email)
        
        if existing_user:
            # Update existing user
            is_new_user = False
            user_id = existing_user['id']
            
            # Update profile info from Google
            cursor = db.cursor()
            cursor.execute("""
                UPDATE users 
                SET full_name = ?, 
                    profile_photo_url = ?,
                    last_login = CURRENT_TIMESTAMP,
                    is_verified = 1
                WHERE id = ?
            """, (user_info.name, user_info.picture, user_id))
            
            # Update or create OAuth link
            cursor.execute("""
                INSERT OR REPLACE INTO oauth_accounts 
                (user_id, provider, provider_id, email, profile_data)
                VALUES (?, 'google', ?, ?, ?)
            """, (user_id, user_info.google_id, user_info.email, 
                  user_info.dict()))
            
            db.commit()
            
        else:
            # Create new user
            is_new_user = True
            user_id = str(secrets.token_urlsafe(16))
            
            # Generate username from email
            username = user_info.email.split('@')[0] + '_' + secrets.token_hex(4)
            
            cursor = db.cursor()
            
            # Create user account
            cursor.execute("""
                INSERT INTO users (
                    id, email, username, password_hash, 
                    full_name, profile_photo_url, 
                    is_verified, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP)
            """, (user_id, user_info.email, username, 
                  'GOOGLE_AUTH_NO_PASSWORD',  # No password for OAuth users
                  user_info.name, user_info.picture))
            
            # Link OAuth account
            cursor.execute("""
                INSERT INTO oauth_accounts 
                (user_id, provider, provider_id, email, profile_data)
                VALUES (?, 'google', ?, ?, ?)
            """, (user_id, user_info.google_id, user_info.email,
                  user_info.dict()))
            
            db.commit()
        
        # Generate tokens
        access_token = create_access_token(user_id)
        refresh_token = create_refresh_token(user_id)
        
        # Create session
        create_session(db, user_id, access_token, refresh_token)
        
        # Get updated user profile
        cursor = db.cursor()
        cursor.execute("""
            SELECT id, email, username, full_name, 
                   handicap, skill_level, preferred_hand,
                   profile_photo_url, created_at, 
                   last_login, is_verified
            FROM users WHERE id = ?
        """, (user_id,))
        
        user = cursor.fetchone()
        
        user_profile = {
            "id": user['id'],
            "email": user['email'],
            "username": user['username'],
            "full_name": user['full_name'],
            "handicap": user['handicap'],
            "skill_level": user['skill_level'],
            "preferred_hand": user['preferred_hand'],
            "profile_photo_url": user['profile_photo_url'],
            "created_at": str(user['created_at']),
            "is_verified": bool(user['is_verified'])
        }
        
        return AuthResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            is_new_user=is_new_user,
            user_profile=user_profile
        )
        
    except Exception as e:
        print(f"Error in Google auth: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Authentication failed: {str(e)}"
        )

# Add Apple Sign-In endpoint (similar pattern)
@router.post("/auth/apple", response_model=AuthResponse)
async def apple_auth(user_info: dict):
    """
    Authenticate user with Apple info
    
    Similar to Google - app handles Apple Sign-In and sends user info
    """
    # Similar implementation to google_auth
    # Just with Apple-specific fields
    pass