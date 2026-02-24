# Golf Swing AI — Server Auth Setup
## Paste this entire file into Claude Code on the server machine

Please do the following steps exactly. The goal is to add real user authentication to the existing Golf Swing AI FastAPI server.

---

### Step 1 — Install Python dependencies

Run this command:

```bash
pip install "passlib[bcrypt]" "python-jose[cryptography]"
```

---

### Step 2 — Generate a secret key and save it

Run this to generate a secure secret key:

```bash
python3 -c "import secrets; print(secrets.token_hex(64))"
```

Then set it as an environment variable (replace the placeholder with the output from above):

```bash
export AUTH_SECRET_KEY="PASTE_YOUR_GENERATED_KEY_HERE"
```

To make this permanent across reboots, add the export line to `~/.bashrc` or `~/.profile`.

---

### Step 3 — Create the file `backend/auth.py`

Create the file at `backend/auth.py` in the project root with exactly this content:

```python
"""
Golf Swing AI - Authentication Module
Handles user registration, login, JWT tokens, and password reset.
Uses SQLite (built-in) + bcrypt (passlib) + JWT (python-jose).
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
from pydantic import BaseModel, field_validator
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
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
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
    if not SMTP_HOST:
        print(f"📧 [DEV] Password reset token for {to_email}: {reset_token}")
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"Reset your {APP_NAME} password"
    msg["From"] = FROM_EMAIL
    msg["To"] = to_email
    text = f"Your reset token is: {reset_token}\n\nExpires in 1 hour."
    html = f"<p>Your reset token is: <strong>{reset_token}</strong></p><p>Expires in 1 hour.</p>"
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
    conn = get_db()
    try:
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
    conn = get_db()
    try:
        user = get_user_by_email(conn, req.email)
        if not user or not pwd_context.verify(req.password, user["password_hash"]):
            raise HTTPException(status_code=401, detail="Invalid email or password")

        now = datetime.now(timezone.utc).isoformat()
        conn.execute("UPDATE users SET last_login = ? WHERE id = ?", (now, user["id"]))
        conn.commit()

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
    conn = get_db()
    try:
        user = get_user_by_id(conn, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

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
    conn = get_db()
    try:
        conn.execute("UPDATE users SET is_active = 0 WHERE id = ?", (user_id,))
        conn.commit()
        return {"message": "Account deleted successfully"}
    finally:
        conn.close()
```

---

### Step 4 — Update `api_minimal.py`

Find the block in `api_minimal.py` that looks like this:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

Add these lines **immediately after** that block (before the first `@app.get` route):

```python
# Mount authentication router
try:
    from backend.auth import router as auth_router, init_db as auth_init_db
    auth_init_db()
    app.include_router(auth_router)
    print("✅ Auth module loaded — endpoints available at /auth/*")
except Exception as e:
    print(f"⚠️  Auth module not loaded: {e}")
```

---

### Step 5 — Restart the server

```bash
# If running directly:
python api_minimal.py

# If using uvicorn:
uvicorn api_minimal:app --host 0.0.0.0 --port 8000 --reload
```

On startup you should see:
```
✅ Auth: Database initialized at .../backend/users.db
✅ Auth module loaded — endpoints available at /auth/*
```

---

### Step 6 — Verify it works

Run these test commands (the server must be running):

```bash
# Test 1: Register a user
curl -X POST https://golfai.duckdns.org:8443/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","username":"TestGolfer","first_name":"Test","last_name":"User"}'

# Expected: {"access_token":"eyJ...","refresh_token":"eyJ...","token_type":"bearer","user":{...}}

# Test 2: Login
curl -X POST https://golfai.duckdns.org:8443/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Test 3: Get profile (replace TOKEN with the access_token from login above)
curl https://golfai.duckdns.org:8443/auth/me \
  -H "Authorization: Bearer TOKEN"
```

You can also browse to `https://golfai.duckdns.org:8443/docs` to use the interactive API docs.

---

### Done ✅

The server now handles real user accounts stored in `backend/users.db`. The iOS app will automatically connect to these endpoints on next build.
