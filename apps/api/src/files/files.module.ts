import { Module } from '@nestjs/common';
import { FilesController } from './files.controller';
import { FilesService } from './files.service';
import { S3PresignService } from './s3-presign.service';

@Module({
  controllers: [FilesController],
  providers: [FilesService, S3PresignService],
  exports: [FilesService],
})
export class FilesModule {}
