#!/usr/bin/env python3
"""
Golf Swing AI - HTTPS Public Server
Secure SSL/TLS enabled server for production use with new backend structure
"""

import uvicorn
import os
import sys
import ssl
from pathlib import Path

# Setup paths for new backend structure
project_root = Path(__file__).parent.absolute()
backend_paths = [
    project_root / "backend",
    project_root / "backend" / "core",
    project_root / "backend" / "utils", 
    project_root / "backend" / "scripts",
    project_root / "backend" / "models"
]

for path in backend_paths:
    if path.exists() and str(path) not in sys.path:
        sys.path.insert(0, str(path))

def main():
    """Start the HTTPS server"""
    
    # SSL certificate paths
    cert_dir = project_root / "ssl_certs"
    cert_file = cert_dir / "golfai.crt"
    key_file = cert_dir / "golfai.key"
    
    # Check if SSL certificates exist
    if not cert_file.exists() or not key_file.exists():
        print("SSL certificates not found!")
        print("Run: python generate_ssl.py")
        return
    
    # HTTPS Configuration
    config = {
        "app": "api:app",
        "host": "0.0.0.0",  # Bind to all interfaces
        "port": 8443,       # Back to working port
        "ssl_keyfile": str(key_file),
        "ssl_certfile": str(cert_file),
        "ssl_version": ssl.PROTOCOL_TLSv1_2,
        "reload": False,    # Disable reload for production
        "workers": 1,       # Single worker for model consistency
        "log_level": "debug",
        "access_log": True,
        "use_colors": True,
    }
    
    print("Starting Golf Swing AI HTTPS Server...")
    print(f"Local HTTPS: https://localhost:8443")
    print(f"Network HTTPS: https://192.168.4.172:8443")
    print(f"Public HTTPS: https://golfai.duckdns.org:8443")
    print("SSL/TLS encryption enabled!")
    print("Self-signed certificate - browsers will show warnings")
    print("-" * 60)
    
    # Start the HTTPS server
    uvicorn.run(**config)

if __name__ == "__main__":
    main()