import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type PushMessage = {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

export type PushSendResult = {
  provider: 'IN_APP_ONLY' | 'ONESIGNAL';
  status: 'SKIPPED' | 'FAILED';
  disableDevice: false;
  failureCode?: string;
  response: Record<string, unknown>;
};

@Injectable()
export class PushDeliveryService {
  constructor(private readonly config: ConfigService) {}

  async send(message: PushMessage): Promise<PushSendResult> {
    const provider = this.config.get<string>('PUSH_PROVIDER')?.trim().toLowerCase() || 'in_app_only';

    if (provider === 'onesignal') {
      return this.sendWithOneSignal(message);
    }

    return {
      provider: 'IN_APP_ONLY',
      status: 'SKIPPED',
      disableDevice: false,
      response: {
        reason: 'OS push delivery is disabled. Notification is available in the in-app inbox.',
        tokenPlatform: inferTokenPlatform(message.token),
        title: message.title,
      },
    };
  }

  private async sendWithOneSignal(message: PushMessage): Promise<PushSendResult> {
    const appId = this.config.get<string>('ONESIGNAL_APP_ID')?.trim();
    const restApiKey = this.config.get<string>('ONESIGNAL_REST_API_KEY')?.trim();
    const missing = [
      !appId ? 'ONESIGNAL_APP_ID' : null,
      !restApiKey ? 'ONESIGNAL_REST_API_KEY' : null,
    ].filter(Boolean);

    return {
      provider: 'ONESIGNAL',
      status: 'FAILED',
      disableDevice: false,
      failureCode: missing.length > 0 ? 'PUSH_PROVIDER_NOT_CONFIGURED' : 'PUSH_PROVIDER_ADAPTER_PENDING',
      response: {
        reason:
          missing.length > 0
            ? 'OneSignal push delivery is selected, but required server-side credentials are missing.'
            : 'OneSignal credentials are configured, but the provider HTTP adapter is intentionally pending.',
        missing,
        tokenPlatform: inferTokenPlatform(message.token),
        title: message.title,
      },
    };
  }
}

function inferTokenPlatform(token: string) {
  if (token.startsWith('ios')) {
    return 'ios';
  }

  if (token.startsWith('web')) {
    return 'web';
  }

  return 'android';
}
