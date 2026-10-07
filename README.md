# 🏠 FamilySphere

**Modern Family Document Management & Communication Platform**

A comprehensive web and mobile application for Indian families to manage documents, track important events, communicate in real-time, and leverage AI-powered document intelligence.

---

## 📋 Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Deployment](#deployment)
- [Environment Variables](#environment-variables)
- [API Documentation](#api-documentation)

---

## ✨ Features

### 🔐 Authentication & Security
- Email OTP-based registration with SMTP
- Google OAuth integration
- JWT token management (30-day expiration)
- Role-based access control (Admin, Member, Viewer)

### 👨‍👩‍👧‍👦 Family Management
- Create and manage family groups
- Invite family members with role assignment
- Member activity tracking
- Family-wide settings and preferences

### 📄 Document Management
- Upload 50+ document types (Aadhaar, PAN, Passport, Bills, Medical records, etc.)
- Cloud storage via Cloudinary
- Document categorization and organization
- Version control and soft delete with recovery
- Role-based document access

### 🤖 AI-Powered Intelligence
- OCR text extraction (Tesseract.js)
- Smart document classification (Google Gemini AI)
- Automatic entity extraction (names, dates, amounts, account numbers)
- Risk analysis (expiry detection, missing fields, data quality)
- Confidence-based user confirmation workflow

### 📅 Timeline & Events
- Auto-generated events from document intelligence
- Expiry date reminders
- Bill due date notifications
- Recurring event support
- Family activity timeline

### 💬 Real-Time Communication
- Socket.io-based family chat
- Family-specific chat rooms
- Message history storage
- Real-time notifications

### 📊 Document Intelligence Dashboard
- OCR job queue monitoring (BullMQ + Redis)
- Document processing status
- System health monitoring

---

## 🛠 Tech Stack

### Frontend (Mobile)
- **Framework**: Flutter 3.2+
- **State Management**: Riverpod
- **Storage**: Hive (local cache)
- **HTTP Client**: Dio
- **Authentication**: Google Sign-In, Flutter Secure Storage
- **Real-time**: Socket.io Client

### Backend
- **Runtime**: Node.js 20+
- **Framework**: Express.js 5
- **Language**: TypeScript
- **Database**: MongoDB (Mongoose ODM)
- **Queue**: BullMQ + Redis
- **Real-time**: Socket.io
- **Storage**: Cloudinary
- **AI/ML**: Google Gemini AI, Tesseract.js OCR
- **Email**: Nodemailer (SMTP)
- **Security**: Helmet, JWT, bcrypt

### Infrastructure
- **Deployment**: Render (Backend), Cloudinary (Assets)
- **Database**: MongoDB Atlas
- **Cache/Queue**: Redis Cloud
- **Version Control**: Git/GitHub

---

## 📁 Project Structure

```
FamilySphere/
├── backend/                 # Node.js/TypeScript backend
│   ├── src/
│   │   ├── config/          # Database, Redis, app configs
│   │   ├── controllers/     # Route controllers
│   │   ├── middleware/      # Auth, error handling
│   │   ├── models/          # Mongoose schemas
│   │   ├── routes/          # API routes
│   │   ├── services/        # Business logic, Socket.io, OCR
│   │   ├── workers/         # BullMQ workers
│   │   ├── queues/          # Job queues
│   │   └── server.ts        # Entry point
│   ├── .env.example         # Environment template
│   ├── package.json
│   └── tsconfig.json
│
├── mobile/                  # Flutter mobile app
│   └── familysphere_app/
│       ├── lib/
│       │   ├── core/        # Config, theme, utils, providers
│       │   ├── features/    # Feature modules (auth, documents, chat, etc.)
│       │   └── main.dart    # App entry point
│       ├── android/
│       ├── ios/
│       ├── web/
│       └── pubspec.yaml
│
├── redis/                   # Local Redis setup (Windows)
├── render.yaml              # Render deployment config
├── RENDER_DEPLOYMENT.md     # Deployment guide
└── README.md                # This file
```

---

## 🚀 Getting Started

### Prerequisites

- **Node.js** 20+ and npm
- **Flutter** 3.2+
- **MongoDB** (local or Atlas)
- **Redis** (local or cloud) - optional
- **Git**
- Java JDK 17+ (for Android build)

### Backend Setup

1. **Clone the repository**
```bash
git clone https://github.com/Jeel-Kanani/FamilySphere.git
cd FamilySphere
```

2. **Install backend dependencies**
```bash
cd backend
npm install
```

3. **Configure environment variables**
```bash
cp .env.example .env
# Edit .env with your credentials
```

4. **Build TypeScript**
```bash
npm run build
```

5. **Start development server**
```bash
npm run dev
```

Backend will run on `http://localhost:5000`

### Mobile Setup

1. **Navigate to Flutter app**
```bash
cd mobile/familysphere_app
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure API endpoint**
Edit `lib/core/config/api_config.dart`:
```dart
static const bool _isProduction = false; // Use local backend
static const String _localPhysicalDevice = 'http://YOUR_PC_IP:5000';
```

4. **Run the app**
```bash
# Android emulator
flutter run -d emulator-5554

# Physical device
flutter run -d DEVICE_ID

# Using batch scripts (Windows)
# In project root:
start-dev.bat       # Starts backend + Redis
flutter-local.bat   # Runs Flutter with auto-detected IP
```

---

## 🌐 Deployment

### Deploy to Render

See [RENDER_DEPLOYMENT.md](./RENDER_DEPLOYMENT.md) for detailed instructions.

**Quick steps:**
1. Push code to GitHub
2. Connect repository to Render
3. Render auto-detects `render.yaml`
4. Set environment variables in Render dashboard
5. Deploy!

**Production URL**: `https://familysphere.onrender.com`

---

## 🔑 Environment Variables

### Backend (.env)

```bash
# Server
PORT=5000
NODE_ENV=development

# Database
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/dbname

# Authentication
JWT_SECRET=your-super-secret-jwt-key
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com

# Cloudinary
CLOUDINARY_CLOUD_NAME=your-cloudinary-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret

# Email (SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM=your-email@gmail.com
OTP_SECRET=your-otp-secret

# Redis (optional)
REDIS_URL=redis://localhost:6379

# AI
GEMINI_API_KEY=your-gemini-api-key
OCR_CONCURRENCY=1
```

### Important Notes

- **SMTP_PASS**: Use Gmail App Password, not your regular password
  - Generate at: https://myaccount.google.com/apppasswords
- **JWT_SECRET**: Use a strong random string (e.g., from `openssl rand -base64 32`)
- **MongoDB**: Allow IP `0.0.0.0/0` in Atlas for Render deployment

---

## 📚 API Documentation

### Base URL
- **Local**: `http://localhost:5000`
- **Production**: `https://familysphere.onrender.com`

### Core Endpoints

#### Health Check
```http
GET /api/health
```
Returns: MongoDB, Redis status, and OCR queue state

#### Authentication
```http
POST /api/auth/register          # Register with email/password
POST /api/auth/login             # Login
POST /api/auth/google            # Google OAuth
POST /api/auth/send-email-otp    # Send OTP
POST /api/auth/verify-email-otp  # Verify OTP
GET  /api/auth/me                # Get current user
```

#### Families
```http
GET    /api/families             # List user's families
POST   /api/families             # Create family
GET    /api/families/:id         # Get family details
PUT    /api/families/:id         # Update family
POST   /api/families/:id/members # Add member
```

#### Documents
```http
POST   /api/documents/upload     # Upload document (multipart/form-data)
GET    /api/documents            # List documents
GET    /api/documents/:id        # Get document details
DELETE /api/documents/:id        # Delete document
GET    /api/documents/:id/ocr-status  # Check OCR processing status
```

#### Vault
```http
GET    /api/vault                # List vault documents
POST   /api/vault/upload         # Upload to vault
DELETE /api/vault/:id            # Remove from vault
```

#### Events
```http
GET    /api/events               # List events
POST   /api/events               # Create event
PUT    /api/events/:id           # Update event
DELETE /api/events/:id           # Delete event
```

#### Chat
```http
GET    /api/chat/:familyId       # Get chat history
POST   /api/chat/:familyId       # Send message
```

### Authentication
All protected endpoints require JWT token in header:
```http
Authorization: Bearer <your-jwt-token>
```

---

## 🔒 Security Features

- JWT-based authentication with 30-day expiration
- Password hashing with bcrypt
- Role-based access control
- CORS protection
- Helmet.js security headers
- Input validation and sanitization
- Soft delete for sensitive data
- Environment variable protection

---

## 🧪 Testing

### Test Backend
```bash
cd backend
npm test
```

### Test Flutter
```bash
cd mobile/familysphere_app
flutter test
```

---

## 📱 Supported Platforms

- ✅ Android (Mobile & Tablet)
- ✅ iOS (Mobile & Tablet)
- ✅ Web (Desktop browsers)
- ⚠️ Windows/Linux/macOS (Flutter desktop - experimental)

---

## 🤝 Contributing

This is a student project for 5th semester. Contributions, suggestions, and feedback are welcome!

---

## 👨‍💻 Developer

**Jeel Kanani**
- GitHub: [@Jeel-Kanani](https://github.com/Jeel-Kanani)
- Email: kananijeel00@gmail.com

---

## 📄 License

This project is for educational purposes (Student Project - 5th Semester).

---

## 🙏 Acknowledgments

- Google Gemini AI for document intelligence
- Tesseract.js for OCR capabilities
- Cloudinary for document storage
- MongoDB Atlas for database hosting
- Render for backend deployment

---

## 📞 Support

For issues or questions:
1. Check [RENDER_DEPLOYMENT.md](./RENDER_DEPLOYMENT.md) for deployment help
2. Review security reports: `SECURITY_AUDIT_REPORT.md`
3. Open an issue on GitHub

---

**Built with ❤️ for Indian Families**
