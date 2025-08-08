#!/usr/bin/env python3
"""
Fix Xcode Project Paths After Reorganization
Updates the project.pbxproj file to use the new organized structure
"""

import os
import re
from pathlib import Path

def fix_xcode_project():
    """Fix Xcode project file paths after reorganization"""
    
    print("🔧 Fixing Xcode project paths...")
    
    # Define the project file path
    project_root = Path("/Users/nakulbhatnagar/Desktop/Golf Swing AI")
    project_file = project_root / "frontend/ios/Golf Swing AI.xcodeproj/project.pbxproj"
    
    if not project_file.exists():
        print(f"❌ Project file not found: {project_file}")
        return False
    
    try:
        # Read the project file
        with open(project_file, 'r') as f:
            content = f.read()
        
        # Create backup
        backup_file = project_file.with_suffix('.pbxproj.backup')
        with open(backup_file, 'w') as f:
            f.write(content)
        print(f"✅ Created backup: {backup_file.name}")
        
        # Update file paths for the new structure
        path_mappings = {
            # Views
            r'path = "Views/([^"]+)";': r'path = "Views/\1";',
            r'path = "([^"/]*View\.swift)";': r'path = "Views/\1";',
            
            # Services  
            r'path = "Services/([^"]+)";': r'path = "Services/\1";',
            r'path = "([^"/]*Service\.swift)";': r'path = "Services/\1";',
            r'path = "([^"/]*Manager\.swift)";': r'path = "Services/\1";',
            
            # Models
            r'path = "Models/([^"]+)";': r'path = "Models/\1";',
            r'path = "([^"/]*Models\.swift)";': r'path = "Models/\1";',
            r'path = "([^"/]*Calculator\.swift)";': r'path = "Models/\1";',
            
            # Utilities
            r'path = "Utilities/([^"]+)";': r'path = "Utilities/\1";',
            r'path = "([^"/]*Theme\.swift)";': r'path = "Utilities/\1";',
            r'path = "(Constants\.swift)";': r'path = "Utilities/\1";',
            r'path = "(Logger\.swift)";': r'path = "Utilities/\1";',
            
            # Main app files (in Golf Swing AI folder)
            r'path = "([^"/]*App\.swift)";': r'path = "Golf Swing AI/\1";',
            r'path = "(ContentView\.swift)";': r'path = "Golf Swing AI/\1";',
            r'path = "(AuthenticationManager\.swift)";': r'path = "Golf Swing AI/\1";',
            r'path = "(ThemeManager\.swift)";': r'path = "Golf Swing AI/\1";',
            r'path = "(UserModels\.swift)";': r'path = "Golf Swing AI/\1";',
            r'path = "(SettingsView\.swift)";': r'path = "Golf Swing AI/\1";',
            r'path = "(LoginView\.swift)";': r'path = "Golf Swing AI/\1";',
            r'path = "([^"/]*Registration.*\.swift)";': r'path = "Golf Swing AI/\1";',
            r'path = "([^"/]*Progress.*\.swift)";': r'path = "Golf Swing AI/\1";',
        }
        
        # Apply path updates
        updated_content = content
        changes_made = 0
        
        for pattern, replacement in path_mappings.items():
            old_content = updated_content
            updated_content = re.sub(pattern, replacement, updated_content)
            if updated_content != old_content:
                changes_made += 1
                print(f"✅ Applied path mapping: {pattern}")
        
        # Special fixes for specific files that might be referenced incorrectly
        specific_fixes = [
            # Ensure Views are in the Views folder
            ('path = "SwingAnalysisView.swift";', 'path = "Views/SwingAnalysisView.swift";'),
            ('path = "HomeView.swift";', 'path = "Views/HomeView.swift";'),
            ('path = "BallTrackingView.swift";', 'path = "Views/BallTrackingView.swift";'),
            ('path = "CaddieChatView.swift";', 'path = "Views/CaddieChatView.swift";'),
            ('path = "PhysicsEngineView.swift";', 'path = "Views/PhysicsEngineView.swift";'),
            
            # Ensure Services are in Services folder
            ('path = "API Service.swift";', 'path = "Services/API Service.swift";'),
            ('path = "CameraManager.swift";', 'path = "Services/CameraManager.swift";'),
            ('path = "PremiumManager.swift";', 'path = "Services/PremiumManager.swift";'),
            
            # Ensure Models are in Models folder (or backend/models)
            ('path = "APIModels.swift";', 'path = "Models/APIModels.swift";'),
            ('path = "PhysicsCalculator.swift";', 'path = "Models/PhysicsCalculator.swift";'),
        ]
        
        for old_path, new_path in specific_fixes:
            if old_path in updated_content:
                updated_content = updated_content.replace(old_path, new_path)
                changes_made += 1
                print(f"✅ Fixed specific path: {old_path} -> {new_path}")
        
        # Write the updated project file
        if changes_made > 0:
            with open(project_file, 'w') as f:
                f.write(updated_content)
            print(f"✅ Updated project file with {changes_made} changes")
        else:
            print("ℹ️  No path changes needed")
        
        # Verify key files exist at expected locations
        ios_dir = project_root / "frontend/ios"
        expected_files = [
            "Views/SwingAnalysisView.swift",
            "Views/HomeView.swift", 
            "Services/API Service.swift",
            "Golf Swing AI/ContentView.swift",
            "Golf Swing AI/Golf_Swing_AIApp.swift"
        ]
        
        print("\n🔍 Verifying file locations:")
        all_files_exist = True
        for file_path in expected_files:
            full_path = ios_dir / file_path
            if full_path.exists():
                print(f"✅ {file_path}")
            else:
                print(f"❌ Missing: {file_path}")
                all_files_exist = False
        
        if all_files_exist:
            print(f"\n🎉 Xcode project paths fixed successfully!")
            print(f"📱 You can now open: frontend/ios/Golf Swing AI.xcodeproj")
            return True
        else:
            print(f"\n⚠️  Some files are missing. Check the file locations.")
            return False
            
    except Exception as e:
        print(f"❌ Error fixing Xcode paths: {e}")
        return False

if __name__ == "__main__":
    fix_xcode_project()