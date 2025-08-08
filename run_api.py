#!/usr/bin/env python3
"""
Golf Swing AI - Main API Launcher
Handles path setup and launches the FastAPI service with organized folder structure
"""

import os
import sys
from pathlib import Path

def setup_paths():
    """Setup Python paths for organized project structure"""
    
    # Get the project root directory
    project_root = Path(__file__).parent.absolute()
    
    # Add backend directories to Python path
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
    
    # Set working directory to project root
    os.chdir(project_root)
    
    print("🚀 Golf Swing AI - Enhanced LSTM System")
    print("=" * 50)
    print(f"📁 Project Root: {project_root}")
    print(f"🐍 Python Path: {len(sys.path)} directories")
    print(f"🧠 Backend Structure: Organized")
    
    return project_root

def main():
    """Main function to launch the API"""
    
    # Setup organized paths
    project_root = setup_paths()
    
    try:
        # Import and run the API from the organized structure
        print("📡 Starting FastAPI server...")
        
        # Import the API module from backend/core
        from api import app
        
        # Launch with uvicorn
        import uvicorn
        
        port = int(os.environ.get("PORT", 8000))
        host = os.environ.get("HOST", "0.0.0.0")
        
        print(f"🌐 Server starting on http://{host}:{port}")
        print("📚 API Documentation: http://localhost:8000/docs")
        print("🎯 Endpoints available:")
        print("   • POST /predict - Enhanced LSTM swing analysis")
        print("   • POST /submit-corrected-prediction - User training data")
        print("   • GET /model-training-status - Training progress")
        print("   • POST /chat - CaddieChat Q&A")
        print("   • POST /track-ball - Ball tracking analysis")
        
        uvicorn.run(app, host=host, port=port)
        
    except ImportError as e:
        print(f"❌ Import Error: {e}")
        print("💡 Make sure all Python files are in the correct organized structure")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Startup Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()