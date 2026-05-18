type RequestLike = {
  headers?: Record<string, string | string[] | undefined>;
};

type ResponseLike = {
  setHeader(name: string, value: string): void;
};

type Next = () => void;

export function securityHeadersMiddleware(_req: RequestLike, res: ResponseLike, next: Next) {
  res.setHeader('x-content-type-options', 'nosniff');
  res.setHeader('x-frame-options', 'DENY');
  res.setHeader('referrer-policy', 'no-referrer');
  res.setHeader('permissions-policy', 'camera=(), microphone=(), geolocation=()');
  res.setHeader('content-security-policy', "default-src 'none'; frame-ancestors 'none'");

  if (process.env.NODE_ENV === 'production') {
    res.setHeader('strict-transport-security', 'max-age=15552000; includeSubDomains');
  }

  next();
}
