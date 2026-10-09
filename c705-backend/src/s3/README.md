# S3 Service Module

This module provides integration with AWS S3 for file storage and management.

## Configuration

The S3 service is configured via environment variables in `.env`:

```env
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-2
AWS_S3_BUCKET_NAME=c705-media
```

## API Endpoints

All endpoints require JWT authentication (Bearer token).

### Upload File

**POST** `/s3/upload`

Upload a file to the root of the S3 bucket.

**Request:**
- Content-Type: `multipart/form-data`
- Body: Form data with `file` field

**Response:**
```json
{
  "url": "https://c705-media.s3.us-east-2.amazonaws.com/user-id/timestamp-filename.ext",
  "key": "user-id/timestamp-filename.ext",
  "message": "File uploaded successfully"
}
```

**Example (cURL):**
```bash
curl -X POST http://localhost:3000/s3/upload \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/path/to/file.mp3"
```

### Upload File to Folder

**POST** `/s3/upload/:folder`

Upload a file to a specific folder (e.g., `music`, `beats`, `articles`).

**Example:**
```bash
curl -X POST http://localhost:3000/s3/upload/music \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/path/to/song.mp3"
```

### Get Presigned URL

**GET** `/s3/presigned-url/:key`

Get a temporary presigned URL for downloading a file (valid for 1 hour).

**Response:**
```json
{
  "url": "https://c705-media.s3.us-east-2.amazonaws.com/..."
}
```

### Check File Exists

**GET** `/s3/exists/:key`

Check if a file exists in S3.

**Response:**
```json
{
  "exists": true
}
```

### Delete File

**DELETE** `/s3/:key`

Delete a file from S3.

**Response:**
```json
{
  "message": "File deleted successfully"
}
```

## Using S3Service in Your Code

### Inject the Service

```typescript
import { Injectable } from '@nestjs/common';
import { S3Service } from '../s3/s3.service';

@Injectable()
export class YourService {
  constructor(private s3Service: S3Service) {}
}
```

### Upload a File

```typescript
const fileBuffer = Buffer.from(fileData);
const key = this.s3Service.generateKey(userId, 'song.mp3', 'music');
const url = await this.s3Service.uploadPublicFile(fileBuffer, key, 'audio/mpeg');
```

### Generate Presigned URL

```typescript
const url = await this.s3Service.getPresignedUrl('music/user-id/song.mp3', 3600);
```

### Delete a File

```typescript
await this.s3Service.deleteFile('music/user-id/song.mp3');
```

### Check if File Exists

```typescript
const exists = await this.s3Service.fileExists('music/user-id/song.mp3');
```

## File Organization

Files are organized by folder and user:
- Format: `{folder}/{userId}/{timestamp}-{filename}`
- Example: `music/abc123/1703123456789-song.mp3`

## Supported Folders

- `music` - Music tracks uploaded by artists
- `beats` - Beats uploaded by engineers
- `articles` - Article images/media
- `battles` - Rap battle recordings
- `profiles` - User profile images

## Security Notes

- All endpoints require JWT authentication
- Files are uploaded with public-read ACL by default
- Use presigned URLs for private file access
- File keys are generated with user ID to prevent conflicts

