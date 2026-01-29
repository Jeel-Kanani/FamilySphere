# FamilySphere - Complete Project Documentation

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Tech Stack](#tech-stack)
3. [System Architecture](#system-architecture)
4. [Features & Modules](#features--modules)
5. [Development Roadmap](#development-roadmap)
6. [Cost Analysis](#cost-analysis)
7. [Software Engineering Model](#software-engineering-model)
8. [Database Schema](#database-schema)
9. [API Documentation](#api-documentation)
10. [Security & Privacy](#security--privacy)
11. [Future Scope](#future-scope)

---

## 🎯 Project Overview

### Project ID
**FamilySphere-2026**

### Problem Statement
Modern families struggle to:
- Manage and share important documents (medical records, insurance, IDs)
- Track shared expenses and budgets
- Coordinate family events and activities
- Maintain secure access to sensitive family information

### Solution
FamilySphere is a comprehensive family management mobile application that provides a centralized, secure platform for families to organize documents, manage expenses, track activities, and stay connected.

### Target Audience
- Families with 2-10 members
- Tech-savvy adults (25-55 years)
- Families managing shared documents and expenses

### Project Objectives
1. Create a secure document management system for families
2. Enable expense tracking and budget management
3. Facilitate family communication and event coordination
4. Ensure data privacy and role-based access control
5. Provide offline-first mobile experience

---

## 🛠️ Tech Stack

### Mobile Application (Frontend)
| Technology | Version | Purpose |
|------------|---------|---------|
| **Flutter** | 3.10+ | Cross-platform mobile framework (iOS/Android) |
| **Dart** | 3.10+ | Programming language |
| **Riverpod** | 2.5+ | State management |
| **Hive** | 2.2+ | Local database (offline storage) |
| **HTTP/Dio** | Latest | API communication |

### Backend (Server)
| Technology | Version | Purpose |
|------------|---------|---------|
| **Node.js** | 24+ | Runtime environment |
| **Express.js** | Latest | Web framework |
| **TypeScript** | Latest | Type-safe JavaScript |
| **MongoDB** | 7+ | NoSQL database |
| **Mongoose** | Latest | MongoDB ODM |
| **JWT** | Latest | Authentication tokens |
| **bcrypt.js** | Latest | Password hashing |

### Storage & Infrastructure
| Service | Purpose | Tier |
|---------|---------|------|
| **Cloudinary** | Document/image storage | Free (25GB) |
| **MongoDB Atlas** | Cloud database (optional) | Free (512MB) |
| **Render/Railway** | Backend hosting (optional) | Free tier available |

### Development Tools
- **Visual Studio Code** - Primary IDE
- **Android Studio** - Android emulator & SDK
- **Postman** - API testing
- **Git/GitHub** - Version control
- **Figma** - UI/UX design (optional)

---

## 🏗️ System Architecture

### Architecture Pattern
**Clean Architecture + MVC (Modified)**

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile App (Flutter)                  │
│  ┌────────────┐  ┌──────────────┐  ┌─────────────────┐ │
│  │Presentation│  │   Domain      │  │      Data       │ │
│  │   Layer    │←→│    Layer      │←→│     Layer       │ │
│  │ (UI/State) │  │ (Business     │  │ (Repository/    │ │
│  │            │  │  Logic)       │  │  Data Sources)  │ │
│  └────────────┘  └──────────────┘  └─────────────────┘ │
└─────────────────────┬───────────────────────────────────┘
                      │ REST API (HTTP/HTTPS)
                      ▼
┌─────────────────────────────────────────────────────────┐
│                Backend Server (Node.js/Express)          │
│  ┌──────────┐  ┌───────────┐  ┌──────────────────────┐ │
│  │  Routes  │→│Controllers│→│ Business Logic/Models │ │
│  └──────────┘  └───────────┘  └──────────────────────┘ │
└─────────────────────┬───────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼                           ▼
┌──────────────┐          ┌──────────────────┐
│   MongoDB    │          │    Cloudinary    │
│  (Database)  │          │ (File Storage)   │
└──────────────┘          └──────────────────┘
```

### Communication Flow
1. **User Action** → Mobile UI
2. **State Management** → Riverpod Provider
3. **Use Case** → Domain Layer
4. **Repository** → Data Layer
5. **API Call** → Backend Server
6. **Authentication** → JWT Middleware
7. **Business Logic** → Controller
8. **Data Persistence** → MongoDB
9. **File Storage** → Cloudinary
10. **Response** → Back through layers to UI

---

## 📱 Features & Modules

### Module 1: Authentication & User Management
**Status:** ✅ Completed

| Feature | Description | Priority |
|---------|-------------|----------|
| Email/Password Registration | User signup with name, email, password | HIGH |
| Login | JWT-based authentication | HIGH |
| Profile Setup | Name, photo, personal details | HIGH |
| Password Reset | Email-based password recovery | MEDIUM |
| Logout | Clear session and tokens | HIGH |

**Tech Implementation:**
- Frontend: Login/Register screens with form validation
- Backend: JWT token generation, bcrypt password hashing
- Storage: User data in MongoDB, token in SharedPreferences

**Files:**
- `lib/features/auth/` (Mobile)
- `src/controllers/authController.ts` (Backend)
- `src/models/User.ts` (Backend)

---

### Module 2: Family Management
**Status:** 🟡 Partial (UI exists, needs backend)

| Feature | Description | Priority |
|---------|-------------|----------|
| Create Family | Founder creates family group | HIGH |
| Join Family | Members join via invite code | HIGH |
| Family Roles | Admin/Member permissions | HIGH |
| Member List | View all family members | MEDIUM |
| Remove Member | Admin can remove members | LOW |

**Tech Implementation:**
- Backend: Family CRUD operations, invite code generation
- Database: Family collection with member references
- Authorization: Role-based access control

**Database Schema:**
```javascript
Family {
  _id: ObjectId,
  name: String,
  inviteCode: String (unique, 6-digit),
  admin: ObjectId (User ref),
  members: [ObjectId] (User refs),
  createdAt: Date,
  updatedAt: Date
}
```

---

### Module 3: Document Management
**Status:** 🔴 Not Started

| Feature | Description | Priority |
|---------|-------------|----------|
| Upload Documents | PDF, images, scanned docs | HIGH |
| Categorize | Medical, Insurance, ID, Education, etc. | HIGH |
| View/Download | Access documents anytime | HIGH |
| Search | Find docs by name, category, date | MEDIUM |
| Share | Share specific docs with members | MEDIUM |
| OCR Text Extraction | Extract text from scanned docs | LOW |

**Tech Implementation:**
- Frontend: File picker, camera integration, PDF viewer
- Backend: File upload endpoint with Multer
- Storage: Cloudinary for files, MongoDB for metadata
- OCR: Google ML Kit (on-device)

**Cost:** Free (Cloudinary 25GB)

---

### Module 4: Expense Tracking
**Status:** 🔴 Not Started

| Feature | Description | Priority |
|---------|-------------|----------|
| Add Expense | Record expenses with category | HIGH |
| Split Expenses | Divide among family members | HIGH |
| View History | List of all expenses | HIGH |
| Monthly Reports | Charts and analytics | MEDIUM |
| Budget Goals | Set and track budgets | LOW |

**Tech Implementation:**
- Frontend: Expense forms, charts (fl_chart package)
- Backend: Expense CRUD operations
- Database: Expense collection with member splits

**Database Schema:**
```javascript
Expense {
  _id: ObjectId,
  familyId: ObjectId,
  addedBy: ObjectId (User),
  amount: Number,
  category: String,
  description: String,
  date: Date,
  splitAmong: [{
    memberId: ObjectId,
    amount: Number
  }],
  attachments: [String] (URLs)
}
```

---

### Module 5: Events & Calendar
**Status:** 🔴 Not Started

| Feature | Description | Priority |
|---------|-------------|----------|
| Create Event | Family events with date/time | MEDIUM |
| Notifications | Remind members of events | MEDIUM |
| RSVP | Members confirm attendance | LOW |

---

## 🗓️ Development Roadmap

### Phase 1: Foundation ✅ (Completed)
**Timeline:** Weeks 1-2

- [x] Project setup (Flutter + Node.js)
- [x] Database design
- [x] Authentication system (JWT)
- [x] User registration & login
- [x] Basic UI/UX design
- [x] API structure

### Phase 2: Family & Document Management 🟡 (In Progress)
**Timeline:** Weeks 3-5

- [ ] Family creation & management backend
- [ ] Invite code system
- [ ] Document upload integration (Cloudinary)
- [ ] Document CRUD operations
- [ ] Document viewer (PDF, images)
- [ ] Category management

### Phase 3: Expense Tracking
**Timeline:** Weeks 6-7

- [ ] Expense backend API
- [ ] Expense UI (add, edit, delete)
- [ ] Expense splitting logic
- [ ] Charts and reports
- [ ] Budget tracking

### Phase 4: Advanced Features
**Timeline:** Weeks 8-9

- [ ] Events & calendar
- [ ] Push notifications
- [ ] Search functionality
- [ ] OCR integration
- [ ] Offline sync

### Phase 5: Testing & Deployment
**Timeline:** Weeks 10-12

- [ ] Unit testing
- [ ] Integration testing
- [ ] UI/UX testing
- [ ] Performance optimization
- [ ] Beta release
- [ ] Bug fixes
- [ ] Production deployment

---

## 💰 Cost Analysis

### Development Costs
| Item | Cost | Notes |
|------|------|-------|
| Developer Time | $0 | Self-developed |
| Design Tools (Figma) | $0 | Free tier |
| IDE & Tools | $0 | VS Code, Android Studio (free) |
| **Total Development** | **$0** | |

### Infrastructure Costs (Free Tier)
| Service | Free Tier | Paid Tier (if needed) |
|---------|-----------|----------------------|
| MongoDB Atlas | 512MB | $9/month (10GB) |
| Backend Hosting (Render) | 750 hrs/month | $7/month |
| Cloudinary | 25GB storage | $89/month (100GB) |
| Domain Name | - | $10/year |
| **Monthly Total** | **$0** | **~$16/month** |

### Scaling Costs (100 families, ~500 users)
| Resource | Estimate | Cost |
|----------|----------|------|
| Database (5GB) | - | $0 (Atlas Free) |
| Storage (50GB docs) | - | $89/month |
| API Hosting | - | $7/month |
| **Total** | | **~$96/month** |

### Revenue Model (Optional Future)
1. **Freemium Model**
   - Free: Up to 5 family members, 5GB storage
   - Premium: $4.99/month - Unlimited members, 50GB storage
   
2. **One-time Payment**
   - $29.99 for lifetime premium access

---

## 🔄 Software Engineering Model

### Chosen Model: **Agile Scrum** + **Clean Architecture**

#### Why Agile Scrum?
1. **Iterative Development:** Build features incrementally
2. **Flexibility:** Adapt to changing requirements
3. **Quick Feedback:** Test and iterate rapidly
4. **Risk Management:** Identify issues early

#### Sprint Structure
- **Sprint Duration:** 1-2 weeks
- **Sprint Planning:** Define features for the sprint
- **Daily Standups:** Track progress (solo: 5-min check-ins)
- **Sprint Review:** Demo completed features
- **Sprint Retrospective:** Improve process

#### Clean Architecture Benefits
1. **Separation of Concerns:** Domain, Data, Presentation layers
2. **Testability:** Easy to unit test business logic
3. **Maintainability:** Changes in UI don't affect business logic
4. **Scalability:** Add features without breaking existing code

---

## 🗃️ Database Schema

### MongoDB Collections

#### 1. Users Collection
```javascript
{
  _id: ObjectId,
  name: String,
  email: String (unique, indexed),
  password: String (hashed),
  photoUrl: String,
  familyId: ObjectId | null,
  role: "admin" | "member",
  createdAt: Date,
  updatedAt: Date
}
```

#### 2. Families Collection
```javascript
{
  _id: ObjectId,
  name: String,
  inviteCode: String (unique, 6-char),
  adminId: ObjectId (User ref),
  members: [ObjectId] (User refs),
  createdAt: Date,
  updatedAt: Date
}
```

#### 3. Documents Collection
```javascript
{
  _id: ObjectId,
  familyId: ObjectId,
  uploadedBy: ObjectId (User),
  title: String,
  description: String,
  category: "medical" | "insurance" | "education" | "id" | "other",
  fileUrl: String (Cloudinary URL),
  fileType: "pdf" | "image" | "document",
  fileSize: Number (bytes),
  tags: [String],
  sharedWith: [ObjectId] (specific members, or "all"),
  uploadedAt: Date
}
```

#### 4. Expenses Collection
```javascript
{
  _id: ObjectId,
  familyId: ObjectId,
  addedBy: ObjectId (User),
  amount: Number,
  category: "groceries" | "utilities" | "healthcare" | "education" | "entertainment" | "other",
  description: String,
  date: Date,
  splitAmong: [
    {
      memberId: ObjectId,
      shareAmount: Number
    }
  ],
  attachments: [String] (receipt images),
  createdAt: Date
}
```

#### 5. Events Collection
```javascript
{
  _id: ObjectId,
  familyId: ObjectId,
  createdBy: ObjectId (User),
  title: String,
  description: String,
  eventDate: Date,
  location: String,
  attendees: [
    {
      memberId: ObjectId,
      rsvp: "yes" | "no" | "maybe"
    }
  ],
  createdAt: Date
}
```

---

## 🔌 API Documentation

### Authentication Endpoints

#### POST `/api/auth/register`
**Description:** Register a new user

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "securepass123"
}
```

**Response (201):**
```json
{
  "_id": "507f1f77bcf86cd799439011",
  "name": "John Doe",
  "email": "john@example.com",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### POST `/api/auth/login`
**Description:** Login existing user

**Request Body:**
```json
{
  "email": "john@example.com",
  "password": "securepass123"
}
```

**Response (200):**
```json
{
  "_id": "507f1f77bcf86cd799439011",
  "name": "John Doe",
  "email": "john@example.com",
  "familyId": "...",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Family Endpoints (To be implemented)

#### POST `/api/families/create`
**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "name": "The Smiths"
}
```

**Response (201):**
```json
{
  "_id": "...",
  "name": "The Smiths",
  "inviteCode": "SM1TH5",
  "admin": "...",
  "members": ["..."]
}
```

#### POST `/api/families/join`
**Headers:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "inviteCode": "SM1TH5"
}
```

### Document Endpoints (To be implemented)

#### POST `/api/documents/upload`
**Headers:** 
- `Authorization: Bearer <token>`
- `Content-Type: multipart/form-data`

**Request:**
```
file: (binary)
title: "Medical Report"
category: "medical"
description: "Annual checkup results"
```

#### GET `/api/documents/:familyId`
**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
[
  {
    "_id": "...",
    "title": "Medical Report",
    "category": "medical",
    "fileUrl": "https://cloudinary.com/.../report.pdf",
    "uploadedAt": "2026-01-29T..."
  }
]
```

---

## 🔒 Security & Privacy

### Authentication Security
1. **Password Hashing:** bcrypt with salt rounds (10)
2. **JWT Tokens:** Expire after 30 days
3. **HTTPS:** All API communication encrypted
4. **Input Validation:** Prevent SQL/NoSQL injection

### Data Privacy
1. **Family Isolation:** Users can only access their family's data
2. **Role-Based Access:** Admin vs Member permissions
3. **Document Privacy:** Control who sees specific documents
4. **Secure Storage:** Files encrypted in Cloudinary

### Best Practices
- Environment variables for secrets (.env)
- CORS configuration for API
- Rate limiting on endpoints
- Regular security audits

---

## 🚀 Future Scope

### Version 2.0 Features
1. **AI-Powered Features**
   - Smart document categorization
   - OCR with text extraction
   - Expense prediction and budgeting AI

2. **Advanced Analytics**
   - Spending patterns and insights
   - Family activity dashboard
   - Data visualization

3. **Social Features**
   - Family chat/messaging
   - Photo albums and sharing
   - Family tree builder

4. **Integrations**
   - Google Calendar sync
   - Bank account linking for expenses
   - Cloud backup (Google Drive, Dropbox)

5. **Multi-Platform**
   - Web app (React/Next.js)
   - Desktop app (Electron)

### Monetization Strategy
1. Premium subscriptions
2. Enterprise family plans (10+ members)
3. White-label solutions for organizations
4. API access for third-party apps

---

## 📊 Project Timeline

```
Jan 2026  |━━━━━━━━━━| Phase 1: Foundation ✅
Feb 2026  |━━━━━━━━━━| Phase 2: Family & Docs 🟡
Mar 2026  |━━━━━━━━━━| Phase 3: Expenses
Apr 2026  |━━━━━━━━━━| Phase 4: Advanced Features
May 2026  |━━━━━━━━━━| Phase 5: Testing & Launch
Jun 2026  |━━━━━━━━━━| Production Release 🎉
```

---

## 👥 Team & Roles

**Current Team Size:** 1 (Solo Developer)

**Roles:**
- Full-Stack Developer
- UI/UX Designer
- Database Administrator
- DevOps Engineer
- QA Tester

**Future Team (If Scaled):**
- 1 Backend Developer
- 1 Mobile Developer
- 1 UI/UX Designer
- 1 Project Manager

---

## 📞 Contact & Support

**Developer:** Jeel Kanani  
**Project Repository:** https://github.com/Jeel-Kanani/FamilySphere (if public)  
**Email:** support@familysphere.com (placeholder)

---

## 📄 License

**License Type:** MIT License (or Proprietary for commercial use)

---

**Last Updated:** January 29, 2026  
**Version:** 1.0.0  
**Status:** In Active Development
