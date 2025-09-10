#!/usr/bin/env python3
"""
Minimal test server to debug the 500 error
"""

from fastapi import FastAPI
from fastapi.responses import JSONResponse
import uvicorn
import ssl
from pathlib import Path

# Simple FastAPI app
test_app = FastAPI(title="Test Golf Swing AI")

@test_app.get("/health")
async def health_check():
    return {"status": "healthy", "test": True}

@test_app.get("/")
async def root():
    return {"message": "Test server working", "version": "test"}

def main():
    """Start the test HTTPS server"""
    
    # SSL certificate paths
    cert_dir = Path("ssl_certs")
    cert_file = cert_dir / "golfai.crt"
    key_file = cert_dir / "golfai.key"
    
    # Check if SSL certificates exist
    if not cert_file.exists() or not key_file.exists():
        print("SSL certificates not found!")
        return
    
    # HTTPS Configuration
    config = {
        "app": "test_server:test_app",
        "host": "0.0.0.0",
        "port": 8444,  # Different port
        "ssl_keyfile": str(key_file),
        "ssl_certfile": str(cert_file),
        "ssl_version": ssl.PROTOCOL_TLSv1_2,
        "reload": False,
        "workers": 1,
        "log_level": "info",
        "access_log": True,
    }
    
    print("Starting Test HTTPS Server...")
    print(f"Test URL: https://localhost:8444")
    print("-" * 40)
    
    # Start the test server
    uvicorn.run(**config)

if __name__ == "__main__":
    main()