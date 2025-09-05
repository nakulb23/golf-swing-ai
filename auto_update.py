#!/usr/bin/env python3
"""
Automated Git Update System for Golf Swing AI
Checks for updates every 30 minutes and restarts server if needed
"""

import subprocess
import time
import os
import sys
import psutil
from datetime import datetime

class AutoUpdater:
    def __init__(self, repo_path="."):
        self.repo_path = repo_path
        self.server_script = "server_https.py"
        self.check_interval = 1800  # 30 minutes
        
    def log(self, message):
        """Log with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {message}")
        
    def check_for_updates(self):
        """Check if there are new commits on origin/main"""
        try:
            # Fetch latest changes
            result = subprocess.run(
                ["git", "fetch", "origin", "main"],
                cwd=self.repo_path,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.log(f"Failed to fetch: {result.stderr}")
                return False
                
            # Check if local is behind remote
            result = subprocess.run(
                ["git", "rev-list", "--count", "HEAD..origin/main"],
                cwd=self.repo_path,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.log(f"Failed to check commits: {result.stderr}")
                return False
                
            commits_behind = int(result.stdout.strip())
            
            if commits_behind > 0:
                self.log(f"Found {commits_behind} new commits. Updating...")
                return True
            else:
                self.log("Repository is up to date")
                return False
                
        except Exception as e:
            self.log(f"Error checking for updates: {e}")
            return False
    
    def update_repository(self):
        """Pull latest changes from origin/main"""
        try:
            # Stash any local changes
            subprocess.run(
                ["git", "stash"],
                cwd=self.repo_path,
                capture_output=True
            )
            
            # Pull latest changes
            result = subprocess.run(
                ["git", "pull", "origin", "main"],
                cwd=self.repo_path,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.log(f"Failed to pull: {result.stderr}")
                return False
                
            self.log("Repository updated successfully")
            return True
            
        except Exception as e:
            self.log(f"Error updating repository: {e}")
            return False
    
    def restart_server(self):
        """Restart the HTTPS server"""
        try:
            # Find and kill existing server process
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                try:
                    cmdline = proc.info['cmdline']
                    if cmdline and self.server_script in ' '.join(cmdline):
                        self.log(f"Stopping server process {proc.info['pid']}")
                        proc.terminate()
                        proc.wait(timeout=10)
                        break
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
            # Wait a moment for cleanup
            time.sleep(2)
            
            # Start new server process
            self.log("Starting updated server...")
            subprocess.Popen(
                [sys.executable, self.server_script],
                cwd=self.repo_path,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            
            self.log("Server restarted with updates")
            return True
            
        except Exception as e:
            self.log(f"Error restarting server: {e}")
            return False
    
    def run(self):
        """Main update loop"""
        self.log("Golf Swing AI Auto-Updater started")
        self.log(f"Checking for updates every {self.check_interval // 60} minutes")
        
        while True:
            try:
                if self.check_for_updates():
                    if self.update_repository():
                        self.restart_server()
                        self.log("Update cycle completed successfully")
                    else:
                        self.log("Update failed - server not restarted")
                
                # Wait before next check
                time.sleep(self.check_interval)
                
            except KeyboardInterrupt:
                self.log("Auto-updater stopped by user")
                break
            except Exception as e:
                self.log(f"Unexpected error: {e}")
                time.sleep(60)  # Wait 1 minute before retrying

if __name__ == "__main__":
    updater = AutoUpdater()
    updater.run()