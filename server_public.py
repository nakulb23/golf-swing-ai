#!/usr/bin/env python3
"""
Golf Swing AI - Public Server
Configured for external access and production use
"""

import uvicorn
import os
import sys
from pathlib import Path

# Add current directory to path
sys.path.append(str(Path(__file__).parent))

def main():
    """Start the public server"""
    
    # Configuration for public access
    config = {
        "app": "api:app",
        "host": "0.0.0.0",  # Bind to all interfaces for external access
        "port": 8001,
        "reload": False,    # Disable reload for production
        "workers": 1,       # Single worker for GPU/model consistency
        "log_level": "info",
        "access_log": True,
    }
    
    print("Starting Golf Swing AI Public Server...")
    print(f"Local Access: http://localhost:8001")
    print(f"Network Access: http://192.168.4.172:8001")
    print(f"External Access: http://24.130.129.186:8001")
    print("Server will use your powerful GPU for optimal performance!")
    print("Remember to set up port forwarding and firewall rules")
    print("-" * 60)
    
    # Start the server
    uvicorn.run(**config)

if __name__ == "__main__":
    main()