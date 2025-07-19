# Golf Swing AI - Deployment Instructions

## 🚀 Quick Deployment Options

### Option 1: Local Python Server
```bash
pip install -r requirements.txt
python api.py
# Access at http://localhost:8000
```

### Option 2: Docker Deployment
```bash
docker-compose up --build
# Access at http://localhost:8000
```

### Option 3: Cloud Hosting (Recommended)

#### Heroku
```bash
# Install Heroku CLI, then:
heroku create your-golf-swing-ai
git init
git add .
git commit -m "Deploy Golf Swing AI"
heroku git:remote -a your-golf-swing-ai
git push heroku main
```

#### Railway
```bash
# Connect GitHub repo to Railway
# Add environment variables if needed
# Railway will auto-deploy from main branch
```

#### DigitalOcean App Platform
1. Upload this folder to GitHub
2. Create new App in DigitalOcean
3. Connect GitHub repo
4. Set buildpack to Python
5. Set run command: `python api.py`

## 📊 File Size Summary
- **Total Package**: ~64KB (very lightweight!)
- **Core Model**: 22.9KB
- **Feature Extractor**: 16.1KB  
- **API Service**: 3.2KB

## 🔧 Environment Variables
No environment variables required - the model is self-contained.

## 📈 Performance Expectations
- **Memory Usage**: ~200MB
- **CPU Usage**: Low (mostly inference)
- **Response Time**: 2-5 seconds per video
- **Concurrent Users**: 10-50 (depends on hosting)

## 🛠️ Troubleshooting
- **Import Errors**: Run `pip install -r requirements.txt`
- **Model Not Found**: Ensure `models/` directory is present
- **Video Processing Fails**: Check video format (MP4/MOV recommended)

## 📱 API Testing
```bash
# Health check
curl http://localhost:8000/health

# Upload video for prediction
curl -X POST "http://localhost:8000/predict" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@test_video.mp4"
```