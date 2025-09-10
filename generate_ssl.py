#!/usr/bin/env python3
"""
SSL Certificate Generator for Golf Swing AI
Creates self-signed certificates for HTTPS
"""

import os
import subprocess
import sys
from pathlib import Path

def generate_self_signed_cert():
    """Generate self-signed SSL certificate"""
    
    cert_dir = Path("ssl_certs")
    cert_dir.mkdir(exist_ok=True)
    
    cert_file = cert_dir / "server.crt"
    key_file = cert_dir / "server.key"
    
    # Certificate configuration
    config_content = f"""[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Golf Swing AI
OU = IT Department
CN = 24.130.129.186

[v3_req]
keyUsage = critical, digitalSignature, keyAgreement
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = 24.130.129.186
IP.2 = 192.168.4.172
IP.3 = 127.0.0.1
DNS.1 = localhost
"""
    
    config_file = cert_dir / "ssl.conf"
    with open(config_file, 'w') as f:
        f.write(config_content)
    
    print("Generating SSL certificate...")
    
    # Generate private key and certificate
    cmd = [
        "openssl", "req", "-x509", "-nodes", "-days", "365",
        "-newkey", "rsa:2048",
        "-keyout", str(key_file),
        "-out", str(cert_file),
        "-config", str(config_file)
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print("SSL certificate generated successfully!")
        print(f"Certificate: {cert_file}")
        print(f"Private Key: {key_file}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error generating certificate: {e}")
        print(f"Error output: {e.stderr}")
        return False
    except FileNotFoundError:
        print("OpenSSL not found. Please install OpenSSL.")
        print("Download from: https://slproweb.com/products/Win32OpenSSL.html")
        return False

def main():
    print("Golf Swing AI - SSL Certificate Generator")
    print("=" * 50)
    
    if generate_self_signed_cert():
        print("\nSSL setup complete!")
        print("Next steps:")
        print("1. Run: python server_https.py")
        print("2. Access: https://24.130.129.186:8443")
        print("3. Accept the self-signed certificate warning in browser")
        print("\nNote: Self-signed certificates show security warnings")
        print("For production, consider getting a proper SSL certificate")
    else:
        print("\nSSL setup failed. Check the error messages above.")

if __name__ == "__main__":
    main()