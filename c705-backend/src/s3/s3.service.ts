import { Injectable, BadRequestException } from '@nestjs/common';
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

@Injectable()
export class S3Service {
  private s3Client: S3Client;
  private bucketName: string;

  constructor() {
    const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
    const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;

    if (!accessKeyId || !secretAccessKey) {
      throw new Error(
        'AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set in the environment (.env)',
      );
    }

    this.bucketName = process.env.AWS_S3_BUCKET_NAME || 'c705-media';

    this.s3Client = new S3Client({
      region: process.env.AWS_REGION || 'us-east-2',
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });
  }

  /**
   * Upload a file to S3
   * @param file - File buffer or stream
   * @param key - S3 object key (path/filename)
   * @param contentType - MIME type of the file
   * @returns URL of the uploaded file
   */
  async uploadFile(
    file: Buffer | Uint8Array,
    key: string,
    contentType?: string,
  ): Promise<string> {
    try {
      const command = new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        Body: file,
        ContentType: contentType,
      });

      await this.s3Client.send(command);

      // Return the public URL
      return `https://${this.bucketName}.s3.${process.env.AWS_REGION || 'us-east-2'}.amazonaws.com/${key}`;
    } catch (error) {
      throw new BadRequestException(`Failed to upload file: ${error.message}`);
    }
  }

  /**
   * Upload a file with public read access
   * @param file - File buffer or stream
   * @param key - S3 object key (path/filename)
   * @param contentType - MIME type of the file
   * @returns URL of the uploaded file
   */
  async uploadPublicFile(
    file: Buffer | Uint8Array,
    key: string,
    contentType?: string,
  ): Promise<string> {
    try {
      const command = new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        Body: file,
        ContentType: contentType,
        ACL: 'public-read',
      });

      await this.s3Client.send(command);

      return `https://${this.bucketName}.s3.${process.env.AWS_REGION || 'us-east-2'}.amazonaws.com/${key}`;
    } catch (error) {
      throw new BadRequestException(`Failed to upload file: ${error.message}`);
    }
  }

  /**
   * Get a presigned URL for downloading a file (valid for 1 hour)
   * @param key - S3 object key
   * @param expiresIn - Expiration time in seconds (default: 3600 = 1 hour)
   * @returns Presigned URL
   */
  async getPresignedUrl(key: string, expiresIn: number = 3600): Promise<string> {
    try {
      const command = new GetObjectCommand({
        Bucket: this.bucketName,
        Key: key,
      });

      const url = await getSignedUrl(this.s3Client, command, { expiresIn });
      return url;
    } catch (error) {
      throw new BadRequestException(`Failed to generate presigned URL: ${error.message}`);
    }
  }

  /**
   * Delete a file from S3
   * @param key - S3 object key
   */
  async deleteFile(key: string): Promise<void> {
    try {
      const command = new DeleteObjectCommand({
        Bucket: this.bucketName,
        Key: key,
      });

      await this.s3Client.send(command);
    } catch (error) {
      throw new BadRequestException(`Failed to delete file: ${error.message}`);
    }
  }

  /**
   * Check if a file exists in S3
   * @param key - S3 object key
   * @returns true if file exists, false otherwise
   */
  async fileExists(key: string): Promise<boolean> {
    try {
      const command = new HeadObjectCommand({
        Bucket: this.bucketName,
        Key: key,
      });

      await this.s3Client.send(command);
      return true;
    } catch (error) {
      if (error.name === 'NotFound' || error.$metadata?.httpStatusCode === 404) {
        return false;
      }
      throw new BadRequestException(`Failed to check file existence: ${error.message}`);
    }
  }

  /**
   * Generate a unique key for a file based on user ID and timestamp
   * @param userId - User ID
   * @param originalFilename - Original filename
   * @param folder - Optional folder prefix (e.g., 'music', 'beats', 'articles')
   * @returns Generated S3 key
   */
  generateKey(userId: string, originalFilename: string, folder?: string): string {
    const timestamp = Date.now();
    const sanitizedFilename = originalFilename.replace(/[^a-zA-Z0-9.-]/g, '_');
    const folderPrefix = folder ? `${folder}/` : '';
    return `${folderPrefix}${userId}/${timestamp}-${sanitizedFilename}`;
  }
}
