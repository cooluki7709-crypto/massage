import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { FileVisibility, Role } from '@prisma/client';
import { randomUUID } from 'crypto';
import { AuthenticatedUser } from '../auth/auth.types';
import { PrismaService } from '../prisma/prisma.service';
import { S3PresignService } from './s3-presign.service';

type PresignInput = {
  contentType: string;
  visibility: FileVisibility;
  purpose: 'provider-verification' | 'provider-gallery' | 'chat-attachment' | 'profile-image';
  providerVerificationId?: string;
};

@Injectable()
export class FilesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly s3: S3PresignService,
  ) {}

  async createPresignedUpload(user: AuthenticatedUser, input: PresignInput) {
    const providerVerificationId = await this.resolveProviderVerificationId(user, input);
    this.validateUploadRequest(user, { ...input, providerVerificationId });

    const extension = extensionForContentType(input.contentType);
    const key = `${input.purpose}/${new Date().toISOString().slice(0, 10)}/${randomUUID()}${extension}`;

    const file = await this.prisma.fileAsset.create({
      data: {
        key,
        contentType: input.contentType,
        visibility: input.visibility,
        providerVerificationId,
        url: input.visibility === FileVisibility.PUBLIC ? this.s3.publicUrl(key) : null,
      },
    });
    const presignedPutUrl = this.s3.presign({ method: 'PUT', key, expiresInSeconds: 900 });

    return {
      file,
      upload: {
        method: 'PUT',
        url: presignedPutUrl ?? `/storage-upload-placeholder/${key}`,
        headers: {
          'content-type': input.contentType,
        },
      },
      storageMode: this.s3.storageMode(),
      note: this.s3.configurationNote(),
    };
  }

  async createReadUrl(user: AuthenticatedUser, fileId: string) {
    const file = await this.prisma.fileAsset.findUnique({
      where: { id: fileId },
      include: { providerVerification: { include: { providerProfile: true } } },
    });
    if (!file) {
      throw new NotFoundException('File not found');
    }

    if (file.visibility === FileVisibility.PUBLIC) {
      return {
        file,
        read: { method: 'GET', url: file.url ?? this.s3.publicUrl(file.key) },
        storageMode: 'public',
      };
    }

    const canRead =
      user.roles.includes(Role.ADMIN) ||
      (user.roles.includes(Role.PROVIDER) && file.providerVerification?.providerProfile.userId === user.id);
    if (!canRead) {
      throw new ForbiddenException('You do not have access to this file');
    }

    const presignedGetUrl = this.s3.presign({ method: 'GET', key: file.key, expiresInSeconds: 300 });
    return {
      file,
      read: { method: 'GET', url: presignedGetUrl ?? `/storage-read-placeholder/${file.key}` },
      storageMode: this.s3.storageMode(),
    };
  }

  private async resolveProviderVerificationId(user: AuthenticatedUser, input: PresignInput) {
    if (input.purpose !== 'provider-verification') {
      return input.providerVerificationId;
    }
    if (input.providerVerificationId && user.roles.includes(Role.ADMIN)) {
      return input.providerVerificationId;
    }

    const provider = await this.prisma.providerProfile.findUnique({
      where: { userId: user.id },
      include: { verification: true },
    });
    if (!provider) {
      return input.providerVerificationId;
    }

    if (provider.verification) {
      return provider.verification.id;
    }

    const verification = await this.prisma.providerVerification.create({
      data: { providerProfileId: provider.id },
    });
    return verification.id;
  }

  private validateUploadRequest(user: AuthenticatedUser, input: PresignInput) {
    if (!input.contentType.startsWith('image/') && !input.contentType.startsWith('video/')) {
      throw new BadRequestException('Only image and video uploads are allowed in MVP');
    }

    if (input.purpose === 'provider-verification') {
      if (!user.roles.includes(Role.PROVIDER) && !user.roles.includes(Role.ADMIN)) {
        throw new BadRequestException('Provider verification uploads require provider or admin role');
      }
      if (input.visibility !== FileVisibility.PRIVATE) {
        throw new BadRequestException('Provider verification files must be private');
      }
      if (!input.providerVerificationId) {
        throw new BadRequestException('providerVerificationId is required for provider verification files');
      }
    }
  }
}

function extensionForContentType(contentType: string) {
  if (contentType === 'image/png') {
    return '.png';
  }
  if (contentType === 'image/webp') {
    return '.webp';
  }
  if (contentType === 'video/mp4') {
    return '.mp4';
  }
  return '.jpg';
}
