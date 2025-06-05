# 🆓 FREE Render Deployment Guide for Golf Swing AI

## Why Render?
- ✅ **Completely FREE** forever (with limits)
- ✅ Easy GitHub integration
- ✅ Auto-deploys on code changes
- ✅ HTTPS included
- ✅ Good performance

## Step-by-Step Deployment

### 1. Your Code is Ready ✅
Your GitHub repo is already set up at: https://github.com/nakulb23/golf-swing-ai

### 2. Deploy on Render

1. **Visit Render**: Go to [render.com](https://render.com)
2. **Sign Up**: Create account (free) - use your GitHub account
3. **New Web Service**: Click "New +" → "Web Service"
4. **Connect Repository**: 
   - Choose "Build and deploy from a Git repository"
   - Connect your GitHub account
   - Select `nakulb23/golf-swing-ai` repository
5. **Configure Service**:
   - **Name**: `golf-swing-ai`
   - **Region**: Choose closest to you
   - **Branch**: `main`
   - **Runtime**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn api:app --host 0.0.0.0 --port $PORT`
6. **Plan**: Select **FREE** plan
7. **Create Web Service**: Click "Create Web Service"

### 3. Environment Variables (Auto-detected)
Render will automatically set:
- `PORT` - Assigned by Render
- `PYTHONPATH` - For imports

### 4. Monitor Deployment
- **Build Logs**: Watch the build process
- **Deploy Logs**: Monitor startup
- **Service URL**: You'll get a URL like `https://golf-swing-ai.onrender.com`

### 5. Test Your API
Once deployed, test at your Render URL:
```bash
# Replace with your actual Render URL
python3 test_deployment.py https://golf-swing-ai.onrender.com
```

## Free Tier Limitations
- **Sleep after 15 min** of inactivity (wakes up on request)
- **750 hours/month** (more than enough for development)
- **Slower cold starts** (takes ~30 seconds to wake up)
- **Build time limits** (sufficient for your app)

## API Endpoints
Your FREE hosted API will have:
- `GET /` - API overview
- `GET /health` - Health check  
- `POST /predict` - Swing analysis
- `POST /chat` - CaddieChat Q&A
- `POST /track-ball` - Ball tracking
- `GET /docs` - Interactive documentation

## Advantages of Render Free Tier
- ✅ No credit card required
- ✅ Custom domain support
- ✅ HTTPS certificates included
- ✅ GitHub auto-deployment
- ✅ Environment variables
- ✅ Log viewing

## Perfect for iOS Development!
The free tier is ideal for:
- Development and testing
- Demo apps
- Portfolio projects
- Learning and prototyping

Your Golf Swing AI API will be completely free to host! 🎉