"""
Golf Swing AI - Authentication Module
Handles user registration, login, JWT tokens, and password reset.
Uses SQLite (built-in) + bcrypt (passlib) + JWT (python-jose).

Install dependencies on your server:
    pip install "passlib[bcrypt]" "python-jose[cryptography]"
"""

import os
import sqlite3
import uuid
import smtplib
from datetime import datetime, timedelta, timezone
from typing import Optional
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, field_validator
from passlib.context import CryptContext
from jose import JWTError, jwt

# ---------------------------------------------------------------------------
# Configuration — override these via environment variables on your server
# ---------------------------------------------------------------------------
SECRET_KEY = os.getenv("AUTH_SECRET_KEY", "CHANGE_THIS_IN_PRODUCTION_use_a_long_random_string_here")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 24
REFRESH_TOKEN_EXPIRE_DAYS = 30

# Database path — stored next to this file
DB_PATH = Path(__file__).parent / "users.db"

# Email config (optional — set these to enable real password reset emails)
SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", "noreply@golfswingai.com")
APP_NAME = "Golf Swing AI"

# ---------------------------------------------------------------------------
# Password hashing
# ---------------------------------------------------------------------------
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer_scheme = HTTPBearer()

# ---------------------------------------------------------------------------
# Database setup
# ---------------------------------------------------------------------------

def get_db():
    """Get a database connection."""
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Create tables if they don't exist."""
    conn = get_db()
    try:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id                  TEXT PRIMARY KEY,
                email               TEXT UNIQUE NOT NULL,
                username            TEXT NOT NULL,
                first_name          TEXT NOT NULL DEFAULT '',
                last_name           TEXT NOT NULL DEFAULT '',
                password_hash       TEXT NOT NULL,
                handicap            REAL,
                preferred_hand      TEXT NOT NULL DEFAULT 'right',
                experience_level    TEXT NOT NULL DEFAULT 'beginner',
                home_course         TEXT,
                years_played        INTEGER,
                date_created        TEXT NOT NULL,
                last_login          TEXT,
                is_active           INTEGER NOT NULL DEFAULT 1,
                reset_token         TEXT,
                reset_token_expires TEXT
            )
        """)
        conn.commit()
        print("✅ Auth: Database initialized at", DB_PATH)
    finally:
        conn.close()

# ---------------------------------------------------------------------------
# JWT helpers
# ---------------------------------------------------------------------------

def create_access_token(user_id: str, email: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    payload = {"sub": user_id, "email": email, "type": "access", "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {"sub": user_id, "type": "refresh", "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str, expected_type: str = "access") -> dict:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != expected_type:
            raise HTTPException(status_code=401, detail="Invalid token type")
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

def get_current_user_id(credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme)) -> str:
    """Dependency: extract and verify the Bearer token, return user_id."""
    payload = verify_token(credentials.credentials, expected_type="access")
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")
    return user_id

# ---------------------------------------------------------------------------
# Pydantic request/response models
# ---------------------------------------------------------------------------

class RegisterRequest(BaseModel):
    email: str
    password: str
    username: str
    first_name: str = ""
    last_name: str = ""
    handicap: Optional[float] = None
    preferred_hand: str = "right"
    experience_level: str = "beginner"
    home_course: Optional[str] = None
    years_played: Optional[int] = None

    @field_validator("email")
    @classmethod
    def email_must_be_valid(cls, v):
        import re
        if not re.match(r"[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,64}", v):
            raise ValueError("Invalid email address")
        return v.lower().strip()

    @field_validator("password")
    @classmethod
    def password_must_be_strong(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v

class LoginRequest(BaseModel):
    email: str
    password: str

class RefreshRequest(BaseModel):
    refresh_token: str

class ResetPasswordRequest(BaseModel):
    email: str

class UpdateProfileRequest(BaseModel):
    username: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    handicap: Optional[float] = None
    preferred_hand: Optional[str] = None
    experience_level: Optional[str] = None
    home_course: Optional[str] = None
    years_played: Optional[int] = None

class UserResponse(BaseModel):
    id: str
    email: str
    username: str
    first_name: str
    last_name: str
    handicap: Optional[float]
    preferred_hand: str
    experience_level: str
    home_course: Optional[str]
    years_played: Optional[int]
    date_created: str
    last_login: Optional[str]

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse

# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def row_to_user_response(row) -> UserResponse:
    return UserResponse(
        id=row["id"],
        email=row["email"],
        username=row["username"],
        first_name=row["first_name"],
        last_name=row["last_name"],
        handicap=row["handicap"],
        preferred_hand=row["preferred_hand"],
        experience_level=row["experience_level"],
        home_course=row["home_course"],
        years_played=row["years_played"],
        date_created=row["date_created"],
        last_login=row["last_login"],
    )

def get_user_by_email(conn, email: str):
    return conn.execute("SELECT * FROM users WHERE email = ? AND is_active = 1", (email.lower(),)).fetchone()

def get_user_by_id(conn, user_id: str):
    return conn.execute("SELECT * FROM users WHERE id = ? AND is_active = 1", (user_id,)).fetchone()

# ---------------------------------------------------------------------------
# Email helper (optional)
# ---------------------------------------------------------------------------

def send_reset_email(to_email: str, reset_token: str):
    """Send a password reset email. Only runs if SMTP_HOST is configured."""
    if not SMTP_HOST:
        print(f"📧 [DEV] Password reset token for {to_email}: {reset_token}")
        return

    reset_link = f"https://golfai.duckdns.org:8443/reset?token={reset_token}"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"Reset your {APP_NAME} password"
    msg["From"] = FROM_EMAIL
    msg["To"] = to_email

    text = f"""
Hi,

You requested a password reset for your {APP_NAME} account.

Your reset token is: {reset_token}

This token expires in 1 hour.

If you didn't request this, ignore this email.
"""
    html = f"""
<html><body>
<h2>{APP_NAME} - Password Reset</h2>
<p>Your reset token is: <strong>{reset_token}</strong></p>
<p>This token expires in 1 hour.</p>
<p>If you didn't request this, ignore this email.</p>
</body></html>
"""
    msg.attach(MIMEText(text, "plain"))
    msg.attach(MIMEText(html, "html"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.sendmail(FROM_EMAIL, to_email, msg.as_string())
        print(f"✅ Reset email sent to {to_email}")
    except Exception as e:
        print(f"❌ Failed to send reset email: {e}")

# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=AuthResponse, status_code=201)
async def register(req: RegisterRequest):
    """Create a new account."""
    conn = get_db()
    try:
        # Check email uniqueness
        if get_user_by_email(conn, req.email):
            raise HTTPException(status_code=409, detail="An account with this email already exists")

        user_id = str(uuid.uuid4())
        password_hash = pwd_context.hash(req.password)
        now = datetime.now(timezone.utc).isoformat()

        conn.execute("""
            INSERT INTO users (id, email, username, first_name, last_name, password_hash,
                               handicap, preferred_hand, experience_level, home_course,
                               years_played, date_created, last_login)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            user_id, req.email.lower(), req.username, req.first_name, req.last_name,
            password_hash, req.handicap, req.preferred_hand, req.experience_level,
            req.home_course, req.years_played, now, now
        ))
        conn.commit()

        user = get_user_by_id(conn, user_id)
        return AuthResponse(
            access_token=create_access_token(user_id, req.email),
            refresh_token=create_refresh_token(user_id),
            user=row_to_user_response(user),
        )
    finally:
        conn.close()


@router.post("/login", response_model=AuthResponse)
async def login(req: LoginRequest):
    """Sign in with email and password. Returns JWT tokens."""
    conn = get_db()
    try:
        user = get_user_by_email(conn, req.email)

        if not user or not pwd_context.verify(req.password, user["password_hash"]):
            raise HTTPException(status_code=401, detail="Invalid email or password")

        # Update last_login
        now = datetime.now(timezone.utc).isoformat()
        conn.execute("UPDATE users SET last_login = ? WHERE id = ?", (now, user["id"]))
        conn.commit()

        # Re-fetch to get updated row
        user = get_user_by_id(conn, user["id"])
        return AuthResponse(
            access_token=create_access_token(user["id"], user["email"]),
            refresh_token=create_refresh_token(user["id"]),
            user=row_to_user_response(user),
        )
    finally:
        conn.close()


@router.post("/refresh")
async def refresh_token(req: RefreshRequest):
    """Exchange a refresh token for a new access token."""
    payload = verify_token(req.refresh_token, expected_type="refresh")
    user_id = payload.get("sub")

    conn = get_db()
    try:
        user = get_user_by_id(conn, user_id)
        if not user:
            raise HTTPException(status_code=401, detail="User not found")

        return {
            "access_token": create_access_token(user["id"], user["email"]),
            "token_type": "bearer",
        }
    finally:
        conn.close()


@router.get("/me", response_model=UserResponse)
async def get_me(user_id: str = Depends(get_current_user_id)):
    """Get the currently authenticated user's profile."""
    conn = get_db()
    try:
        user = get_user_by_id(conn, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        return row_to_user_response(user)
    finally:
        conn.close()


@router.put("/me", response_model=UserResponse)
async def update_me(req: UpdateProfileRequest, user_id: str = Depends(get_current_user_id)):
    """Update the currently authenticated user's profile."""
    conn = get_db()
    try:
        user = get_user_by_id(conn, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # Build update dict from non-None fields
        updates = {k: v for k, v in req.model_dump().items() if v is not None}
        if not updates:
            return row_to_user_response(user)

        set_clause = ", ".join(f"{k} = ?" for k in updates)
        values = list(updates.values()) + [user_id]
        conn.execute(f"UPDATE users SET {set_clause} WHERE id = ?", values)
        conn.commit()

        user = get_user_by_id(conn, user_id)
        return row_to_user_response(user)
    finally:
        conn.close()


@router.post("/reset-password/request")
async def request_password_reset(req: ResetPasswordRequest):
    """Request a password reset token. Always returns 200 to prevent email enumeration."""
    conn = get_db()
    try:
        user = get_user_by_email(conn, req.email)
        if user:
            reset_token = str(uuid.uuid4()).replace("-", "")
            expires = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
            conn.execute(
                "UPDATE users SET reset_token = ?, reset_token_expires = ? WHERE id = ?",
                (reset_token, expires, user["id"])
            )
            conn.commit()
            send_reset_email(req.email, reset_token)

        return {"message": "If an account with that email exists, a reset link has been sent."}
    finally:
        conn.close()


@router.post("/reset-password/confirm")
async def confirm_password_reset(token: str, new_password: str):
    """Apply a new password using a reset token."""
    if len(new_password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")

    conn = get_db()
    try:
        now = datetime.now(timezone.utc).isoformat()
        user = conn.execute(
            "SELECT * FROM users WHERE reset_token = ? AND reset_token_expires > ? AND is_active = 1",
            (token, now)
        ).fetchone()

        if not user:
            raise HTTPException(status_code=400, detail="Invalid or expired reset token")

        new_hash = pwd_context.hash(new_password)
        conn.execute(
            "UPDATE users SET password_hash = ?, reset_token = NULL, reset_token_expires = NULL WHERE id = ?",
            (new_hash, user["id"])
        )
        conn.commit()
        return {"message": "Password updated successfully"}
    finally:
        conn.close()


@router.delete("/me")
async def delete_account(user_id: str = Depends(get_current_user_id)):
    """Soft-delete the authenticated user's account."""
    conn = get_db()
    try:
        conn.execute("UPDATE users SET is_active = 0 WHERE id = ?", (user_id,))
        conn.commit()
        return {"message": "Account deleted successfully"}
    finally:
        conn.close()
