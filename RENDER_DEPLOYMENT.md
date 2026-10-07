# Render Deployment Guide for FamilySphere

## 🚀 Quick Deploy Steps

### 1. Push to GitHub
```bash
git add .
git commit -m "Fix: Production configuration and Render deployment setup"
git push origin main
```

### 2. Set Up Render Service

#### Option A: Using render.yaml (Recommended)
1. Go to [Render Dashboard](https://dashboard.render.com/)
2. Click **"New +"** → **"Blueprint"**
3. Connect your GitHub repository: `Jeel-Kanani/FamilySphere`
4. Render will automatically detect `render.yaml` and set up the service

#### Option B: Manual Setup
1. Go to [Render Dashboard](https://dashboard.render.com/)
2. Click **"New +"** → **"Web Service"**
3. Connect repository: `Jeel-Kanani/FamilySphere`
4. Configure:
   - **Name**: `familysphere-backend`
   - **Region**: Singapore (or closest to you)
   - **Branch**: `main`
   - **Root Directory**: Leave blank
   - **Runtime**: Node
   - **Build Command**: `cd backend && npm install && npm run build`
   - **Start Command**: `cd backend && npm start`
   - **Plan**: Free

### 3. Configure Environment Variables

Go to your service → **Environment** tab and add these variables:

#### Required Variables
```bash
# Database
MONGO_URI=mongodb+srv://kananijeel00_db_user:JEEL%40171285@familysphere.2rqtvcd.mongodb.net/familysphere?retryWrites=true&w=majority&appName=FamilySphere

# Authentication
JWT_SECRET=supersecretkey123

# Google OAuth
GOOGLE_CLIENT_ID=967736331876-ve92tp7l0ao891vpqkqu0o95vam74q46.apps.googleusercontent.com,967736331876-n9u76f17tj41mq2pib9akrcpvhvjhlhh.apps.googleusercontent.com

# Cloudinary
CLOUDINARY_CLOUD_NAME=dtydc4qdq
CLOUDINARY_API_KEY=726569867577951
CLOUDINARY_API_SECRET=YuiaXVgtkPzXEcJmLiojbLiO9sc

# Email (SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=kananijeel00@gmail.com
SMTP_PASS=[YOUR_GMAIL_APP_PASSWORD]
SMTP_FROM=kananijeel00@gmail.com
OTP_SECRET=familysphere_dev_otp_secret_2026

# Redis (Optional - for OCR queue)
REDIS_URL=redis://default:YMlEbBoerBKHIa4dxfAmBrYLvYtwauuE@redis-11531.c301.ap-south-1-1.ec2.cloud.redislabs.com:11531

# Gemini AI (Optional - for document intelligence)
GEMINI_API_KEY=AIzaSyCB-1JSTtBEtBdjyPRNEdD8cXXzU2i6B80
OCR_CONCURRENCY=1

# System
NODE_ENV=production
PORT=5000
```

#### Important Notes:
- **SMTP_PASS**: You need a Gmail App Password (not your regular password)
  - Go to: https://myaccount.google.com/apppasswords
  - Generate a new app password for "Mail"
  - Use that password in SMTP_PASS

### 4. Monitor Deployment

1. Watch the **Logs** tab during deployment
2. Wait for "Your service is live 🎉" message
3. Check health endpoint: `https://familysphere.onrender.com/api/health`
4. Expected response:
```json
{
  "status": "ok",
  "mongo": "up",
  "redis": "up",
  "ocrQueueEnabled": true,
  "timestamp": "2024-10-07T12:00:00.000Z"
}
```

### 5. Update Flutter App (If Needed)

The Flutter app already points to production:
```dart
// mobile/familysphere_app/lib/core/config/api_config.dart
static const String _productionUrl = 'https://familysphere.onrender.com';
static const bool _isProduction = true; // Already set
```

## 🔧 Troubleshooting

### Issue: Build Fails
**Solution**: Check if all dependencies are in `package.json`
```bash
cd backend
npm install
npm run build
```

### Issue: ECONNREFUSED Redis
**Solution**: Redis is optional. The app will work without it (OCR processed synchronously)

### Issue: MongoDB Connection Failed
**Solution**: 
1. Check if MongoDB Atlas allows connections from `0.0.0.0/0`
2. Verify MONGO_URI is correct in Render environment variables

### Issue: Health Check Failing
**Solution**: Make sure `/api/health` endpoint is accessible
```bash
curl https://familysphere.onrender.com/api/health
```

### Issue: Free Tier Sleeps
**Note**: Render free tier sleeps after 15 minutes of inactivity
- First request after sleep takes 30-60 seconds to wake up
- Consider upgrading to paid plan for production

## 📱 Mobile App Configuration

Once deployed, your mobile app will automatically connect to:
- Production URL: `https://familysphere.onrender.com`
- WebSocket: `wss://familysphere.onrender.com`

No code changes needed in Flutter app if `_isProduction = true`.

## 🔐 Security Checklist

- [ ] Changed default JWT_SECRET
- [ ] Using Gmail App Password (not regular password)
- [ ] MongoDB Atlas whitelist configured
- [ ] Cloudinary credentials secured
- [ ] Environment variables set in Render (not in code)

## 🎉 Success!

Your app should now be live at: **https://familysphere.onrender.com**

Test endpoints:
- Ping: `https://familysphere.onrender.com/ping`
- Health: `https://familysphere.onrender.com/api/health`
- Auth: `https://familysphere.onrender.com/api/auth/login`

---

**Note**: Keep this file for reference. Do not commit sensitive credentials to Git!
