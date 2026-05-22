# Storage

## MVP Contract

The API exposes `POST /api/files/presign` to create a `FileAsset` record and return an upload contract:

- `file` - database record with key, content type, visibility, and CDN/private metadata.
- `upload.method` - currently `PUT`.
- `upload.url` - S3/R2-compatible presigned PUT URL when storage env vars are configured.
- `upload.headers` - client must send matching `content-type`.
- `storageMode` - `s3-compatible-presigned`, `supabase-storage-s3`, or `placeholder`.

## Visibility

- `PRIVATE` - provider verification IDs, passports, private moderation materials.
- `PUBLIC` - provider gallery/profile media intended for CDN.

## Storage Providers

Set `STORAGE_PROVIDER`, `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY`, and `S3_SECRET_KEY` to enable SigV4 presigned PUT/GET URLs. `S3_PUBLIC_BASE_URL` can point at a CDN or public bucket domain for public assets.

Local development defaults to MinIO:

```dotenv
STORAGE_PROVIDER=s3-compatible
S3_ENDPOINT=http://localhost:9000
S3_REGION=auto
S3_BUCKET=massage-vn
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_PUBLIC_BASE_URL=http://localhost:9000/massage-vn
```

Supabase Storage can be used through its S3-compatible endpoint without changing mobile upload flows:

```dotenv
STORAGE_PROVIDER=supabase-storage-s3
S3_ENDPOINT=https://<project-ref>.storage.supabase.co/storage/v1/s3
S3_REGION=auto
S3_BUCKET=hands-files
S3_ACCESS_KEY=<supabase-storage-access-key>
S3_SECRET_KEY=<supabase-storage-secret-key>
S3_PUBLIC_BASE_URL=https://<project-ref>.supabase.co/storage/v1/object/public/hands-files
```

Confirm the exact Supabase S3 endpoint and access keys in the Supabase dashboard before production use. Keep these credentials server-side only.

Private files are read through `GET /api/files/:id/read-url`, which checks that the requester is an admin or the owning provider before returning a short-lived signed GET URL.

If storage variables are missing, the API deliberately falls back to placeholder URLs so local MVP flows remain usable.
