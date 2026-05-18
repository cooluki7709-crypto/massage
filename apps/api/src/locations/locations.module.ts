import { Module } from '@nestjs/common';
import { LocationsGateway } from './locations.gateway';

@Module({ providers: [LocationsGateway] })
export class LocationsModule {}

