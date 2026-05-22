import { Controller, Get } from '@nestjs/common';
import { HealthService } from './health.service';

@Controller()
export class HealthController {
  constructor(private readonly health: HealthService) {}

  @Get('health')
  healthcheck() {
    return this.health.healthcheck();
  }

  @Get('health/ready')
  readiness() {
    return this.health.readiness();
  }

  @Get('health/external')
  externalReadiness() {
    return this.health.externalReadiness();
  }
}
