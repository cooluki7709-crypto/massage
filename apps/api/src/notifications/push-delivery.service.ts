import { Injectable } from '@nestjs/common';

export type PushMessage = {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

export type PushSendResult = {
  provider: 'IN_APP_ONLY';
  status: 'SKIPPED';
  disableDevice: false;
  failureCode?: string;
  response: Record<string, unknown>;
};

@Injectable()
export class PushDeliveryService {
  async send(message: PushMessage): Promise<PushSendResult> {
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
