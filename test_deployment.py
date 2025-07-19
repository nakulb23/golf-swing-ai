#!/usr/bin/env python3
"""
Test script for deployed Golf Swing AI API
Use this to verify your Railway deployment is working
"""

import requests
import json
import sys

def test_deployed_api(base_url):
    """Test all endpoints of the deployed API"""
    
    print(f"🧪 Testing Deployed Golf Swing AI API")
    print(f"🌐 Base URL: {base_url}")
    print("="*60)
    
    # Test 1: Root endpoint
    print("\n1️⃣ Testing Root Endpoint")
    try:
        response = requests.get(f"{base_url}/")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Root endpoint working")
            print(f"   Version: {data.get('version')}")
            print(f"   Features: {len(data.get('features', {}))}")
        else:
            print(f"❌ Root endpoint failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Root endpoint error: {str(e)}")
    
    # Test 2: Health check
    print("\n2️⃣ Testing Health Check")
    try:
        response = requests.get(f"{base_url}/health")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Health check passed")
            print(f"   Status: {data.get('status')}")
        else:
            print(f"❌ Health check failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Health check error: {str(e)}")
    
    # Test 3: CaddieChat
    print("\n3️⃣ Testing CaddieChat")
    try:
        chat_data = {"question": "Who won the 2024 Masters?"}
        response = requests.post(
            f"{base_url}/chat",
            json=chat_data,
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ CaddieChat working")
            print(f"   Golf-related: {data.get('is_golf_related')}")
            print(f"   Answer: {data.get('answer')[:100]}...")
        else:
            print(f"❌ CaddieChat failed: {response.status_code}")
            print(f"   Response: {response.text}")
    except Exception as e:
        print(f"❌ CaddieChat error: {str(e)}")
    
    # Test 4: API Documentation
    print("\n4️⃣ Testing API Documentation")
    try:
        response = requests.get(f"{base_url}/docs")
        if response.status_code == 200:
            print(f"✅ API docs available at {base_url}/docs")
        else:
            print(f"❌ API docs failed: {response.status_code}")
    except Exception as e:
        print(f"❌ API docs error: {str(e)}")
    
    # Test 5: OpenAPI spec
    print("\n5️⃣ Testing OpenAPI Specification")
    try:
        response = requests.get(f"{base_url}/openapi.json")
        if response.status_code == 200:
            spec = response.json()
            print(f"✅ OpenAPI spec available")
            print(f"   Endpoints: {len(spec.get('paths', {}))}")
        else:
            print(f"❌ OpenAPI spec failed: {response.status_code}")
    except Exception as e:
        print(f"❌ OpenAPI spec error: {str(e)}")
    
    print("\n" + "="*60)
    print("🎯 DEPLOYMENT TEST SUMMARY")
    print("="*60)
    print(f"📡 API Base URL: {base_url}")
    print(f"📚 Documentation: {base_url}/docs")
    print(f"🔄 Health Check: {base_url}/health")
    print(f"🏌️ Ready for iOS app integration!")

def main():
    """Main test function"""
    
    if len(sys.argv) != 2:
        print("Usage: python3 test_deployment.py <API_URL>")
        print("Example: python3 test_deployment.py https://your-app.railway.app")
        sys.exit(1)
    
    api_url = sys.argv[1].rstrip('/')
    test_deployed_api(api_url)

if __name__ == "__main__":
    main()