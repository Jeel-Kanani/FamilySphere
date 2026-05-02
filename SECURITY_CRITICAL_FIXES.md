# FamilySphere Security - CRITICAL FIXES REQUIRED IMMEDIATELY

## 🔴 DO NOT DEPLOY WITHOUT THESE FIXES

### Fix #1: Protect Admin Routes (5 minutes)
**File:** `backend/src/routes/adminRoutes.ts`

```typescript
import { Router } from 'express';
import { protect, authorize } from '../middleware/authMiddleware';
import { getEngineDashboard, adminRequeueStuck, getDocumentFullDetail } from '../controllers/adminController';

const router = Router();

// ADD THESE TWO LINES:
router.use(protect);
router.use(authorize('admin'));

router.get('/engine-dashboard', getEngineDashboard);
router.post('/requeue-stuck', adminRequeueStuck);
router.get('/doc/:id/full', getDocumentFullDetail);

export default router;
```

---

### Fix #2: Protect Vault Routes (5 minutes)
**File:** `backend/src/routes/vaultRoutes.ts`

```typescript
import express from 'express';
import { protect, authorize } from '../middleware/authMiddleware';
import { uploadDocument, getDocuments, deleteDocument } from '../controllers/documentController';

const router = express.Router();

// ADD THESE THREE LINES:
router.use(protect);
router.post('/upload', authorize('admin', 'member'), uploadDocument);
router.get('/', getDocuments);
router.delete('/:id', authorize('admin', 'member'), deleteDocument);

export default router;
```

---

### Fix #3: Fix CORS Configuration (10 minutes)
**File:** `backend/src/server.ts`

**Replace:**
```typescript
app.use(cors());
```

**With:**
```typescript
const corsOptions = {
    origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 86400
};

app.use(cors(corsOptions));
```

**Add to `.env`:**
```env
CORS_ORIGIN=http://localhost:3000,http://localhost:3001
```

---

### Fix #4: Fix Socket.io CORS (5 minutes)
**File:** `backend/src/services/socketService.ts`

**Replace:**
```typescript
const io = new Server(server, {
    cors: {
        origin: '*',
        methods: ['GET', 'POST'],
    },
});
```

**With:**
```typescript
const corsOptions = {
    origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
    methods: ['GET', 'POST'],
    credentials: true
};

const io = new Server(server, { cors: corsOptions });
```

---

## Quick Checklist
- [ ] Fix admin routes
- [ ] Fix vault routes  
- [ ] Fix CORS
- [ ] Fix Socket.io CORS
- [ ] Add `.env` CORS_ORIGIN variable
- [ ] Test each endpoint is now protected
- [ ] Deploy

**Total Time to Fix:** ~25 minutes  
**Risk if Not Fixed:** 🔴 CRITICAL - Complete data breach possible

---

## Verification Commands

```bash
# Test admin endpoint (should now fail without auth)
curl http://localhost:5000/api/admin/engine-dashboard
# Expected: 401 Unauthorized

# Test with Bearer token (should work)
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:5000/api/admin/engine-dashboard
# Expected: 200 OK

# Test vault endpoint (should now fail without auth)
curl http://localhost:5000/api/vault/
# Expected: 401 Unauthorized

# Test CORS (different origin should be rejected)
curl -H "Origin: http://evil.com" http://localhost:5000/api/auth/me -H "Authorization: Bearer TOKEN"
# Expected: CORS error or rejection
```

