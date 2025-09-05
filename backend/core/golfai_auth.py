"""
GolfSwingAI Authentication System
Secure JWT-based authentication with SQLite database for user management
"""

import sqlite3
import json
import os
from pathlib import Path
from datetime import datetime, timedelta
import hashlib
import secrets
from typing import Dict, List, Optional, Any
import jwt
import bcrypt
from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, Field

# JWT Configuration
JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", secrets.token_urlsafe(32))
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_HOURS = 24 * 30  # 30 days for persistent login

# Security scheme for FastAPI
security = HTTPBearer()

class GolfAIDatabase:
    """Database manager for GolfSwingAI user data"""
    
    def __init__(self, db_path: str = None):
        """Initialize GolfSwingAI database"""
        if db_path is None:
            # Create separate GolfSwingAI data directory
            data_dir = Path.home() / "Documents" / "GolfSwingAI_Data"
            data_dir.mkdir(parents=True, exist_ok=True)
            self.db_path = data_dir / "golfai_users.db"
        else:
            self.db_path = Path(db_path)
        
        # Initialize database connection
        self.conn = sqlite3.connect(str(self.db_path), check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self._create_tables()
        
        print(f"GolfSwingAI Authentication database initialized at: {self.db_path}")
        print(f"This is separate from MotorMates - dedicated to Golf Swing AI users only")
    
    def _create_tables(self):
        """Create database tables if they don't exist"""
        cursor = self.conn.cursor()
        
        # Users table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                email TEXT UNIQUE NOT NULL,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                full_name TEXT,
                handicap REAL,
                skill_level TEXT,
                preferred_hand TEXT,
                profile_photo_url TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_login TIMESTAMP,
                is_active BOOLEAN DEFAULT 1,
                is_verified BOOLEAN DEFAULT 0,
                verification_token TEXT,
                reset_token TEXT,
                reset_token_expires TIMESTAMP
            )
        ''')
        
        # User preferences table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_preferences (
                user_id TEXT PRIMARY KEY,
                units TEXT DEFAULT 'imperial',
                receive_tips BOOLEAN DEFAULT 1,
                share_data_for_improvement BOOLEAN DEFAULT 0,
                notification_enabled BOOLEAN DEFAULT 1,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        ''')
        
        # Swing history table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS swing_history (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                video_url TEXT,
                predicted_label TEXT,
                confidence REAL,
                camera_angle TEXT,
                physics_insights TEXT,
                recommendations TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                notes TEXT,
                is_favorite BOOLEAN DEFAULT 0,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        ''')
        
        # Progress tracking table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_progress (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                date DATE NOT NULL,
                swings_analyzed INTEGER DEFAULT 0,
                on_plane_count INTEGER DEFAULT 0,
                too_steep_count INTEGER DEFAULT 0,
                too_flat_count INTEGER DEFAULT 0,
                average_confidence REAL,
                improvement_score REAL,
                FOREIGN KEY (user_id) REFERENCES users (id),
                UNIQUE(user_id, date)
            )
        ''')
        
        # Sessions table for token management
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                token TEXT UNIQUE NOT NULL,
                refresh_token TEXT UNIQUE,
                device_info TEXT,
                ip_address TEXT,
                expires_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                is_active BOOLEAN DEFAULT 1,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        ''')
        
        self.conn.commit()
    
    def close(self):
        """Close database connection"""
        self.conn.close()

# Pydantic models for request/response
class UserRegister(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=30)
    password: str = Field(..., min_length=6)
    full_name: Optional[str] = None
    handicap: Optional[float] = None
    skill_level: Optional[str] = "beginner"  # beginner, intermediate, advanced, pro
    preferred_hand: Optional[str] = "right"  # right, left

class UserLogin(BaseModel):
    username: str  # Can be email or username
    password: str
    device_info: Optional[str] = None

class UserProfile(BaseModel):
    id: str
    email: str
    username: str
    full_name: Optional[str]
    handicap: Optional[float]
    skill_level: Optional[str]
    preferred_hand: Optional[str]
    profile_photo_url: Optional[str]
    created_at: str
    last_login: Optional[str]
    is_verified: bool
    preferences: Optional[Dict[str, Any]]
    stats: Optional[Dict[str, Any]]

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    user: UserProfile

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    handicap: Optional[float] = None
    skill_level: Optional[str] = None
    preferred_hand: Optional[str] = None

class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=6)

class PasswordReset(BaseModel):
    email: EmailStr

class SwingRecord(BaseModel):
    predicted_label: str
    confidence: float
    camera_angle: Optional[str]
    physics_insights: Optional[str]
    recommendations: Optional[List[str]]
    notes: Optional[str]
    video_url: Optional[str]

# Authentication functions
def hash_password(password: str) -> str:
    """Hash password using bcrypt"""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    """Verify password against hash"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def create_access_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    
    payload = {
        "sub": user_id,
        "exp": expire,
        "iat": datetime.utcnow(),
        "type": "access"
    }
    
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)

def create_refresh_token(user_id: str) -> str:
    """Create JWT refresh token with longer expiration"""
    expire = datetime.utcnow() + timedelta(days=90)  # 90 days for refresh token
    
    payload = {
        "sub": user_id,
        "exp": expire,
        "iat": datetime.utcnow(),
        "type": "refresh"
    }
    
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)

def decode_token(token: str) -> Dict[str, Any]:
    """Decode and verify JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired"
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    """Get current user from JWT token"""
    token = credentials.credentials
    payload = decode_token(token)
    
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type"
        )
    
    return payload.get("sub")

# Database instance
_db_instance = None

def get_db() -> GolfAIDatabase:
    """Get database instance (singleton)"""
    global _db_instance
    if _db_instance is None:
        _db_instance = GolfAIDatabase()
    return _db_instance

# User management functions
def create_user(db: GolfAIDatabase, user_data: UserRegister) -> Dict[str, Any]:
    """Create a new user"""
    cursor = db.conn.cursor()
    
    # Check if email or username already exists
    cursor.execute("SELECT id FROM users WHERE email = ? OR username = ?", 
                   (user_data.email, user_data.username))
    if cursor.fetchone():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email or username already registered"
        )
    
    # Create user
    user_id = secrets.token_urlsafe(16)
    password_hash = hash_password(user_data.password)
    verification_token = secrets.token_urlsafe(32)
    
    cursor.execute('''
        INSERT INTO users (id, email, username, password_hash, full_name, 
                          handicap, skill_level, preferred_hand, verification_token)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (user_id, user_data.email, user_data.username, password_hash,
          user_data.full_name, user_data.handicap, user_data.skill_level,
          user_data.preferred_hand, verification_token))
    
    # Create default preferences
    cursor.execute('''
        INSERT INTO user_preferences (user_id) VALUES (?)
    ''', (user_id,))
    
    db.conn.commit()
    
    return {
        "id": user_id,
        "email": user_data.email,
        "username": user_data.username,
        "verification_token": verification_token
    }

def authenticate_user(db: GolfAIDatabase, login_data: UserLogin) -> Optional[Dict[str, Any]]:
    """Authenticate user and return user data"""
    cursor = db.conn.cursor()
    
    # Check by email or username
    cursor.execute('''
        SELECT id, email, username, password_hash, full_name, handicap, 
               skill_level, preferred_hand, profile_photo_url, created_at,
               last_login, is_active, is_verified
        FROM users 
        WHERE (email = ? OR username = ?) AND is_active = 1
    ''', (login_data.username, login_data.username))
    
    user = cursor.fetchone()
    if not user:
        return None
    
    # Verify password
    if not verify_password(login_data.password, user['password_hash']):
        return None
    
    # Update last login
    cursor.execute('''
        UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?
    ''', (user['id'],))
    db.conn.commit()
    
    return dict(user)

def get_user_by_id(db: GolfAIDatabase, user_id: str) -> Optional[Dict[str, Any]]:
    """Get user by ID"""
    cursor = db.conn.cursor()
    
    cursor.execute('''
        SELECT id, email, username, full_name, handicap, skill_level, 
               preferred_hand, profile_photo_url, created_at, last_login, is_verified
        FROM users WHERE id = ? AND is_active = 1
    ''', (user_id,))
    
    user = cursor.fetchone()
    if user:
        # Get preferences
        cursor.execute('SELECT * FROM user_preferences WHERE user_id = ?', (user_id,))
        preferences = cursor.fetchone()
        
        # Get stats
        cursor.execute('''
            SELECT COUNT(*) as total_swings,
                   SUM(CASE WHEN predicted_label = 'on_plane' THEN 1 ELSE 0 END) as on_plane_count,
                   AVG(confidence) as avg_confidence
            FROM swing_history WHERE user_id = ?
        ''', (user_id,))
        stats = cursor.fetchone()
        
        user_dict = dict(user)
        user_dict['preferences'] = dict(preferences) if preferences else {}
        user_dict['stats'] = dict(stats) if stats else {}
        
        return user_dict
    
    return None

def update_user(db: GolfAIDatabase, user_id: str, update_data: UserUpdate) -> bool:
    """Update user profile"""
    cursor = db.conn.cursor()
    
    update_fields = []
    values = []
    
    for field, value in update_data.dict(exclude_unset=True).items():
        if value is not None:
            update_fields.append(f"{field} = ?")
            values.append(value)
    
    if not update_fields:
        return False
    
    values.append(user_id)
    query = f"UPDATE users SET {', '.join(update_fields)}, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
    
    cursor.execute(query, values)
    db.conn.commit()
    
    return cursor.rowcount > 0

def save_swing_record(db: GolfAIDatabase, user_id: str, swing_data: SwingRecord) -> str:
    """Save swing analysis record"""
    cursor = db.conn.cursor()
    
    record_id = secrets.token_urlsafe(16)
    
    cursor.execute('''
        INSERT INTO swing_history (id, user_id, video_url, predicted_label, confidence,
                                  camera_angle, physics_insights, recommendations, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (record_id, user_id, swing_data.video_url, swing_data.predicted_label,
          swing_data.confidence, swing_data.camera_angle, swing_data.physics_insights,
          json.dumps(swing_data.recommendations) if swing_data.recommendations else None,
          swing_data.notes))
    
    # Update daily progress
    today = datetime.now().date()
    cursor.execute('''
        INSERT INTO user_progress (user_id, date, swings_analyzed, on_plane_count, 
                                  too_steep_count, too_flat_count, average_confidence)
        VALUES (?, ?, 1, ?, ?, ?, ?)
        ON CONFLICT(user_id, date) DO UPDATE SET
            swings_analyzed = swings_analyzed + 1,
            on_plane_count = on_plane_count + ?,
            too_steep_count = too_steep_count + ?,
            too_flat_count = too_flat_count + ?,
            average_confidence = (average_confidence * swings_analyzed + ?) / (swings_analyzed + 1)
    ''', (user_id, today,
          1 if swing_data.predicted_label == 'on_plane' else 0,
          1 if swing_data.predicted_label == 'too_steep' else 0,
          1 if swing_data.predicted_label == 'too_flat' else 0,
          swing_data.confidence,
          1 if swing_data.predicted_label == 'on_plane' else 0,
          1 if swing_data.predicted_label == 'too_steep' else 0,
          1 if swing_data.predicted_label == 'too_flat' else 0,
          swing_data.confidence))
    
    db.conn.commit()
    
    return record_id

def get_user_swing_history(db: GolfAIDatabase, user_id: str, limit: int = 50) -> List[Dict[str, Any]]:
    """Get user's swing history"""
    cursor = db.conn.cursor()
    
    cursor.execute('''
        SELECT * FROM swing_history 
        WHERE user_id = ? 
        ORDER BY created_at DESC 
        LIMIT ?
    ''', (user_id, limit))
    
    records = cursor.fetchall()
    return [dict(record) for record in records]

def get_user_progress(db: GolfAIDatabase, user_id: str, days: int = 30) -> List[Dict[str, Any]]:
    """Get user's progress over time"""
    cursor = db.conn.cursor()
    
    cursor.execute('''
        SELECT * FROM user_progress 
        WHERE user_id = ? AND date >= date('now', '-' || ? || ' days')
        ORDER BY date DESC
    ''', (user_id, days))
    
    progress = cursor.fetchall()
    return [dict(record) for record in progress]

def create_session(db: GolfAIDatabase, user_id: str, token: str, refresh_token: str, 
                  device_info: Optional[str] = None) -> str:
    """Create a new session"""
    cursor = db.conn.cursor()
    
    session_id = secrets.token_urlsafe(16)
    expires_at = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    
    cursor.execute('''
        INSERT INTO sessions (id, user_id, token, refresh_token, device_info, expires_at)
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (session_id, user_id, token, refresh_token, device_info, expires_at))
    
    db.conn.commit()
    
    return session_id

def invalidate_session(db: GolfAIDatabase, token: str) -> bool:
    """Invalidate a session (logout)"""
    cursor = db.conn.cursor()
    
    cursor.execute('''
        UPDATE sessions SET is_active = 0 WHERE token = ?
    ''', (token,))
    
    db.conn.commit()
    
    return cursor.rowcount > 0

def refresh_session(db: GolfAIDatabase, refresh_token: str) -> Optional[Dict[str, Any]]:
    """Refresh a session with refresh token"""
    cursor = db.conn.cursor()
    
    cursor.execute('''
        SELECT user_id, device_info FROM sessions 
        WHERE refresh_token = ? AND is_active = 1 AND expires_at > CURRENT_TIMESTAMP
    ''', (refresh_token,))
    
    session = cursor.fetchone()
    if not session:
        return None
    
    # Create new tokens
    new_access_token = create_access_token(session['user_id'])
    new_refresh_token = create_refresh_token(session['user_id'])
    
    # Update session
    cursor.execute('''
        UPDATE sessions 
        SET token = ?, refresh_token = ?, last_accessed = CURRENT_TIMESTAMP,
            expires_at = ?
        WHERE refresh_token = ?
    ''', (new_access_token, new_refresh_token, 
          datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS),
          refresh_token))
    
    db.conn.commit()
    
    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "user_id": session['user_id']
    }