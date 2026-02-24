# Golf Swing AI — Server Auth Setup Guide

Paste these instructions on your **server machine**. This adds real user registration, login, and JWT authentication to your existing FastAPI backend.

---

## What This Adds

Your server will gain these new endpoints:

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/register` | Create a new account |
| POST | `/auth/login` | Sign in → returns JWT tokens |
| POST | `/auth/refresh` | Exchange refresh token for new access token |
| GET | `/auth/me` | Get current user profile (requires JWT) |
| PUT | `/auth/me` | Update profile (requires JWT) |
| POST | `/auth/reset-password/request` | Request password reset email |
| POST | `/auth/reset-password/confirm` | Apply new password with reset token |
| DELETE | `/auth/me` | Delete account (requires JWT) |

Users are stored in a local **SQLite database** (`backend/users.db`). No external database setup needed.

---

## Step 1 — Install Dependencies

Run this on your server in the project directory:

```bash
pip install "passlib[bcrypt]" "python-jose[cryptography]"
```

If you use a virtual environment:
```bash
source venv/bin/activate   # or: venv\Scripts\activate on Windows
pip install "passlib[bcrypt]" "python-jose[cryptography]"
```

---

## Step 2 — Set the Secret Key (IMPORTANT)

The JWT secret key **must** be set to a long random string in production. Run this once on your server to generate one:

```bash
python3 -c "import secrets; print(secrets.token_hex(64))"
```

Then set it as an environment variable **before** starting the server:

```bash
# Linux/Mac — add to your ~/.bashrc or server startup script:
export AUTH_SECRET_KEY="paste_your_generated_key_here"

# Windows PowerShell:
$env:AUTH_SECRET_KEY = "paste_your_generated_key_here"
```

> ⚠️ If you skip this, the server still works but uses a default key. Anyone who knows the default can forge tokens. Always set a real key in production.

---

## Step 3 — Verify the Files Are in Place

Your project should have:
```
Golf Swing AI/
├── api_minimal.py          ← already updated to mount auth router
├── backend/
│   └── auth.py             ← new file — the auth module
```

If you pulled these from git, both files are already there. The `users.db` database file will be created automatically when the server first starts.

---

## Step 4 — Restart the Server

```bash
# If you run it directly:
python api_minimal.py

# If you use uvicorn:
uvicorn api_minimal:app --host 0.0.0.0 --port 8000 --reload

# If you have a start script (e.g. start_server_with_logs.bat):
# Just restart it normally — the auth module loads automatically
```

On startup you should see:
```
✅ Auth: Database initialized at .../backend/users.db
✅ Auth module loaded — endpoints available at /auth/*
```

---

## Step 5 — Test That It Works

Run these curl commands from any machine (replace the IP/domain with yours):

```bash
# Register a new user
curl -X POST https://golfai.duckdns.org:8443/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "mypassword123",
    "username": "TestGolfer",
    "first_name": "Test",
    "last_name": "User"
  }'

# You should get back:
# { "access_token": "eyJ...", "refresh_token": "eyJ...", "token_type": "bearer", "user": {...} }


# Login
curl -X POST https://golfai.duckdns.org:8443/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "mypassword123"}'


# Get your profile (paste the access_token from login above)
curl https://golfai.duckdns.org:8443/auth/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE"
```

You can also open `https://golfai.duckdns.org:8443/docs` in a browser to use the interactive API documentation.

---

## Step 6 — (Optional) Enable Real Password Reset Emails

By default, reset tokens are printed to the server log instead of emailed. To send real emails, set these environment variables before starting:

```bash
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="your-gmail@gmail.com"
export SMTP_PASS="your-app-password"      # Use Gmail App Password, not your main password
export FROM_EMAIL="noreply@golfswingai.com"
```

For Gmail, generate an App Password at: https://myaccount.google.com/apppasswords

---

## How Tokens Work (for reference)

- **Access token** — expires in 24 hours. Sent with every API request in the `Authorization: Bearer <token>` header.
- **Refresh token** — expires in 30 days. Used only to get a new access token when the current one expires.
- The iOS app stores both tokens securely in the iOS Keychain.

---

## Troubleshooting

**"Auth module not loaded"** — check that `backend/auth.py` exists and that `passlib` and `python-jose` are installed.

**"Invalid or expired token"** — the client's access token expired. The iOS app automatically uses the refresh token to get a new one.

**Database errors** — make sure the process has write permission to the `backend/` folder. On Linux: `chmod 755 backend/`

**Reset emails not sending** — check your SMTP credentials. The token is always printed to the server log as a fallback.
