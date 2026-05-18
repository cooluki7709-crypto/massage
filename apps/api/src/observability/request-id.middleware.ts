import { randomUUID } from 'crypto';

type RequestLike = {
  method?: string;
  originalUrl?: string;
  url?: string;
  headers?: Record<string, string | string[] | undefined>;
  requestId?: string;
};

type ResponseLike = {
  statusCode?: number;
  setHeader(name: string, value: string): void;
  on(event: 'finish', callback: () => void): void;
};

type Next = () => void;

export function requestIdMiddleware(req: RequestLike, res: ResponseLike, next: Next) {
  const incoming = req.headers?.['x-request-id'];
  const requestId = Array.isArray(incoming) ? incoming[0] : incoming || randomUUID();
  const startedAt = Date.now();

  req.requestId = requestId;
  res.setHeader('x-request-id', requestId);

  res.on('finish', () => {
    const log = {
      level: 'info',
      event: 'http_request',
      requestId,
      method: req.method,
      path: req.originalUrl ?? req.url,
      statusCode: res.statusCode,
      durationMs: Date.now() - startedAt,
      userAgent: req.headers?.['user-agent'],
    };
    console.log(JSON.stringify(log));
  });

  next();
}
