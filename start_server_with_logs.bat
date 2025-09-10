@echo off
echo Starting Golf Swing AI Server with Logging...
cd /d "C:\Users\nbhat\golf-swing-ai"
python server_https.py > server_logs.txt 2>&1