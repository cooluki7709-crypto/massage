-- HANDS Supabase Storage buckets and RLS draft.
-- Run after `hands-core-schema.sql`.
-- The NestJS API can use Supabase Storage through the S3-compatible endpoint,
-- while these policies prepare direct client access for a later migration phase.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'hands-public',
    'hands-public',
    true,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'video/mp4']
  ),
  (
    'hands-private',
    'hands-private',
    false,
    10485760,
    array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'application/pdf']
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public media read" on storage.objects;
create policy "public media read"
  on storage.objects for select
  using (bucket_id = 'hands-public');

drop policy if exists "owner public media insert" on storage.objects;
create policy "owner public media insert"
  on storage.objects for insert
  with check (
    bucket_id = 'hands-public'
    and owner = auth.uid()
  );

drop policy if exists "owner public media update" on storage.objects;
create policy "owner public media update"
  on storage.objects for update
  using (
    bucket_id = 'hands-public'
    and (owner = auth.uid() or public.is_admin())
  )
  with check (
    bucket_id = 'hands-public'
    and (owner = auth.uid() or public.is_admin())
  );

drop policy if exists "owner public media delete" on storage.objects;
create policy "owner public media delete"
  on storage.objects for delete
  using (
    bucket_id = 'hands-public'
    and (owner = auth.uid() or public.is_admin())
  );

drop policy if exists "private media owner read" on storage.objects;
create policy "private media owner read"
  on storage.objects for select
  using (
    bucket_id = 'hands-private'
    and (owner = auth.uid() or public.is_admin())
  );

drop policy if exists "private media owner insert" on storage.objects;
create policy "private media owner insert"
  on storage.objects for insert
  with check (
    bucket_id = 'hands-private'
    and owner = auth.uid()
  );

drop policy if exists "private media owner update" on storage.objects;
create policy "private media owner update"
  on storage.objects for update
  using (
    bucket_id = 'hands-private'
    and (owner = auth.uid() or public.is_admin())
  )
  with check (
    bucket_id = 'hands-private'
    and (owner = auth.uid() or public.is_admin())
  );

drop policy if exists "private media owner delete" on storage.objects;
create policy "private media owner delete"
  on storage.objects for delete
  using (
    bucket_id = 'hands-private'
    and (owner = auth.uid() or public.is_admin())
  );
