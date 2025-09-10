"""
MotorMates Database Manager
Secure SQLite database with encryption for user data storage
Completely separate from GolfSwingAI data
"""

import sqlite3
import json
import os
from pathlib import Path
from datetime import datetime
import hashlib
import secrets
from cryptography.fernet import Fernet
from typing import Dict, List, Optional, Any
import base64

class MotorMatesDB:
    def __init__(self, db_path: str = None):
        """Initialize MotorMates database with encryption"""
        # Create separate MotorMates data directory on desktop
        if db_path is None:
            desktop = Path.home() / "Desktop" / "MotorMates_Data"
            desktop.mkdir(parents=True, exist_ok=True)
            self.db_path = desktop / "motormates.db"
        else:
            self.db_path = Path(db_path)
        
        # Generate or load encryption key
        self.key_file = self.db_path.parent / ".motormates.key"
        self.cipher = self._get_cipher()
        
        # Initialize database
        self.conn = sqlite3.connect(str(self.db_path))
        self.conn.row_factory = sqlite3.Row
        self._create_tables()
        
        print(f"MotorMates database initialized at: {self.db_path}")
        print(f"This is completely separate from GolfSwingAI data")
    
    def _get_cipher(self) -> Fernet:
        """Get or create encryption cipher"""
        if self.key_file.exists():
            with open(self.key_file, 'rb') as f:
                key = f.read()
        else:
            key = Fernet.generate_key()
            with open(self.key_file, 'wb') as f:
                f.write(key)
            # Hide the key file on Windows
            if os.name == 'nt':
                import ctypes
                FILE_ATTRIBUTE_HIDDEN = 0x02
                ctypes.windll.kernel32.SetFileAttributesW(str(self.key_file), FILE_ATTRIBUTE_HIDDEN)
        
        return Fernet(key)
    
    def _encrypt(self, data: str) -> str:
        """Encrypt sensitive data"""
        if data is None:
            return None
        return self.cipher.encrypt(data.encode()).decode()
    
    def _decrypt(self, data: str) -> str:
        """Decrypt sensitive data"""
        if data is None:
            return None
        return self.cipher.decrypt(data.encode()).decode()
    
    def _hash_password(self, password: str) -> str:
        """Hash password with salt"""
        salt = secrets.token_hex(16)
        hashed = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
        return f"{salt}${base64.b64encode(hashed).decode()}"
    
    def _verify_password(self, password: str, hashed: str) -> bool:
        """Verify password against hash"""
        try:
            salt, hash_b64 = hashed.split('$')
            expected = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
            return base64.b64encode(expected).decode() == hash_b64
        except:
            return False
    
    def _create_tables(self):
        """Create database tables if they don't exist"""
        cursor = self.conn.cursor()
        
        # Users table with encrypted sensitive data
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                email TEXT UNIQUE NOT NULL,
                email_encrypted TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                name TEXT NOT NULL,
                city TEXT,
                state TEXT,
                country TEXT,
                profile_photo_url TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT
            )
        ''')
        
        # Sessions table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS sessions (
                token TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        # Posts table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS posts (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                caption TEXT NOT NULL,
                location TEXT,
                image_urls TEXT,
                tags TEXT,
                likes_count INTEGER DEFAULT 0,
                comments_count INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        # Routes table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS routes (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                name TEXT NOT NULL,
                description TEXT,
                start_location TEXT,
                end_location TEXT,
                distance REAL,
                estimated_duration INTEGER,
                difficulty TEXT,
                category TEXT,
                coordinates TEXT,
                photos TEXT,
                is_public INTEGER DEFAULT 1,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        # Cars table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS cars (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                make TEXT NOT NULL,
                model TEXT NOT NULL,
                year INTEGER NOT NULL,
                color TEXT,
                engine TEXT,
                horsepower INTEGER,
                is_project INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        # Comments table for posts
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS comments (
                id TEXT PRIMARY KEY,
                post_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        # Likes table for posts
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS likes (
                id TEXT PRIMARY KEY,
                post_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(post_id, user_id),
                FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ''')
        
        # Follows table for user relationships
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS follows (
                id TEXT PRIMARY KEY,
                follower_id TEXT NOT NULL,
                following_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(follower_id, following_id),
                FOREIGN KEY (follower_id) REFERENCES users(id),
                FOREIGN KEY (following_id) REFERENCES users(id)
            )
        ''')
        
        self.conn.commit()
    
    # User Management
    def create_user(self, email: str, password: str, name: str, **kwargs) -> Dict:
        """Create new user with encrypted email"""
        cursor = self.conn.cursor()
        user_id = secrets.token_urlsafe(16)
        
        # Encrypt sensitive data
        email_encrypted = self._encrypt(email)
        password_hash = self._hash_password(password)
        
        try:
            cursor.execute('''
                INSERT INTO users (id, email, email_encrypted, password_hash, name, city, state, country, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                user_id, 
                email,  # Store plain for uniqueness check
                email_encrypted,  # Store encrypted version
                password_hash, 
                name,
                kwargs.get('city'),
                kwargs.get('state'),
                kwargs.get('country'),
                datetime.utcnow().isoformat()
            ))
            self.conn.commit()
            
            return {
                'id': user_id,
                'email': email,
                'name': name,
                'city': kwargs.get('city'),
                'state': kwargs.get('state'),
                'country': kwargs.get('country'),
                'created_at': datetime.utcnow().isoformat()
            }
        except sqlite3.IntegrityError:
            raise ValueError("Email already exists")
    
    def authenticate_user(self, email: str, password: str) -> Optional[Dict]:
        """Authenticate user and return user data"""
        cursor = self.conn.cursor()
        cursor.execute('SELECT * FROM users WHERE email = ?', (email,))
        user = cursor.fetchone()
        
        if user and self._verify_password(password, user['password_hash']):
            return {
                'id': user['id'],
                'email': email,
                'name': user['name'],
                'city': user['city'],
                'state': user['state'],
                'country': user['country'],
                'profile_photo_url': user['profile_photo_url'],
                'created_at': user['created_at']
            }
        return None
    
    def create_session(self, user_id: str) -> str:
        """Create new session token"""
        cursor = self.conn.cursor()
        token = secrets.token_urlsafe(32)
        
        cursor.execute('''
            INSERT INTO sessions (token, user_id, created_at, expires_at)
            VALUES (?, ?, ?, datetime('now', '+7 days'))
        ''', (token, user_id, datetime.utcnow().isoformat()))
        
        self.conn.commit()
        return token
    
    def get_user_by_token(self, token: str) -> Optional[Dict]:
        """Get user by session token"""
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT u.* FROM users u
            JOIN sessions s ON u.id = s.user_id
            WHERE s.token = ? AND s.expires_at > datetime('now')
        ''', (token,))
        
        user = cursor.fetchone()
        if user:
            return {
                'id': user['id'],
                'email': user['email'],
                'name': user['name'],
                'city': user['city'],
                'state': user['state'],
                'country': user['country'],
                'profile_photo_url': user['profile_photo_url'],
                'created_at': user['created_at']
            }
        return None
    
    # Posts Management
    def create_post(self, user_id: str, caption: str, **kwargs) -> Dict:
        """Create new post"""
        cursor = self.conn.cursor()
        post_id = secrets.token_urlsafe(16)
        
        image_urls = json.dumps(kwargs.get('image_urls', []))
        tags = json.dumps(kwargs.get('tags', []))
        
        cursor.execute('''
            INSERT INTO posts (id, user_id, caption, location, image_urls, tags, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            post_id, user_id, caption, kwargs.get('location'),
            image_urls, tags, datetime.utcnow().isoformat()
        ))
        
        self.conn.commit()
        return {
            'id': post_id,
            'user_id': user_id,
            'caption': caption,
            'location': kwargs.get('location'),
            'image_urls': kwargs.get('image_urls', []),
            'tags': kwargs.get('tags', []),
            'created_at': datetime.utcnow().isoformat()
        }
    
    def get_posts_feed(self, limit: int = 20, user_id: str = None) -> List[Dict]:
        """Get posts for feed with engagement data"""
        cursor = self.conn.cursor()
        
        # Get posts with actual like/comment counts
        cursor.execute('''
            SELECT p.*, u.name as user_name, u.profile_photo_url,
                   COUNT(DISTINCT l.id) as actual_likes_count,
                   COUNT(DISTINCT c.id) as actual_comments_count
            FROM posts p
            JOIN users u ON p.user_id = u.id
            LEFT JOIN likes l ON p.id = l.post_id
            LEFT JOIN comments c ON p.id = c.post_id
            GROUP BY p.id, u.id, u.name, u.profile_photo_url
            ORDER BY p.created_at DESC
            LIMIT ?
        ''', (limit,))
        
        posts = []
        for row in cursor.fetchall():
            post_data = {
                'id': row['id'],
                'user_id': row['user_id'],
                'user_name': row['user_name'],
                'user_photo': row['profile_photo_url'],
                'caption': row['caption'],
                'location': row['location'],
                'image_urls': json.loads(row['image_urls']) if row['image_urls'] else [],
                'tags': json.loads(row['tags']) if row['tags'] else [],
                'likes_count': row['actual_likes_count'],
                'comments_count': row['actual_comments_count'],
                'created_at': row['created_at']
            }
            
            # Check if current user liked this post
            if user_id:
                cursor.execute('SELECT 1 FROM likes WHERE post_id = ? AND user_id = ?', 
                             (row['id'], user_id))
                post_data['liked_by_user'] = cursor.fetchone() is not None
            else:
                post_data['liked_by_user'] = False
                
            posts.append(post_data)
        return posts
    
    # Routes Management
    def create_route(self, user_id: str, name: str, **kwargs) -> Dict:
        """Create new driving route"""
        cursor = self.conn.cursor()
        route_id = secrets.token_urlsafe(16)
        
        coordinates = json.dumps(kwargs.get('coordinates', {}))
        photos = json.dumps(kwargs.get('photos', []))
        
        cursor.execute('''
            INSERT INTO routes (id, user_id, name, description, start_location, end_location,
                              distance, estimated_duration, difficulty, category, coordinates,
                              photos, is_public, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            route_id, user_id, name, kwargs.get('description'),
            kwargs.get('start_location'), kwargs.get('end_location'),
            kwargs.get('distance'), kwargs.get('estimated_duration'),
            kwargs.get('difficulty'), kwargs.get('category'),
            coordinates, photos, int(kwargs.get('is_public', True)),
            datetime.utcnow().isoformat()
        ))
        
        self.conn.commit()
        return {'id': route_id, 'name': name, 'user_id': user_id}
    
    def get_public_routes(self, limit: int = 20) -> List[Dict]:
        """Get public routes"""
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT * FROM routes WHERE is_public = 1
            ORDER BY created_at DESC LIMIT ?
        ''', (limit,))
        
        routes = []
        for row in cursor.fetchall():
            routes.append(dict(row))
        return routes
    
    # Cars Management
    def add_car(self, user_id: str, make: str, model: str, year: int, **kwargs) -> Dict:
        """Add car to user's garage"""
        cursor = self.conn.cursor()
        car_id = secrets.token_urlsafe(16)
        
        cursor.execute('''
            INSERT INTO cars (id, user_id, make, model, year, color, engine, horsepower, is_project, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            car_id, user_id, make, model, year,
            kwargs.get('color'), kwargs.get('engine'),
            kwargs.get('horsepower'), int(kwargs.get('is_project', False)),
            datetime.utcnow().isoformat()
        ))
        
        self.conn.commit()
        return {'id': car_id, 'make': make, 'model': model, 'year': year}
    
    def get_user_garage(self, user_id: str) -> List[Dict]:
        """Get user's cars"""
        cursor = self.conn.cursor()
        cursor.execute('SELECT * FROM cars WHERE user_id = ?', (user_id,))
        return [dict(row) for row in cursor.fetchall()]
    
    # Social Media Features
    def like_post(self, post_id: str, user_id: str) -> bool:
        """Like or unlike a post"""
        cursor = self.conn.cursor()
        
        # Check if already liked
        cursor.execute('SELECT id FROM likes WHERE post_id = ? AND user_id = ?', 
                      (post_id, user_id))
        existing = cursor.fetchone()
        
        if existing:
            # Unlike the post
            cursor.execute('DELETE FROM likes WHERE post_id = ? AND user_id = ?', 
                          (post_id, user_id))
            action = "unliked"
        else:
            # Like the post
            like_id = secrets.token_urlsafe(16)
            cursor.execute('''
                INSERT INTO likes (id, post_id, user_id, created_at)
                VALUES (?, ?, ?, ?)
            ''', (like_id, post_id, user_id, datetime.utcnow().isoformat()))
            action = "liked"
        
        self.conn.commit()
        return action == "liked"
    
    def add_comment(self, post_id: str, user_id: str, content: str) -> Dict:
        """Add comment to a post"""
        cursor = self.conn.cursor()
        comment_id = secrets.token_urlsafe(16)
        
        cursor.execute('''
            INSERT INTO comments (id, post_id, user_id, content, created_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (comment_id, post_id, user_id, content, datetime.utcnow().isoformat()))
        
        self.conn.commit()
        
        # Return comment with user info
        cursor.execute('''
            SELECT c.*, u.name as user_name FROM comments c
            JOIN users u ON c.user_id = u.id
            WHERE c.id = ?
        ''', (comment_id,))
        
        row = cursor.fetchone()
        return {
            'id': row['id'],
            'post_id': row['post_id'],
            'user_id': row['user_id'],
            'user_name': row['user_name'],
            'content': row['content'],
            'created_at': row['created_at']
        }
    
    def get_post_comments(self, post_id: str, limit: int = 50) -> List[Dict]:
        """Get comments for a post"""
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT c.*, u.name as user_name FROM comments c
            JOIN users u ON c.user_id = u.id
            WHERE c.post_id = ?
            ORDER BY c.created_at ASC
            LIMIT ?
        ''', (post_id, limit))
        
        comments = []
        for row in cursor.fetchall():
            comments.append({
                'id': row['id'],
                'user_id': row['user_id'],
                'user_name': row['user_name'],
                'content': row['content'],
                'created_at': row['created_at']
            })
        return comments
    
    def follow_user(self, follower_id: str, following_id: str) -> bool:
        """Follow or unfollow a user"""
        cursor = self.conn.cursor()
        
        # Check if already following
        cursor.execute('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', 
                      (follower_id, following_id))
        existing = cursor.fetchone()
        
        if existing:
            # Unfollow
            cursor.execute('DELETE FROM follows WHERE follower_id = ? AND following_id = ?', 
                          (follower_id, following_id))
            action = "unfollowed"
        else:
            # Follow
            follow_id = secrets.token_urlsafe(16)
            cursor.execute('''
                INSERT INTO follows (id, follower_id, following_id, created_at)
                VALUES (?, ?, ?, ?)
            ''', (follow_id, follower_id, following_id, datetime.utcnow().isoformat()))
            action = "followed"
        
        self.conn.commit()
        return action == "followed"
    
    def get_followers(self, user_id: str) -> List[Dict]:
        """Get user's followers"""
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT u.id, u.name FROM follows f
            JOIN users u ON f.follower_id = u.id
            WHERE f.following_id = ?
            ORDER BY f.created_at DESC
        ''', (user_id,))
        
        return [dict(row) for row in cursor.fetchall()]
    
    def get_following(self, user_id: str) -> List[Dict]:
        """Get users that this user follows"""
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT u.id, u.name FROM follows f
            JOIN users u ON f.following_id = u.id
            WHERE f.follower_id = ?
            ORDER BY f.created_at DESC
        ''', (user_id,))
        
        return [dict(row) for row in cursor.fetchall()]
    
    def get_user_posts(self, user_id: str, limit: int = 20) -> List[Dict]:
        """Get posts by specific user"""
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT p.*, u.name as user_name,
                   COUNT(DISTINCT l.id) as likes_count,
                   COUNT(DISTINCT c.id) as comments_count
            FROM posts p
            JOIN users u ON p.user_id = u.id
            LEFT JOIN likes l ON p.id = l.post_id
            LEFT JOIN comments c ON p.id = c.post_id
            WHERE p.user_id = ?
            GROUP BY p.id, u.name
            ORDER BY p.created_at DESC
            LIMIT ?
        ''', (user_id, limit))
        
        posts = []
        for row in cursor.fetchall():
            posts.append({
                'id': row['id'],
                'user_id': row['user_id'],
                'user_name': row['user_name'],
                'caption': row['caption'],
                'location': row['location'],
                'image_urls': json.loads(row['image_urls']) if row['image_urls'] else [],
                'tags': json.loads(row['tags']) if row['tags'] else [],
                'likes_count': row['likes_count'],
                'comments_count': row['comments_count'],
                'created_at': row['created_at']
            })
        return posts
    
    def close(self):
        """Close database connection"""
        self.conn.close()
    
    def backup(self):
        """Create encrypted backup of database"""
        backup_dir = self.db_path.parent / "backups"
        backup_dir.mkdir(exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = backup_dir / f"motormates_backup_{timestamp}.db"
        
        # Create backup
        with sqlite3.connect(str(backup_file)) as backup_conn:
            self.conn.backup(backup_conn)
        
        print(f"Backup created: {backup_file}")
        return backup_file

# Singleton instance
_db_instance = None

def get_db() -> MotorMatesDB:
    """Get or create database instance"""
    global _db_instance
    if _db_instance is None:
        _db_instance = MotorMatesDB()
    return _db_instance