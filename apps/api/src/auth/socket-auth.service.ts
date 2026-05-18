import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { Socket } from 'socket.io';
import { AuthenticatedUser } from './auth.types';

type JwtPayload = {
  sub?: string;
  roles?: Role[];
};

export type AuthenticatedSocket = Socket & {
  data: {
    user?: AuthenticatedUser;
  };
};

@Injectable()
export class SocketAuthService {
  constructor(private readonly jwt: JwtService) {}

  authenticate(client: Socket): AuthenticatedUser {
    const token = extractSocketToken(client);
    if (!token) {
      throw new UnauthorizedException('Socket bearer token is required');
    }

    const payload = this.jwt.verify<JwtPayload>(token, {
      secret: process.env.JWT_ACCESS_SECRET ?? 'dev-access-secret',
    });

    if (!payload.sub) {
      throw new UnauthorizedException('Invalid socket token subject');
    }

    const user = {
      id: payload.sub,
      roles: payload.roles ?? [],
    };

    (client as AuthenticatedSocket).data.user = user;
    return user;
  }

  requireUser(client: Socket): AuthenticatedUser {
    const user = (client as AuthenticatedSocket).data.user;
    if (!user) {
      throw new UnauthorizedException('Authenticated socket user is required');
    }
    return user;
  }
}

function extractSocketToken(client: Socket) {
  const authToken = client.handshake.auth?.token;
  if (typeof authToken === 'string' && authToken.length > 0) {
    return stripBearer(authToken);
  }

  const header = client.handshake.headers.authorization;
  if (typeof header === 'string') {
    return stripBearer(header);
  }

  return undefined;
}

function stripBearer(value: string) {
  const [scheme, token] = value.split(' ');
  return scheme === 'Bearer' ? token : value;
}

