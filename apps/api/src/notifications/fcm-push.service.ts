import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type PushMessage = {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

export type PushSendResult = {
  provider: 'FCM_HTTP_V1' | 'FCM_DISABLED';
  status: 'SENT' | 'SKIPPED' | 'FAILED';
  response: Record<string, unknown>;
};

@Injectable()
export class FcmPushService {
  constructor(private readonly config: ConfigService) {}

  async send(message: PushMessage): Promise<PushSendResult> {
    const projectId = this.config.get<string>('FCM_PROJECT_ID');
    const accessToken = this.config.get<string>('FCM_ACCESS_TOKEN');

    if (!projectId || !accessToken) {
      return {
        provider: 'FCM_DISABLED',
        status: 'SKIPPED',
        response: { reason: 'FCM_PROJECT_ID or FCM_ACCESS_TOKEN is missing' },
      };
    }

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

    return {
      provider: 'FCM_HTTP_V1',
      status: response.ok ? 'SENT' : 'FAILED',
      response: {
        statusCode: response.status,
        body,
      },
    };
  }
}

