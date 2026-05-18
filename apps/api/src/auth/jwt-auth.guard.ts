import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { AuthenticatedUser } from './auth.types';

type RequestWithHeadersAndUser = {
  headers: Record<string, string | string[] | undefined>;
  user?: AuthenticatedUser;
};

type JwtPayload = {
  sub?: string;
  roles?: Role[];
};

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<RequestWithHeadersAndUser>();
    const token = extractBearerToken(request.headers.authorization);

    if (!token) {
      throw new UnauthorizedException('Bearer token is required');
    }

    const payload = this.jwt.verify<JwtPayload>(token, {
      secret: process.env.JWT_ACCESS_SECRET ?? 'dev-access-secret',
    });

    if (!payload.sub) {
      throw new UnauthorizedException('Invalid token subject');
    }

    request.user = {
      id: payload.sub,
      roles: payload.roles ?? [],
    };

    return true;
  }
}

function extractBearerToken(header: string | string[] | undefined) {
  const value = Array.isArray(header) ? header[0] : header;
  if (!value) {
    return undefined;
  }

  const [scheme, token] = value.split(' ');
  return scheme === 'Bearer' ? token : undefined;
}

