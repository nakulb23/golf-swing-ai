# Server Video Format Compatibility Guide

## Current Issue
The AI server is rejecting iPhone video uploads with error: `{"detail":"File must be a video"}`

## iPhone Video Formats
iPhones record videos in several formats depending on settings and device:

### Common iPhone Video Formats:
1. **QuickTime Movie (.mov)** - Default format
   - Container: QuickTime
   - Video Codec: H.264 or HEVC (H.265)
   - MIME Type: `video/quicktime`

2. **MP4 (.mp4)** - When "Most Compatible" is selected
   - Container: MP4
   - Video Codec: H.264
   - MIME Type: `video/mp4`

3. **HEVC/H.265** - High efficiency format
   - Container: MP4 or QuickTime
   - Video Codec: HEVC
   - MIME Type: `video/mp4` or `video/quicktime`

## Server-Side Updates Needed

### 1. File Type Detection
Update your server to accept these MIME types:
```python
ALLOWED_VIDEO_TYPES = [
    'video/mp4',
    'video/quicktime',
    'video/mov',
    'video/x-msvideo',  # AVI (fallback)
    'video/avi'         # AVI (fallback)
]

ALLOWED_EXTENSIONS = ['.mp4', '.mov', '.avi', '.m4v']
```

### 2. Video Processing Library Updates
Ensure your video processing library (OpenCV, FFmpeg, etc.) supports:
- **H.264** codec (widely supported)
- **HEVC/H.265** codec (newer, requires updated libraries)
- **QuickTime containers** (.mov files)

### 3. Example Server Validation (FastAPI/Python)
```python
from fastapi import UploadFile, HTTPException
import magic  # python-magic for file type detection

def validate_video_file(file: UploadFile):
    # Check file extension
    allowed_extensions = ['.mp4', '.mov', '.avi', '.m4v']
    file_ext = os.path.splitext(file.filename)[1].lower()
    
    if file_ext not in allowed_extensions:
        raise HTTPException(400, "Invalid file extension")
    
    # Check MIME type
    file_content = file.file.read()
    file.file.seek(0)  # Reset file pointer
    
    mime_type = magic.from_buffer(file_content, mime=True)
    allowed_mimes = ['video/mp4', 'video/quicktime', 'video/x-msvideo']
    
    if mime_type not in allowed_mimes:
        raise HTTPException(400, f"Invalid file type: {mime_type}")
    
    return True
```

### 4. FFmpeg Compatibility
If using FFmpeg for processing, ensure it's compiled with:
```bash
# Check FFmpeg capabilities
ffmpeg -formats | grep mov
ffmpeg -codecs | grep h264
ffmpeg -codecs | grep hevc
```

### 5. OpenCV Updates
For OpenCV-based processing:
```python
import cv2

# These should work with updated OpenCV
cap = cv2.VideoCapture('video.mov')  # QuickTime
cap = cv2.VideoCapture('video.mp4')  # MP4
```

## iOS App Optimizations Made

### 1. Video Recording Settings
- Disabled movie fragmentation for better compatibility
- Set consistent video orientation (portrait)
- Enhanced error logging with file format detection

### 2. Debug Information
The app now logs:
- Video file size
- File format detection via header analysis
- Detailed multipart form data information

## Testing
1. **Record a video** using the iOS app
2. **Check console logs** for video format details
3. **Server should now accept** the properly formatted video data

## Next Steps
1. Update server video validation logic
2. Test with various iPhone video formats
3. Consider adding server-side video format conversion if needed