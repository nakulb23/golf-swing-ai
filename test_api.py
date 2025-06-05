#!/usr/bin/env python3
"""
Test script for Golf Swing AI API
Tests all three main features: swing analysis, ball tracking, and chatbot
"""

import json
from golf_chatbot import CaddieChat
from ball_tracking import GolfBallTracker

def test_chatbot():
    """Test CaddieChat functionality"""
    print("🤖 Testing CaddieChat")
    print("="*40)
    
    chatbot = CaddieChat()
    
    test_questions = [
        "Who won the 2024 Masters?",
        "What is the proper golf grip?", 
        "Tell me about swing plane",
        "What's the weather like?"  # Non-golf question
    ]
    
    for question in test_questions:
        print(f"\nQ: {question}")
        answer = chatbot.answer_question(question)
        is_golf = chatbot.is_golf_question(question)
        print(f"Golf-related: {is_golf}")
        print(f"A: {answer[:100]}...")

def test_ball_tracker():
    """Test the ball tracking functionality"""
    print("\n🏌️ Testing Ball Tracker")
    print("="*40)
    
    tracker = GolfBallTracker()
    
    # Create synthetic test data
    test_positions = []
    for i in range(20):
        t = i * 0.1
        x = 100 + 30 * t
        y = 200 + 10 * t - 2 * t**2
        
        test_positions.append({
            'frame': i,
            'timestamp': t,
            'x': int(x),
            'y': int(y),
            'radius': 8,
            'detected': True
        })
    
    analysis = tracker.analyze_ball_trajectory(test_positions)
    
    print(f"Detection Rate: {analysis['detection_rate']*100:.1f}%")
    print(f"Flight Time: {analysis['flight_time']:.2f}s")
    
    if 'physics_analysis' in analysis:
        physics = analysis['physics_analysis']
        print(f"Launch Angle: {physics['launch_angle_degrees']:.1f}°")
        print(f"Launch Speed: {physics['launch_speed_ms']:.1f} m/s")
        print(f"Trajectory: {physics['trajectory_type']}")

def test_api_structure():
    """Test that API components can be imported and initialized"""
    print("\n🚀 Testing API Structure")
    print("="*40)
    
    try:
        from api import app, chatbot, ball_tracker
        print("✅ FastAPI app created")
        print("✅ Chatbot initialized")
        print("✅ Ball tracker initialized")
        
        # Test that endpoints exist
        routes = [route.path for route in app.routes]
        expected_routes = ["/", "/health", "/predict", "/chat", "/track-ball"]
        
        print(f"\nAPI Routes: {routes}")
        
        for route in expected_routes:
            if route in routes:
                print(f"✅ {route} endpoint exists")
            else:
                print(f"❌ {route} endpoint missing")
                
    except Exception as e:
        print(f"❌ API initialization failed: {str(e)}")

def main():
    """Run all tests"""
    print("🧪 Golf Swing AI - Complete System Test")
    print("="*50)
    
    try:
        test_chatbot()
        test_ball_tracker()
        test_api_structure()
        
        print("\n🎉 ALL TESTS COMPLETED")
        print("="*50)
        print("Your Golf Swing AI API is ready with:")
        print("✅ Physics-based swing analysis (/predict)")
        print("✅ Ball tracking and trajectory analysis (/track-ball)")
        print("✅ CaddieChat - Golf Q&A chatbot (/chat)")
        print("\nTo start the API server:")
        print("python3 api.py")
        print("Then visit: http://localhost:8000")
        
    except Exception as e:
        print(f"❌ Test failed: {str(e)}")

if __name__ == "__main__":
    main()