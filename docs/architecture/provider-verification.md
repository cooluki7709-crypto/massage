# Provider Verification

The MVP supports a simple verification loop for providers.

## Provider Flow

1. Provider logs in.
2. Provider requests `GET /provider/verification` to load or create the verification record.
3. Provider requests `POST /files/presign` with `purpose=provider-verification` and `visibility=PRIVATE`.
4. API creates a private `FileAsset` attached to the provider verification record.
5. Provider calls `POST /provider/verification/submit`.
6. Verification status becomes `SUBMITTED`.

## Admin Flow

1. Admin opens the provider verification dashboard.
2. Admin sees verification status, rejection reason, and private file metadata.
3. Admin approves or rejects.
4. Provider receives an in-app notification.

## Production Hardening

- Replace placeholder upload URLs with S3/R2 presigned PUT URLs.
- Add private signed-read URLs for admin file review.
- Add document categories such as ID card, certificate, selfie, and work permit.
- Add file malware scanning and moderation workflow before approval.
