# Backend & S3 Connection Verification Guide

This guide helps you verify that your iOS app, backend, and S3 are all properly connected.

## ✅ Current Configuration

### iOS App (APIService.swift)
- **Base URL**: `http://10.0.0.215:3000`
- **Connection**: Configured for both Simulator and Physical Device
- **Authentication**: JWT Bearer tokens

### Backend (NestJS)
- **Port**: `3000` (configurable via `PORT` env variable)
- **Host**: `0.0.0.0` (listens on all network interfaces)
- **CORS**: Enabled for all origins (development)
- **Database**: PostgreSQL via Prisma

### S3 Service
- **Bucket**: `c705-media` (default, configurable via `AWS_S3_BUCKET_NAME`)
- **Region**: `us-east-2` (configurable via `AWS_REGION`)
- **Credentials**: Loaded from environment variables

---

## 🔧 Setup Steps

### Step 1: Backend Environment Variables

Create a `.env` file in `c705-backend/` directory:

```env
# Database
DATABASE_URL=postgresql://your-user:your-password@localhost:5432/c705_db

# Server
PORT=3000

# AWS S3 Configuration
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-2
AWS_S3_BUCKET_NAME=c705-media
```

**⚠️ Important**: Replace the AWS credentials with your actual S3 credentials if different.

### Step 2: Verify S3 Bucket Exists

1. Go to AWS Console → S3
2. Verify bucket `c705-media` exists (or your configured bucket name)
3. Check bucket permissions:
   - Public read access for uploaded files (or use presigned URLs)
   - Write access for your AWS credentials

### Step 3: Test Backend Connection

```bash
cd c705-backend
npm run start:dev
```

You should see:
```
🚀 Server is running on: http://0.0.0.0:3000
   Local access: http://localhost:3000
   Network access: http://10.0.0.215:3000
```

### Step 4: Test S3 Connection from Backend

Test S3 upload via Postman:

```bash
POST http://10.0.0.215:3000/s3/upload
Headers:
  Authorization: Bearer YOUR_JWT_TOKEN
Body (form-data):
  file: [select an audio file]
```

Expected response:
```json
{
  "url": "https://c705-media.s3.us-east-2.amazonaws.com/music/user-id/timestamp-filename.mp3",
  "key": "music/user-id/timestamp-filename.mp3",
  "message": "File uploaded successfully"
}
```

### Step 5: Test iOS App Connection

1. Open iOS app in Xcode
2. Check console logs for:
   - `📤 Making request to: http://10.0.0.215:3000/...`
   - `📥 Response Status: 200`

---

## 🔍 Verification Checklist

### Backend → Database
- [ ] Prisma migrations run successfully
- [ ] Database connection works
- [ ] Can create/read users, tracks, cyphers

### Backend → S3
- [ ] S3 credentials are correct
- [ ] Bucket exists and is accessible
- [ ] Upload test file succeeds
- [ ] File URL is returned correctly

### iOS App → Backend
- [ ] Base URL matches your Mac's IP (`10.0.0.215`)
- [ ] Can login/signup
- [ ] Can fetch data (tracks, cyphers, etc.)
- [ ] Can upload files (tracks, cypher entries)

### File Upload Flow
- [ ] iOS app uploads to backend endpoint
- [ ] Backend receives file
- [ ] Backend uploads to S3
- [ ] S3 URL saved to database
- [ ] iOS app receives S3 URL in response

---

## 🐛 Troubleshooting

### Issue: "Cannot connect to server"
**Solution:**
1. Verify backend is running: `npm run start:dev`
2. Check Mac's IP hasn't changed: `ipconfig getifaddr en0`
3. Update `baseURL` in `APIService.swift` if IP changed
4. Ensure iOS device/simulator is on same WiFi network

### Issue: "S3 upload fails"
**Solution:**
1. Verify AWS credentials in `.env` file
2. Check bucket name matches
3. Verify bucket permissions allow uploads
4. Check AWS region is correct

### Issue: "401 Unauthorized"
**Solution:**
1. Verify JWT token is being sent in Authorization header
2. Check token hasn't expired
3. Ensure user is logged in

### Issue: "File upload succeeds but URL doesn't work"
**Solution:**
1. Check S3 bucket has public-read ACL enabled
2. Or use presigned URLs for private files
3. Verify S3 URL format is correct

---

## 📝 Current Upload Endpoints

### Tracks Upload
- **Endpoint**: `POST /tracks/upload`
- **Flow**: iOS → Backend → S3 → Database
- **S3 Folder**: `music/`
- **Returns**: Track with S3 URL

### Cypher Entry Upload
- **Endpoint**: `POST /cyphers/:id/submit`
- **Flow**: iOS → Backend → S3 → Database
- **S3 Folder**: `cyphers/`
- **Returns**: CypherEntry with S3 URL

---

## ✅ Verification Commands

### Test Backend Health
```bash
curl http://10.0.0.215:3000/health
```

### Test Database Connection
```bash
cd c705-backend
npx prisma db push
```

### Test S3 Upload (requires auth token)
```bash
curl -X POST http://10.0.0.215:3000/s3/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@test.mp3"
```

---

## 🎯 Next Steps

1. **Create `.env` file** in `c705-backend/` with your actual AWS credentials
2. **Test S3 upload** via Postman to verify credentials work
3. **Test iOS app** connection and file uploads
4. **Monitor backend logs** for any S3 errors
5. **Verify files appear** in your S3 bucket after uploads

---

## 📞 Support

If you encounter issues:
1. Check backend console logs
2. Check iOS Xcode console logs
3. Verify AWS S3 bucket permissions
4. Test each component individually (backend → S3, iOS → backend)

