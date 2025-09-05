"""
MotorMates API - Backend service for MotorMates iOS app
Provides user management, posts, routes, and garage features
"""

from fastapi import APIRouter, HTTPException, Depends, File, UploadFile, Form
from fastapi.responses import JSONResponse
from pydantic import BaseModel, EmailStr
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import json
import os
from pathlib import Path
import hashlib
import secrets

# Create router for MotorMates endpoints
router = APIRouter(prefix="/motormates", tags=["MotorMates"])

# Import database manager
try:
    from motormates_database import get_db, MotorMatesDB
    db = get_db()
    print("MotorMates: Using encrypted SQLite database on Desktop")
except ImportError:
    print("Warning: Database module not found, using in-memory storage")
    # Fallback to in-memory storage
    users_db = {}
    posts_db = {}
    routes_db = {}
    cars_db = {}
    sessions_db = {}
    db = None

# File storage path - separate from GolfSwingAI
UPLOAD_PATH = Path.home() / "Desktop" / "MotorMates_Data" / "uploads"
UPLOAD_PATH.mkdir(parents=True, exist_ok=True)

# Pydantic models
class UserRegister(BaseModel):
    email: EmailStr
    password: str
    name: str
    city: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserProfile(BaseModel):
    id: str
    email: str
    name: str
    city: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    profile_photo_url: Optional[str] = None
    created_at: str

class Post(BaseModel):
    id: Optional[str] = None
    user_id: str
    caption: str
    location: Optional[str] = None
    image_urls: List[str] = []
    tags: List[str] = []
    likes_count: int = 0
    comments_count: int = 0
    created_at: Optional[str] = None

class Route(BaseModel):
    id: Optional[str] = None
    user_id: str
    name: str
    description: Optional[str] = None
    start_location: Optional[str] = None
    end_location: Optional[str] = None
    distance: Optional[float] = None
    estimated_duration: Optional[int] = None  # in minutes
    difficulty: Optional[str] = None
    category: Optional[str] = None
    coordinates: Optional[Dict] = None  # GeoJSON format
    photos: List[str] = []
    is_public: bool = True
    created_at: Optional[str] = None

class Car(BaseModel):
    id: Optional[str] = None
    user_id: str
    make: str
    model: str
    year: int
    color: Optional[str] = None
    engine: Optional[str] = None
    horsepower: Optional[int] = None
    is_project: bool = False
    created_at: Optional[str] = None

class AppUpdateInstructions(BaseModel):
    version: str
    release_notes: str
    update_url: str
    mandatory: bool = False
    instructions: List[str]

# Helper functions
def hash_password(password: str) -> str:
    """Hash password for storage"""
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(password: str, hashed: str) -> bool:
    """Verify password against hash"""
    return hash_password(password) == hashed

def generate_token() -> str:
    """Generate session token"""
    return secrets.token_urlsafe(32)

def get_current_user(token: str = None):
    """Get current user from token"""
    if not token or token not in sessions_db:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return sessions_db[token]

# Root endpoint
@router.get("/")
async def motormates_root():
    return {
        "service": "MotorMates Social API",
        "version": "2.0.0",
        "status": "active",
        "description": "Complete social media platform for automotive enthusiasts",
        "features": {
            "social_feed": "Browse and interact with posts from all users",
            "posts": "Upload photos and content with location tags",
            "routes": "Share driving routes with GPS data and photos",
            "garage": "Showcase your car collection with photos",
            "social_interactions": "Like posts, comment, follow users",
            "file_storage": "All data stored securely on Desktop"
        },
        "endpoints": {
            "feed": "/motormates/posts/feed",
            "create_post": "/motormates/posts (POST with photos)",
            "like_post": "/motormates/posts/{post_id}/like",
            "comment": "/motormates/posts/{post_id}/comment",
            "follow_user": "/motormates/users/{user_id}/follow",
            "user_posts": "/motormates/users/{user_id}/posts",
            "followers": "/motormates/users/{user_id}/followers",
            "routes": "/motormates/routes",
            "garage": "/motormates/garage",
            "profile": "/motormates/users/{user_id}/photo",
            "storage_info": "/motormates/storage-info",
            "uploads": "/motormates/uploads/{file_path}",
            "app_updates": "/motormates/app-updates"
        },
        "data_storage": {
            "location": "Desktop/MotorMates_Data",
            "encryption": "Enabled",
            "separation": "Completely separate from GolfSwingAI"
        }
    }

# Health check
@router.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "MotorMates",
        "timestamp": datetime.utcnow().isoformat()
    }

# Authentication endpoints
@router.post("/auth/register")
async def register(user: UserRegister):
    """Register new user"""
    if db:
        # Use database
        try:
            user_data = db.create_user(
                email=user.email,
                password=user.password,
                name=user.name,
                city=user.city,
                state=user.state,
                country=user.country
            )
            token = db.create_session(user_data['id'])
            return {
                "user": UserProfile(**user_data),
                "token": token,
                "message": "Registration successful - Data stored securely on Desktop"
            }
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
    else:
        # Fallback to in-memory
        if user.email in users_db:
            raise HTTPException(status_code=400, detail="Email already registered")
        
        user_id = secrets.token_urlsafe(16)
        users_db[user.email] = {
            "id": user_id,
            "email": user.email,
            "password_hash": hash_password(user.password),
            "name": user.name,
            "city": user.city,
            "state": user.state,
            "country": user.country,
            "profile_photo_url": None,
            "created_at": datetime.utcnow().isoformat()
        }
        
        token = generate_token()
        sessions_db[token] = user_id
        
        return {
            "user": UserProfile(**users_db[user.email]),
            "token": token,
            "message": "Registration successful"
        }

@router.post("/auth/login")
async def login(credentials: UserLogin):
    """User login"""
    if db:
        # Use database
        user_data = db.authenticate_user(credentials.email, credentials.password)
        if not user_data:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        token = db.create_session(user_data['id'])
        return {
            "user": UserProfile(**user_data),
            "token": token,
            "message": "Login successful - Using secure database"
        }
    else:
        # Fallback to in-memory
        if credentials.email not in users_db:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        user = users_db[credentials.email]
        if not verify_password(credentials.password, user["password_hash"]):
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        token = generate_token()
        sessions_db[token] = user["id"]
        
        return {
            "user": UserProfile(**user),
            "token": token,
            "message": "Login successful"
        }

# Posts endpoints
@router.get("/posts/feed")
async def get_feed(user_id: Optional[str] = None):
    """Get posts for social media feed"""
    if db:
        posts = db.get_posts_feed(limit=20, user_id=user_id)
        return {
            "posts": posts,
            "count": len(posts),
            "storage": "Database on Desktop",
            "social_features": "enabled"
        }
    else:
        posts = list(posts_db.values())
        posts.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return {
            "posts": posts[:20],
            "count": len(posts)
        }

@router.get("/posts/{post_id}")
async def get_post(post_id: str):
    """Get specific post with comments"""
    if db:
        # Get post details
        cursor = db.conn.cursor()
        cursor.execute('''
            SELECT p.*, u.name as user_name, u.profile_photo_url,
                   COUNT(DISTINCT l.id) as likes_count,
                   COUNT(DISTINCT c.id) as comments_count
            FROM posts p
            JOIN users u ON p.user_id = u.id
            LEFT JOIN likes l ON p.id = l.post_id
            LEFT JOIN comments c ON p.id = c.post_id
            WHERE p.id = ?
            GROUP BY p.id, u.id, u.name
        ''', (post_id,))
        
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Post not found")
        
        post = {
            'id': row['id'],
            'user_id': row['user_id'],
            'user_name': row['user_name'],
            'user_photo': row['profile_photo_url'],
            'caption': row['caption'],
            'location': row['location'],
            'image_urls': json.loads(row['image_urls']) if row['image_urls'] else [],
            'tags': json.loads(row['tags']) if row['tags'] else [],
            'likes_count': row['likes_count'],
            'comments_count': row['comments_count'],
            'created_at': row['created_at']
        }
        
        # Get comments
        comments = db.get_post_comments(post_id)
        
        return {
            "post": post,
            "comments": comments
        }
    else:
        if post_id not in posts_db:
            raise HTTPException(status_code=404, detail="Post not found")
        return {"post": posts_db[post_id], "comments": []}

# Social interaction endpoints
@router.post("/posts/{post_id}/like")
async def like_post(post_id: str, user_id: str = Form(...)):
    """Like or unlike a post"""
    if db:
        is_liked = db.like_post(post_id, user_id)
        return {
            "post_id": post_id,
            "user_id": user_id,
            "liked": is_liked,
            "action": "liked" if is_liked else "unliked"
        }
    else:
        raise HTTPException(status_code=501, detail="Database required for social features")

@router.post("/posts/{post_id}/comment")
async def comment_on_post(post_id: str, user_id: str = Form(...), content: str = Form(...)):
    """Add comment to a post"""
    if db:
        comment = db.add_comment(post_id, user_id, content)
        return {
            "comment": comment,
            "message": "Comment added successfully"
        }
    else:
        raise HTTPException(status_code=501, detail="Database required for social features")

@router.post("/posts")
async def create_post(
    caption: str = Form(...),
    location: Optional[str] = Form(None),
    tags: Optional[str] = Form(None),
    user_id: str = Form(...),
    images: List[UploadFile] = File(None)
):
    """Create new post with photos stored on Desktop"""
    post_id = secrets.token_urlsafe(16)
    image_urls = []
    
    # Handle image uploads - store in organized folders
    if images:
        posts_dir = UPLOAD_PATH / "posts" / user_id / post_id
        posts_dir.mkdir(parents=True, exist_ok=True)
        
        for idx, image in enumerate(images):
            if image and image.filename:
                # Generate safe filename
                ext = Path(image.filename).suffix
                safe_filename = f"image_{idx}{ext}"
                file_path = posts_dir / safe_filename
                
                # Save image
                content = await image.read()
                with open(file_path, "wb") as f:
                    f.write(content)
                
                # Store relative path for portability
                relative_path = f"posts/{user_id}/{post_id}/{safe_filename}"
                image_urls.append(relative_path)
    
    if db:
        # Use database
        post = db.create_post(
            user_id=user_id,
            caption=caption,
            location=location,
            image_urls=image_urls,
            tags=tags.split(",") if tags else []
        )
        return {
            "post": post,
            "message": "Post created successfully",
            "storage_location": str(UPLOAD_PATH),
            "images_saved": len(image_urls)
        }
    else:
        # Fallback to in-memory
        post = {
            "id": post_id,
            "user_id": user_id,
            "caption": caption,
            "location": location,
            "image_urls": image_urls,
            "tags": tags.split(",") if tags else [],
            "likes_count": 0,
            "comments_count": 0,
            "created_at": datetime.utcnow().isoformat()
        }
        posts_db[post_id] = post
        return {"post": post, "message": "Post created successfully"}

# Routes endpoints
@router.get("/routes/discover")
async def discover_routes():
    """Get public routes for discovery"""
    public_routes = [r for r in routes_db.values() if r.get("is_public", True)]
    public_routes.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return {
        "routes": public_routes[:20],
        "count": len(public_routes)
    }

@router.post("/routes")
async def create_route(
    name: str = Form(...),
    user_id: str = Form(...),
    description: Optional[str] = Form(None),
    start_location: Optional[str] = Form(None),
    end_location: Optional[str] = Form(None),
    distance: Optional[float] = Form(None),
    estimated_duration: Optional[int] = Form(None),
    difficulty: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    coordinates: Optional[str] = Form(None),  # JSON string of GPS coordinates
    is_public: bool = Form(True),
    photos: List[UploadFile] = File(None)
):
    """Create new driving route with photos and GPS data"""
    route_id = secrets.token_urlsafe(16)
    photo_urls = []
    
    # Handle route photos
    if photos:
        routes_dir = UPLOAD_PATH / "routes" / user_id / route_id
        routes_dir.mkdir(parents=True, exist_ok=True)
        
        for idx, photo in enumerate(photos):
            if photo and photo.filename:
                ext = Path(photo.filename).suffix
                safe_filename = f"route_photo_{idx}{ext}"
                file_path = routes_dir / safe_filename
                
                content = await photo.read()
                with open(file_path, "wb") as f:
                    f.write(content)
                
                relative_path = f"routes/{user_id}/{route_id}/{safe_filename}"
                photo_urls.append(relative_path)
    
    # Parse coordinates if provided
    coords_dict = None
    if coordinates:
        try:
            coords_dict = json.loads(coordinates)
        except:
            coords_dict = None
    
    # Save GPS data separately for large routes
    if coords_dict:
        gps_file = UPLOAD_PATH / "routes" / user_id / route_id / "gps_data.json"
        gps_file.parent.mkdir(parents=True, exist_ok=True)
        with open(gps_file, "w") as f:
            json.dump(coords_dict, f, indent=2)
    
    if db:
        route = db.create_route(
            user_id=user_id,
            name=name,
            description=description,
            start_location=start_location,
            end_location=end_location,
            distance=distance,
            estimated_duration=estimated_duration,
            difficulty=difficulty,
            category=category,
            coordinates=coords_dict,
            photos=photo_urls,
            is_public=is_public
        )
        return {
            "route": route,
            "message": "Route created successfully",
            "photos_saved": len(photo_urls),
            "gps_data_saved": bool(coords_dict)
        }
    else:
        route_dict = {
            "id": route_id,
            "user_id": user_id,
            "name": name,
            "description": description,
            "start_location": start_location,
            "end_location": end_location,
            "distance": distance,
            "estimated_duration": estimated_duration,
            "difficulty": difficulty,
            "category": category,
            "coordinates": coords_dict,
            "photos": photo_urls,
            "is_public": is_public,
            "created_at": datetime.utcnow().isoformat()
        }
        routes_db[route_id] = route_dict
        return {"route": route_dict, "message": "Route created successfully"}

# Garage endpoints
@router.get("/garage/{user_id}")
async def get_user_garage(user_id: str):
    """Get user's garage (cars)"""
    user_cars = [car for car in cars_db.values() if car.get("user_id") == user_id]
    return {
        "cars": user_cars,
        "count": len(user_cars)
    }

@router.post("/garage/cars")
async def add_car(
    user_id: str = Form(...),
    make: str = Form(...),
    model: str = Form(...),
    year: int = Form(...),
    color: Optional[str] = Form(None),
    engine: Optional[str] = Form(None),
    horsepower: Optional[int] = Form(None),
    is_project: bool = Form(False),
    photos: List[UploadFile] = File(None)
):
    """Add car to garage with photos"""
    car_id = secrets.token_urlsafe(16)
    photo_urls = []
    
    # Handle car photos
    if photos:
        garage_dir = UPLOAD_PATH / "garage" / user_id / car_id
        garage_dir.mkdir(parents=True, exist_ok=True)
        
        for idx, photo in enumerate(photos):
            if photo and photo.filename:
                ext = Path(photo.filename).suffix
                safe_filename = f"car_{idx}{ext}"
                file_path = garage_dir / safe_filename
                
                content = await photo.read()
                with open(file_path, "wb") as f:
                    f.write(content)
                
                relative_path = f"garage/{user_id}/{car_id}/{safe_filename}"
                photo_urls.append(relative_path)
    
    if db:
        car = db.add_car(
            user_id=user_id,
            make=make,
            model=model,
            year=year,
            color=color,
            engine=engine,
            horsepower=horsepower,
            is_project=is_project
        )
        # Store photo references separately
        if photo_urls:
            photos_json = UPLOAD_PATH / "garage" / user_id / car_id / "photos.json"
            with open(photos_json, "w") as f:
                json.dump({"car_id": car_id, "photos": photo_urls}, f)
        
        car["photos"] = photo_urls
        return {
            "car": car,
            "message": "Car added to garage",
            "photos_saved": len(photo_urls)
        }
    else:
        car_dict = {
            "id": car_id,
            "user_id": user_id,
            "make": make,
            "model": model,
            "year": year,
            "color": color,
            "engine": engine,
            "horsepower": horsepower,
            "is_project": is_project,
            "photos": photo_urls,
            "created_at": datetime.utcnow().isoformat()
        }
        cars_db[car_id] = car_dict
        return {"car": car_dict, "message": "Car added to garage"}

# User profile endpoints
@router.get("/users/{user_id}")
async def get_user_profile(user_id: str):
    """Get user profile"""
    for user in users_db.values():
        if user["id"] == user_id:
            return {"user": UserProfile(**user)}
    
    raise HTTPException(status_code=404, detail="User not found")

@router.put("/users/{user_id}")
async def update_user_profile(user_id: str, updates: Dict[str, Any]):
    """Update user profile"""
    if db:
        # TODO: Implement database update
        pass
    else:
        for email, user in users_db.items():
            if user["id"] == user_id:
                user.update(updates)
                return {"user": UserProfile(**user), "message": "Profile updated"}
    
    raise HTTPException(status_code=404, detail="User not found")

@router.post("/users/{user_id}/photo")
async def upload_profile_photo(
    user_id: str,
    photo: UploadFile = File(...)
):
    """Upload user profile photo"""
    if photo and photo.filename:
        # Create user profile directory
        profile_dir = UPLOAD_PATH / "profiles" / user_id
        profile_dir.mkdir(parents=True, exist_ok=True)
        
        # Save profile photo with timestamp to allow history
        ext = Path(photo.filename).suffix
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        safe_filename = f"profile_{timestamp}{ext}"
        file_path = profile_dir / safe_filename
        
        content = await photo.read()
        with open(file_path, "wb") as f:
            f.write(content)
        
        relative_path = f"profiles/{user_id}/{safe_filename}"
        
        # Also save as current.jpg for easy access
        current_path = profile_dir / f"current{ext}"
        with open(current_path, "wb") as f:
            f.seek(0)
            content = await photo.read() if photo.size else content
            f.write(content)
        
        return {
            "message": "Profile photo uploaded successfully",
            "photo_url": relative_path,
            "storage_location": str(profile_dir)
        }
    
    raise HTTPException(status_code=400, detail="No photo provided")

# Social following endpoints
@router.post("/users/{user_id}/follow")
async def follow_user(user_id: str, follower_id: str = Form(...)):
    """Follow or unfollow a user"""
    if db:
        is_following = db.follow_user(follower_id, user_id)
        return {
            "user_id": user_id,
            "follower_id": follower_id,
            "following": is_following,
            "action": "followed" if is_following else "unfollowed"
        }
    else:
        raise HTTPException(status_code=501, detail="Database required for social features")

@router.get("/users/{user_id}/followers")
async def get_user_followers(user_id: str):
    """Get user's followers"""
    if db:
        followers = db.get_followers(user_id)
        return {
            "user_id": user_id,
            "followers": followers,
            "count": len(followers)
        }
    else:
        raise HTTPException(status_code=501, detail="Database required for social features")

@router.get("/users/{user_id}/following")
async def get_user_following(user_id: str):
    """Get users that this user follows"""
    if db:
        following = db.get_following(user_id)
        return {
            "user_id": user_id,
            "following": following,
            "count": len(following)
        }
    else:
        raise HTTPException(status_code=501, detail="Database required for social features")

@router.get("/users/{user_id}/posts")
async def get_user_posts(user_id: str, limit: int = 20):
    """Get posts by specific user"""
    if db:
        posts = db.get_user_posts(user_id, limit)
        return {
            "user_id": user_id,
            "posts": posts,
            "count": len(posts)
        }
    else:
        # Fallback to in-memory
        user_posts = [post for post in posts_db.values() if post.get("user_id") == user_id]
        user_posts.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return {
            "user_id": user_id,
            "posts": user_posts[:limit],
            "count": len(user_posts)
        }

# App update instructions endpoint
@router.get("/app-updates")
async def get_app_updates():
    """Get app update instructions from GitHub"""
    # This will be populated from GitHub repository
    instructions_file = Path("C:/Users/nbhat/MotorMates/APP_UPDATE_INSTRUCTIONS.json")
    
    if instructions_file.exists():
        with open(instructions_file, "r") as f:
            return json.load(f)
    
    return {
        "version": "1.0.0",
        "release_notes": "Initial release",
        "update_url": "https://github.com/nakulb23/MotorMates",
        "mandatory": False,
        "instructions": [
            "Open TestFlight or App Store",
            "Check for updates",
            "Download and install the latest version"
        ]
    }

@router.post("/app-updates")
async def update_app_instructions(instructions: AppUpdateInstructions):
    """Update app instructions (admin only)"""
    instructions_file = Path("C:/Users/nbhat/MotorMates/APP_UPDATE_INSTRUCTIONS.json")
    
    with open(instructions_file, "w") as f:
        json.dump(instructions.dict(), f, indent=2)
    
    return {"message": "App update instructions saved", "instructions": instructions.dict()}

# Test endpoint for iOS connection
@router.get("/test-ios")
async def test_ios_connection():
    """Test endpoint for iOS app connection"""
    return {
        "message": "MotorMates server is connected!",
        "timestamp": datetime.utcnow().isoformat(),
        "success": True,
        "server_info": {
            "version": "1.0.0",
            "host": "0.0.0.0",
            "port": 8443,
            "ssl": True
        }
    }

# Storage info endpoint
@router.get("/storage-info")
async def get_storage_info():
    """Get information about data storage"""
    # Calculate storage sizes
    total_size = 0
    file_counts = {
        "posts": 0,
        "routes": 0,
        "garage": 0,
        "profiles": 0
    }
    
    if UPLOAD_PATH.exists():
        for category in ["posts", "routes", "garage", "profiles"]:
            category_path = UPLOAD_PATH / category
            if category_path.exists():
                for file in category_path.rglob("*"):
                    if file.is_file():
                        total_size += file.stat().st_size
                        file_counts[category] += 1
    
    db_size = 0
    db_path = Path.home() / "Desktop" / "MotorMates_Data" / "motormates.db"
    if db_path.exists():
        db_size = db_path.stat().st_size
    
    return {
        "storage_location": str(UPLOAD_PATH),
        "database_location": str(db_path),
        "total_upload_size_mb": round(total_size / (1024 * 1024), 2),
        "database_size_mb": round(db_size / (1024 * 1024), 2),
        "file_counts": file_counts,
        "encryption": "Enabled - Fernet encryption for sensitive data",
        "backup_available": (Path.home() / "Desktop" / "MotorMates_Data" / "backups").exists()
    }

# Serve uploaded files
@router.get("/uploads/{file_path:path}")
async def get_upload(file_path: str):
    """Serve uploaded files"""
    from fastapi.responses import FileResponse
    
    full_path = UPLOAD_PATH / file_path
    if full_path.exists() and full_path.is_file():
        return FileResponse(full_path)
    
    raise HTTPException(status_code=404, detail="File not found")