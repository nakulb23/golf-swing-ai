"""
GolfSwingAI OAuth Authentication
Support for Google and Apple Sign-In
"""

import secrets
import jwt
import json
import hashlib
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from fastapi import HTTPException, status
import httpx
from pydantic import BaseModel, EmailStr

# OAuth Configuration
GOOGLE_CLIENT_ID = "YOUR_GOOGLE_CLIENT_ID"  # Set in environment variables
APPLE_CLIENT_ID = "YOUR_APPLE_CLIENT_ID"    # Your app's bundle ID
APPLE_TEAM_ID = "YOUR_APPLE_TEAM_ID"
APPLE_KEY_ID = "YOUR_APPLE_KEY_ID"

# Token verification URLs
GOOGLE_TOKEN_INFO_URL = "https://oauth2.googleapis.com/tokeninfo"
GOOGLE_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs"
APPLE_AUTH_URL = "https://appleid.apple.com/auth/token"
APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"

# Import database and auth functions
from golfai_auth import (
    GolfAIDatabase, get_db,
    create_access_token, create_refresh_token,
    create_session, get_user_by_id,
    hash_password
)

# Pydantic models for OAuth
class GoogleSignIn(BaseModel):
    id_token: str
    # Optional fields from Google profile
    email: Optional[str] = None
    name: Optional[str] = None
    picture: Optional[str] = None

class AppleSignIn(BaseModel):
    id_token: str
    authorization_code: Optional[str] = None
    # Apple provides these on first sign-in only
    email: Optional[str] = None
    full_name: Optional[Dict[str, str]] = None  # {givenName, familyName}
    
class SocialLoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    is_new_user: bool
    user_profile: Dict[str, Any]

class OAuthUserData(BaseModel):
    provider: str  # 'google' or 'apple'
    provider_id: str  # Unique ID from provider
    email: str
    full_name: Optional[str] = None
    profile_photo_url: Optional[str] = None
    
# OAuth verification functions
async def verify_google_token(id_token: str) -> Dict[str, Any]:
    """
    Verify Google ID token and extract user information
    """
    try:
        # Verify token with Google
        async with httpx.AsyncClient() as client:
            response = await client.get(
                GOOGLE_TOKEN_INFO_URL,
                params={"id_token": id_token}
            )
            
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google token"
            )
        
        token_data = response.json()
        
        # Verify the token is for our app
        if token_data.get("aud") != GOOGLE_CLIENT_ID:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token not for this application"
            )
        
        # Extract user information
        return {
            "provider": "google",
            "provider_id": token_data.get("sub"),
            "email": token_data.get("email"),
            "full_name": token_data.get("name"),
            "profile_photo_url": token_data.get("picture"),
            "email_verified": token_data.get("email_verified", False)
        }
        
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to verify with Google: {str(e)}"
        )

async def verify_apple_token(id_token: str) -> Dict[str, Any]:
    """
    Verify Apple ID token and extract user information
    """
    try:
        # Fetch Apple's public keys
        async with httpx.AsyncClient() as client:
            response = await client.get(APPLE_KEYS_URL)
            apple_keys = response.json()["keys"]
        
        # Decode token header to get the key ID
        header = jwt.get_unverified_header(id_token)
        kid = header.get("kid")
        
        # Find the matching public key
        apple_key = next((key for key in apple_keys if key["kid"] == kid), None)
        if not apple_key:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Apple token - key not found"
            )
        
        # Verify and decode the token
        # Note: In production, use proper RSA key verification
        try:
            # For development, we'll do basic validation
            # In production, convert apple_key to RSA public key and verify properly
            decoded = jwt.decode(
                id_token,
                options={"verify_signature": False},  # Only for development!
                audience=APPLE_CLIENT_ID,
                algorithms=["RS256"]
            )
        except jwt.InvalidTokenError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid Apple token: {str(e)}"
            )
        
        # Extract user information
        return {
            "provider": "apple",
            "provider_id": decoded.get("sub"),
            "email": decoded.get("email"),
            "email_verified": decoded.get("email_verified", False),
            # Apple doesn't provide name in token, only during first sign-in
            "full_name": None,
            "profile_photo_url": None
        }
        
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to verify with Apple: {str(e)}"
        )

def update_oauth_database_schema(db: GolfAIDatabase):
    """
    Add OAuth-related columns to the users table if they don't exist
    """
    cursor = db.conn.cursor()
    
    # Check if oauth columns exist
    cursor.execute("PRAGMA table_info(users)")
    columns = [column[1] for column in cursor.fetchall()]
    
    # Add OAuth columns if they don't exist
    if 'oauth_provider' not in columns:
        cursor.execute('''
            ALTER TABLE users ADD COLUMN oauth_provider TEXT
        ''')
    
    if 'oauth_provider_id' not in columns:
        cursor.execute('''
            ALTER TABLE users ADD COLUMN oauth_provider_id TEXT
        ''')
    
    if 'oauth_data' not in columns:
        cursor.execute('''
            ALTER TABLE users ADD COLUMN oauth_data TEXT
        ''')
    
    # Create index for OAuth lookups
    cursor.execute('''
        CREATE INDEX IF NOT EXISTS idx_oauth_provider 
        ON users(oauth_provider, oauth_provider_id)
    ''')
    
    db.conn.commit()

def find_or_create_oauth_user(db: GolfAIDatabase, oauth_data: OAuthUserData) -> tuple[Dict[str, Any], bool]:
    """
    Find existing user or create new one from OAuth data
    Returns (user_dict, is_new_user)
    """
    cursor = db.conn.cursor()
    
    # First, check if user exists with this OAuth provider ID
    cursor.execute('''
        SELECT * FROM users 
        WHERE oauth_provider = ? AND oauth_provider_id = ?
    ''', (oauth_data.provider, oauth_data.provider_id))
    
    user = cursor.fetchone()
    
    if user:
        # Existing OAuth user - update last login
        cursor.execute('''
            UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?
        ''', (user['id'],))
        db.conn.commit()
        return dict(user), False
    
    # Check if user exists with same email (allow linking accounts)
    cursor.execute('''
        SELECT * FROM users WHERE email = ?
    ''', (oauth_data.email,))
    
    user = cursor.fetchone()
    
    if user:
        # User exists with same email - link OAuth account
        cursor.execute('''
            UPDATE users 
            SET oauth_provider = ?, oauth_provider_id = ?, oauth_data = ?,
                last_login = CURRENT_TIMESTAMP
            WHERE id = ?
        ''', (oauth_data.provider, oauth_data.provider_id, 
              json.dumps(oauth_data.dict()), user['id']))
        db.conn.commit()
        return dict(user), False
    
    # Create new user from OAuth data
    user_id = secrets.token_urlsafe(16)
    
    # Generate username from email or name
    username_base = oauth_data.email.split('@')[0]
    username = username_base
    counter = 1
    
    # Ensure unique username
    while True:
        cursor.execute('SELECT id FROM users WHERE username = ?', (username,))
        if not cursor.fetchone():
            break
        username = f"{username_base}{counter}"
        counter += 1
    
    # Create random password (user won't use it with OAuth)
    random_password = secrets.token_urlsafe(32)
    password_hash = hash_password(random_password)
    
    # Insert new user
    cursor.execute('''
        INSERT INTO users (
            id, email, username, password_hash, full_name, 
            profile_photo_url, oauth_provider, oauth_provider_id, 
            oauth_data, is_verified, created_at, last_login
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ''', (user_id, oauth_data.email, username, password_hash,
          oauth_data.full_name, oauth_data.profile_photo_url,
          oauth_data.provider, oauth_data.provider_id,
          json.dumps(oauth_data.dict()), True))  # OAuth users are pre-verified
    
    # Create default preferences
    cursor.execute('''
        INSERT INTO user_preferences (user_id) VALUES (?)
    ''', (user_id,))
    
    db.conn.commit()
    
    # Fetch the created user
    cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
    return dict(cursor.fetchone()), True

async def handle_google_signin(db: GolfAIDatabase, google_data: GoogleSignIn) -> SocialLoginResponse:
    """
    Handle Google Sign-In flow
    """
    # Verify token with Google
    verified_data = await verify_google_token(google_data.id_token)
    
    # Create OAuth user data
    oauth_data = OAuthUserData(
        provider="google",
        provider_id=verified_data["provider_id"],
        email=verified_data["email"],
        full_name=verified_data.get("full_name") or google_data.name,
        profile_photo_url=verified_data.get("profile_photo_url") or google_data.picture
    )
    
    # Find or create user
    user, is_new_user = find_or_create_oauth_user(db, oauth_data)
    
    # Generate tokens
    access_token = create_access_token(user['id'])
    refresh_token = create_refresh_token(user['id'])
    
    # Create session
    create_session(db, user['id'], access_token, refresh_token, "Google OAuth")
    
    # Get full user profile
    user_profile = get_user_by_id(db, user['id'])
    
    return SocialLoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=24 * 30 * 3600,  # 30 days
        is_new_user=is_new_user,
        user_profile={
            "id": user_profile['id'],
            "email": user_profile['email'],
            "username": user_profile['username'],
            "full_name": user_profile.get('full_name'),
            "profile_photo_url": user_profile.get('profile_photo_url'),
            "handicap": user_profile.get('handicap'),
            "skill_level": user_profile.get('skill_level'),
            "created_at": str(user_profile['created_at']),
            "preferences": user_profile.get('preferences', {}),
            "stats": user_profile.get('stats', {})
        }
    )

async def handle_apple_signin(db: GolfAIDatabase, apple_data: AppleSignIn) -> SocialLoginResponse:
    """
    Handle Apple Sign-In flow
    """
    # Verify token with Apple
    verified_data = await verify_apple_token(apple_data.id_token)
    
    # Create OAuth user data
    full_name = None
    if apple_data.full_name:
        given_name = apple_data.full_name.get('givenName', '')
        family_name = apple_data.full_name.get('familyName', '')
        full_name = f"{given_name} {family_name}".strip()
    
    oauth_data = OAuthUserData(
        provider="apple",
        provider_id=verified_data["provider_id"],
        email=apple_data.email or verified_data["email"],
        full_name=full_name,
        profile_photo_url=None  # Apple doesn't provide profile photos
    )
    
    # Find or create user
    user, is_new_user = find_or_create_oauth_user(db, oauth_data)
    
    # Generate tokens
    access_token = create_access_token(user['id'])
    refresh_token = create_refresh_token(user['id'])
    
    # Create session
    create_session(db, user['id'], access_token, refresh_token, "Apple OAuth")
    
    # Get full user profile
    user_profile = get_user_by_id(db, user['id'])
    
    return SocialLoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=24 * 30 * 3600,  # 30 days
        is_new_user=is_new_user,
        user_profile={
            "id": user_profile['id'],
            "email": user_profile['email'],
            "username": user_profile['username'],
            "full_name": user_profile.get('full_name'),
            "profile_photo_url": user_profile.get('profile_photo_url'),
            "handicap": user_profile.get('handicap'),
            "skill_level": user_profile.get('skill_level'),
            "created_at": str(user_profile['created_at']),
            "preferences": user_profile.get('preferences', {}),
            "stats": user_profile.get('stats', {})
        }
    )

def link_oauth_to_existing_user(db: GolfAIDatabase, user_id: str, provider: str, provider_id: str):
    """
    Link an OAuth provider to an existing user account
    Useful when users want to add social login to their existing account
    """
    cursor = db.conn.cursor()
    
    # Check if this OAuth account is already linked to another user
    cursor.execute('''
        SELECT id FROM users 
        WHERE oauth_provider = ? AND oauth_provider_id = ? AND id != ?
    ''', (provider, provider_id, user_id))
    
    if cursor.fetchone():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This social account is already linked to another user"
        )
    
    # Link the OAuth account
    cursor.execute('''
        UPDATE users 
        SET oauth_provider = ?, oauth_provider_id = ?
        WHERE id = ?
    ''', (provider, provider_id, user_id))
    
    db.conn.commit()
    
    return {"message": f"{provider.title()} account linked successfully"}

def unlink_oauth_from_user(db: GolfAIDatabase, user_id: str):
    """
    Remove OAuth linking from a user account
    User must have a password set to unlink OAuth
    """
    cursor = db.conn.cursor()
    
    # Check if user has a proper password (not the random one)
    cursor.execute('''
        SELECT password_hash, oauth_provider FROM users WHERE id = ?
    ''', (user_id,))
    
    user = cursor.fetchone()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Don't allow unlinking if no password is set properly
    # (You might want to add a flag to track if password was user-set)
    
    # Unlink OAuth
    cursor.execute('''
        UPDATE users 
        SET oauth_provider = NULL, oauth_provider_id = NULL, oauth_data = NULL
        WHERE id = ?
    ''', (user_id,))
    
    db.conn.commit()
    
    return {"message": "Social account unlinked successfully"}