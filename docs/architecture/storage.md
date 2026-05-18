# Storage

## MVP Contract

The API exposes `POST /api/files/presign` to create a `FileAsset` record and return an upload contract:

- `file` - database record with key, content type, visibility, and CDN/private metadata.
- `upload.method` - currently `PUT`.
- `upload.url` - S3/R2-compatible presigned PUT URL when storage env vars are configured.
- `upload.headers` - client must send matching `content-type`.
- `storageMode` - `s3-compatible-presigned` or `placeholder`.

## Visibility

- `PRIVATE` - provider verification IDs, passports, private moderation materials.
- `PUBLIC` - provider gallery/profile media intended for CDN.

## Next Adapter Step

Set `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY`, and `S3_SECRET_KEY` to enable SigV4 presigned PUT/GET URLs. `S3_PUBLIC_BASE_URL` can point at a CDN or public bucket domain for public assets.

Private files are read through `GET /api/files/:id/read-url`, which checks that the requester is an admin or the owning provider before returning a short-lived signed GET URL.

If storage variables are missing, the API deliberately falls back to placeholder URLs so local MVP flows remain usable.
