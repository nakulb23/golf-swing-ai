# GitHub Setup for Golf Swing AI

## Create GitHub Repository
1. Go to https://github.com
2. Click "New repository"
3. Repository name: `golf-swing-ai`
4. Make it **Public** (required for privacy pages)
5. Don't initialize with README
6. Click "Create repository"

## Connect Your Local Repository
After creating the repository, run these commands in Terminal:

```bash
cd "/Users/nakulbhatnagar/Desktop/Golf Swing AI"

# Add GitHub as remote (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/golf-swing-ai.git

# Push your code
git branch -M main
git push -u origin main
```

## Your Privacy Page URLs (After Upload)
Once uploaded, your URLs will be:

**Privacy Policy URL:**
```
https://YOUR_USERNAME.github.io/golf-swing-ai/privacy-policy.html
```

**Data Deletion URL:**
```
https://YOUR_USERNAME.github.io/golf-swing-ai/data-deletion-page.html
```

## Enable GitHub Pages
1. Go to your repository on GitHub
2. Click **Settings** tab
3. Scroll to **Pages** section
4. Source: **Deploy from a branch**
5. Branch: **main**
6. Folder: **/ (root)**
7. Click **Save**

## Alternative: Use Raw GitHub URLs
If you don't want to enable GitHub Pages, you can use raw URLs:

**Privacy Policy:**
```
https://raw.githubusercontent.com/YOUR_USERNAME/golf-swing-ai/main/privacy-policy.html
```

**Data Deletion:**
```
https://raw.githubusercontent.com/YOUR_USERNAME/golf-swing-ai/main/data-deletion-page.html
```

## Facebook App Configuration
Use these URLs in your Facebook App Settings:

1. **App Settings → Basic**
2. **Privacy Policy URL**: Add your privacy policy URL
3. **User Data Deletion**: Add your data deletion URL
4. **App Domains**: Add `your-username.github.io`

## Files Ready for Upload
✅ privacy-policy.html
✅ data-deletion-page.html  
✅ PRIVACY_POLICY.md
✅ FACEBOOK_SETUP.md

All files are committed and ready to push!