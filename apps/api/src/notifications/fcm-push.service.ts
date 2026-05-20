import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';

export type PushMessage = {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

export type PushSendResult = {
  provider: 'FCM_HTTP_V1' | 'FCM_DISABLED';
  status: 'SENT' | 'SKIPPED' | 'FAILED';
  disableDevice: boolean;
  failureCode?: string;
  response: Record<string, unknown>;
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
  token_uri?: string;
};

@Injectable()
export class FcmPushService {
  private cachedAccessToken: { token: string; expiresAt: number } | null = null;

  constructor(private readonly config: ConfigService) {}

  async send(message: PushMessage): Promise<PushSendResult> {
    const projectId = this.config.get<string>('FCM_PROJECT_ID');
    if (!projectId || !this.hasCredentialsConfigured()) {
      return {
        provider: 'FCM_DISABLED',
        status: 'SKIPPED',
        disableDevice: false,
        response: { reason: 'FCM_PROJECT_ID and either FCM_ACCESS_TOKEN or service account credentials are required' },
      };
    }

    let accessToken: string | null;
    try {
      accessToken = await this.getAccessToken();
    } catch (error) {
      return {
        provider: 'FCM_HTTP_V1',
        status: 'FAILED',
        disableDevice: false,
        response: {
          phase: 'token',
          error: error instanceof Error ? error.message : 'Unknown token error',
        },
      };
    }

    if (!accessToken) {
      return {
        provider: 'FCM_HTTP_V1',
        status: 'FAILED',
        disableDevice: false,
        response: {
          phase: 'token',
          error: 'Unable to acquire FCM access token',
        },
      };
    }

    try {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${accessToken}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: message.token,
            notification: {
              title: message.title,
              body: message.body,
            },
            data: message.data,
          },
        }),
      });

      const body = (await response.json().catch(() => ({}))) as Record<string, unknown>;
      const failureCode = readFcmFailureCode(body);

      return {
        provider: 'FCM_HTTP_V1',
        status: response.ok ? 'SENT' : 'FAILED',
        disableDevice: isPermanentTokenFailure(response.status, failureCode),
        failureCode,
        response: {
          statusCode: response.status,
          body,
        },
      };
    } catch (error) {
      return {
        provider: 'FCM_HTTP_V1',
        status: 'FAILED',
        disableDevice: false,
        response: {
          phase: 'send',
          error: error instanceof Error ? error.message : 'Unknown send error',
        },
      };
    }
  }

  private async getAccessToken() {
    const directAccessToken = this.config.get<string>('FCM_ACCESS_TOKEN');
    if (directAccessToken) {
      return directAccessToken;
    }

    const now = Date.now();
    if (this.cachedAccessToken && this.cachedAccessToken.expiresAt > now + 60_000) {
      return this.cachedAccessToken.token;
    }

    const serviceAccount = this.loadServiceAccount();
    if (!serviceAccount) {
      return null;
    }

    const issuedAt = Math.floor(now / 1000);
    const expiresAt = issuedAt + 3600;
    const assertion = signJwt(serviceAccount, issuedAt, expiresAt);
    const tokenUri = serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token';

    const response = await fetch(tokenUri, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    });

    const body = (await response.json().catch(() => ({}))) as {
      access_token?: string;
      expires_in?: number;
    };

    if (!response.ok || !body.access_token) {
      return null;
    }

    this.cachedAccessToken = {
      token: body.access_token,
      expiresAt: now + (body.expires_in ?? 3600) * 1000,
    };
    return this.cachedAccessToken.token;
  }

  private loadServiceAccount(): ServiceAccount | null {
    const inlineJson = this.config.get<string>('FCM_SERVICE_ACCOUNT_JSON');
    if (inlineJson) {
      return JSON.parse(inlineJson) as ServiceAccount;
    }

    const base64Json = this.config.get<string>('FCM_SERVICE_ACCOUNT_JSON_BASE64');
    if (base64Json) {
      return JSON.parse(Buffer.from(base64Json, 'base64').toString('utf8')) as ServiceAccount;
    }

    const filePath = this.config.get<string>('FCM_SERVICE_ACCOUNT_FILE');
    if (filePath) {
      return JSON.parse(readFileSync(filePath, 'utf8')) as ServiceAccount;
    }

    return null;
  }

  private hasCredentialsConfigured() {
    return Boolean(
      this.config.get<string>('FCM_ACCESS_TOKEN') ||
        this.config.get<string>('FCM_SERVICE_ACCOUNT_FILE') ||
        this.config.get<string>('FCM_SERVICE_ACCOUNT_JSON') ||
        this.config.get<string>('FCM_SERVICE_ACCOUNT_JSON_BASE64'),
    );
  }
}

function signJwt(serviceAccount: ServiceAccount, issuedAt: number, expiresAt: number) {
  const header = encodeBase64Url({ alg: 'RS256', typ: 'JWT' });
  const payload = encodeBase64Url({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: issuedAt,
    exp: expiresAt,
  });
  const unsignedToken = `${header}.${payload}`;
  const signer = createSign('RSA-SHA256');
  signer.update(unsignedToken);
  signer.end();
  const signature = signer.sign(serviceAccount.private_key, 'base64url');
  return `${unsignedToken}.${signature}`;
}

function encodeBase64Url(value: unknown) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function readFcmFailureCode(body: Record<string, unknown>) {
  const error = body.error;
  if (!error || typeof error !== 'object' || Array.isArray(error)) {
    return undefined;
  }

  const details = (error as { details?: unknown }).details;
  if (!Array.isArray(details)) {
    return undefined;
  }

  for (const detail of details) {
    if (!detail || typeof detail !== 'object' || Array.isArray(detail)) {
      continue;
    }

    const errorCode = (detail as { errorCode?: unknown }).errorCode;
    if (typeof errorCode === 'string' && errorCode.length > 0) {
      return errorCode;
    }
  }

  return undefined;
}

function isPermanentTokenFailure(statusCode: number, failureCode?: string) {
  if (!failureCode) {
    return false;
  }

  if (failureCode === 'UNREGISTERED') {
    return true;
  }

  return statusCode === 400 && failureCode === 'INVALID_ARGUMENT';
}
