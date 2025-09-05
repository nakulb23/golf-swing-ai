#!/usr/bin/env python3
"""
Golf Swing AI - HTTPS Server with Let's Encrypt Certificate
Uses certificate from Windows Certificate Store
"""

import uvicorn
import ssl
import sys
from pathlib import Path

# Add current directory to path
sys.path.append(str(Path(__file__).parent))

def main():
    """Start the HTTPS server with Let's Encrypt certificate"""
    
    print("Starting Golf Swing AI HTTPS Server with Let's Encrypt Certificate...")
    print(f"HTTPS URL: https://golfai.duckdns.org:8443")
    print("Real SSL certificate - no browser warnings!")
    print("-" * 60)
    
    # HTTPS Configuration using system certificate store
    config = {
        "app": "api:app",
        "host": "0.0.0.0",  # Bind to all interfaces
        "port": 8443,       # HTTPS port
        # Let uvicorn use the system certificate store
        "ssl": True,
        "ssl_version": ssl.PROTOCOL_TLS_SERVER,
        "reload": False,    # Disable reload for production
        "workers": 1,       # Single worker for model consistency
        "log_level": "info",
        "access_log": True,
    }
    
    try:
        # Start the HTTPS server
        uvicorn.run(**config)
    except Exception as e:
        print(f"Error starting HTTPS server: {e}")
        print("Falling back to certificate files...")
        
        # Fallback to file-based certificates
        cert_dir = Path("ssl_certs")
        cert_file = cert_dir / "server.crt"
        key_file = cert_dir / "server.key"
        
        if cert_file.exists() and key_file.exists():
            config_fallback = {
                "app": "api:app",
                "host": "0.0.0.0",
                "port": 8443,
                "ssl_keyfile": str(key_file),
                "ssl_certfile": str(cert_file),
                "ssl_version": ssl.PROTOCOL_TLSv1_2,
                "reload": False,
                "workers": 1,
                "log_level": "info",
                "access_log": True,
            }
            uvicorn.run(**config_fallback)
        else:
            print("No SSL certificates found!")
            return

if __name__ == "__main__":
    main()