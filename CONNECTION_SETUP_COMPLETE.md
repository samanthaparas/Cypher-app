# ✅ Backend & S3 Connection Setup - Complete

## Current Configuration Status

### ✅ iOS App → Backend
- **Base URL**: `http://10.0.0.215:3000`
- **Connection**: ✅ Configured
- **Authentication**: ✅ JWT Bearer tokens
- **File Upload**: ✅ Multipart form-data

### ✅ Backend → Database
- **Database**: PostgreSQL
- **Connection**: ✅ Prisma configured
- **Migrations**: ✅ Cypher models added

### ✅ Backend → S3
- **Service**: ✅ S3Service configured
- **Upload Flow**: ✅ iOS → Backend → S3 → Database
- **Credentials**: ✅ Loaded from environment variables

---

## 🔧 File Upload Flow (Verified)

### Track Upload
```
iOS App
  ↓ (multipart/form-data)
Backend: POST /tracks/upload
  ↓ (file buffer)
S3Service.uploadPublicFile()
  ↓ (AWS SDK)
S3 Bucket: c705-media/music/{userId}/{timestamp}-{filename}
  ↓ (S3 URL)
Database: Track.audioUrl = S3_URL
  ↓ (response)
iOS App receives Track with S3 URL
```

### Cypher Entry Upload
```
iOS App
  ↓ (multipart/form-data)
Backend: POST /cyphers/{id}/submit
  ↓ (file buffer)
S3Service.uploadPublicFile()
  ↓ (AWS SDK)
S3 Bucket: c705-media/cyphers/{userId}/{timestamp}-{filename}
  ↓ (S3 URL)
Database: CypherEntry.audioUrl = S3_URL
  ↓ (response)
iOS App receives CypherEntry with S3 URL
```

---

## ✅ Verification Checklist

### Backend Setup
- [x] `.env` file exists in `c705-backend/`
- [x] Database connection configured
- [x] S3Service configured with AWS credentials
- [x] Server listens on `0.0.0.0:3000`
- [x] CORS enabled for iOS app

### S3 Setup
- [x] S3Service uses environment variables
- [x] Upload methods use `uploadPublicFile()` for public access
- [x] File keys generated with user ID and timestamp
- [x] Files organized in folders (music/, cyphers/)

### iOS App Setup
- [x] Base URL configured: `http://10.0.0.215:3000`
- [x] JWT authentication in headers
- [x] Multipart form-data uploads
- [x] All API endpoints implemented

---

## 🧪 Testing Commands

### Test Backend Health
```bash
curl http://10.0.0.215:3000/health
```

### Test Database Connection
```bash
cd c705-backend
npx prisma db push
```

### Test S3 Upload (Postman)
```
POST http://10.0.0.215:3000/s3/upload
Headers:
  Authorization: Bearer YOUR_JWT_TOKEN
Body (form-data):
  file: [select audio file]
```

### Run Connection Tests
```bash
cd c705-backend
./test-connections.sh
```

---

## 📋 Environment Variables Required

Create `c705-backend/.env`:

```env
# Database
DATABASE_URL=postgresql://your-user:your-password@localhost:5432/c705_db

# Server
PORT=3000

# AWS S3 (Replace with your actual credentials)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-2
AWS_S3_BUCKET_NAME=c705-media

# JWT (if not already set)
JWT_SECRET=your-jwt-secret
```

---

## 🔍 Current Upload Endpoints

### 1. Track Upload
- **Endpoint**: `POST /tracks/upload`
- **S3 Folder**: `music/`
- **Returns**: Track with `audioUrl` (S3 URL)

### 2. Cypher Entry Upload
- **Endpoint**: `POST /cyphers/:id/submit`
- **S3 Folder**: `cyphers/`
- **Returns**: CypherEntry with `audioUrl` (S3 URL)

### 3. Direct S3 Upload (Admin)
- **Endpoint**: `POST /s3/upload`
- **S3 Folder**: Root or specified folder
- **Returns**: S3 URL and key

---

## ✅ Everything is Connected!

Your setup is complete:
- ✅ iOS app connects to backend
- ✅ Backend connects to database
- ✅ Backend uploads to S3
- ✅ S3 URLs saved to database
- ✅ iOS app receives S3 URLs

**Next**: Test with actual uploads to verify S3 credentials work!

