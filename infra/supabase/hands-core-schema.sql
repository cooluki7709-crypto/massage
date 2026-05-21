-- HANDS Supabase core schema draft.
-- Run in Supabase SQL editor after reviewing project-specific admin claims.
-- This is designed as a migration target while the MVP still routes critical
-- booking, payment, and matching writes through the NestJS API.

create extension if not exists pgcrypto;
create extension if not exists postgis;

do $$
begin
  create type public.user_role as enum ('CUSTOMER', 'PROVIDER', 'ADMIN');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.provider_status as enum (
    'OFFLINE',
    'ONLINE_AVAILABLE',
    'ONLINE_BUSY',
    'ONLINE_AVAILABLE_SOON'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.booking_status as enum (
    'CREATED',
    'OPEN_MATCHING',
    'MATCHED',
    'PROVIDER_ON_THE_WAY',
    'ARRIVED',
    'IN_SERVICE',
    'COMPLETED',
    'CANCELLED',
    'EXPIRED',
    'REFUNDED'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.payment_status as enum (
    'PENDING',
    'AUTHORIZED',
    'PAID',
    'FAILED',
    'REFUNDED'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.file_visibility as enum ('PUBLIC', 'PRIVATE');
exception
  when duplicate_object then null;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null default 'CUSTOMER',
  phone text,
  display_name text,
  avatar_url text,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.providers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  category text not null default 'massage',
  bio text,
  status public.provider_status not null default 'OFFLINE',
  verification_status text not null default 'DRAFT',
  rating numeric(3, 2) not null default 0,
  review_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  duration_minutes integer not null check (duration_minutes > 0),
  base_price_vnd integer not null check (base_price_vnd >= 0),
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.provider_services (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  service_id uuid not null references public.services(id) on delete cascade,
  price_vnd integer not null check (price_vnd >= 0),
  duration_minutes integer not null check (duration_minutes > 0),
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_id, service_id, duration_minutes)
);

create table if not exists public.provider_locations (
  provider_id uuid primary key references public.providers(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  location geography(point, 4326)
    generated always as (st_setsrid(st_makepoint(longitude, latitude), 4326)::geography) stored,
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_selected_locations (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  address_text text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id),
  preferred_provider_id uuid references public.providers(id),
  selected_provider_id uuid references public.providers(id),
  status public.booking_status not null default 'CREATED',
  address_text text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  scheduled_at timestamptz not null default now(),
  expires_at timestamptz,
  subtotal_vnd integer not null default 0,
  total_vnd integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.booking_services (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  service_id uuid not null references public.services(id),
  provider_service_id uuid references public.provider_services(id),
  name text not null,
  duration_minutes integer not null,
  price_vnd integer not null
);

create table if not exists public.booking_participants (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  provider_id uuid not null references public.providers(id) on delete cascade,
  role text not null default 'BACKUP',
  status text not null default 'JOINED',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (booking_id, provider_id)
);

create table if not exists public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  provider_id uuid not null references public.providers(id),
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_room_id uuid not null references public.chat_rooms(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  method text not null,
  status public.payment_status not null default 'PENDING',
  amount_vnd integer not null check (amount_vnd >= 0),
  provider_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  provider_id uuid not null references public.providers(id),
  rating integer not null check (rating between 1 and 5),
  body text,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  bucket text not null,
  path text not null,
  visibility public.file_visibility not null default 'PRIVATE',
  purpose text,
  content_type text,
  created_at timestamptz not null default now(),
  unique (bucket, path)
);

create table if not exists public.admin_settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

create index if not exists providers_user_idx on public.providers(user_id);
create index if not exists providers_status_idx on public.providers(status);
create index if not exists provider_locations_location_idx on public.provider_locations using gist(location);
create index if not exists provider_locations_updated_idx on public.provider_locations(updated_at desc);
create index if not exists customer_selected_locations_customer_idx
  on public.customer_selected_locations(customer_id, created_at desc);
create index if not exists bookings_customer_idx on public.bookings(customer_id, created_at desc);
create index if not exists bookings_selected_provider_idx on public.bookings(selected_provider_id, created_at desc);
create index if not exists bookings_status_idx on public.bookings(status, created_at desc);
create index if not exists booking_participants_provider_idx
  on public.booking_participants(provider_id, created_at desc);
create index if not exists messages_room_idx on public.messages(chat_room_id, created_at desc);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);
create index if not exists files_owner_idx on public.files(owner_id, created_at desc);

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'ADMIN'
  );
$$;

create or replace function public.nearby_providers(
  input_lat double precision,
  input_lng double precision,
  radius_meters integer default 5000
)
returns table (
  provider_id uuid,
  name text,
  category text,
  status public.provider_status,
  latitude double precision,
  longitude double precision,
  updated_at timestamptz,
  distance_meters integer,
  is_recent_location boolean
)
language sql
stable
as $$
  with origin as (
    select st_setsrid(st_makepoint(input_lng, input_lat), 4326)::geography as point
  )
  select
    p.id,
    p.name,
    p.category,
    p.status,
    pl.latitude,
    pl.longitude,
    pl.updated_at,
    round(st_distance(pl.location, origin.point) / 100.0)::integer * 100,
    pl.updated_at >= now() - interval '30 minutes'
  from public.providers p
  join public.provider_locations pl on pl.provider_id = p.id
  cross join origin
  where p.status in ('ONLINE_AVAILABLE', 'ONLINE_AVAILABLE_SOON')
    and pl.updated_at >= now() - interval '24 hours'
    and st_dwithin(pl.location, origin.point, radius_meters)
  order by st_distance(pl.location, origin.point), p.status;
$$;

alter table public.profiles enable row level security;
alter table public.providers enable row level security;
alter table public.services enable row level security;
alter table public.provider_services enable row level security;
alter table public.provider_locations enable row level security;
alter table public.customer_selected_locations enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_services enable row level security;
alter table public.booking_participants enable row level security;
alter table public.chat_rooms enable row level security;
alter table public.messages enable row level security;
alter table public.payments enable row level security;
alter table public.reviews enable row level security;
alter table public.notifications enable row level security;
alter table public.files enable row level security;
alter table public.admin_settings enable row level security;

drop policy if exists "profiles owner read" on public.profiles;
create policy "profiles owner read"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin());

drop policy if exists "profiles owner update" on public.profiles;
create policy "profiles owner update"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "providers public approved read" on public.providers;
create policy "providers public approved read"
  on public.providers for select
  using (verification_status = 'APPROVED' or user_id = auth.uid() or public.is_admin());

drop policy if exists "providers owner update" on public.providers;
create policy "providers owner update"
  on public.providers for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "services public read" on public.services;
create policy "services public read"
  on public.services for select
  using (status = 'ACTIVE' or public.is_admin());

drop policy if exists "provider services public read" on public.provider_services;
create policy "provider services public read"
  on public.provider_services for select
  using (status = 'ACTIVE' or public.is_admin());

drop policy if exists "recent provider locations read" on public.provider_locations;
create policy "recent provider locations read"
  on public.provider_locations for select
  using (updated_at >= now() - interval '24 hours' or public.is_admin());

drop policy if exists "provider owner location upsert" on public.provider_locations;
create policy "provider owner location upsert"
  on public.provider_locations for all
  using (
    exists (
      select 1 from public.providers p
      where p.id = provider_id and p.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.providers p
      where p.id = provider_id and p.user_id = auth.uid()
    )
  );

drop policy if exists "customer selected locations owner" on public.customer_selected_locations;
create policy "customer selected locations owner"
  on public.customer_selected_locations for all
  using (customer_id = auth.uid() or public.is_admin())
  with check (customer_id = auth.uid());

drop policy if exists "bookings participant read" on public.bookings;
create policy "bookings participant read"
  on public.bookings for select
  using (
    customer_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.providers p
      where p.id in (preferred_provider_id, selected_provider_id)
        and p.user_id = auth.uid()
    )
    or exists (
      select 1
      from public.booking_participants bp
      join public.providers p on p.id = bp.provider_id
      where bp.booking_id = bookings.id
        and p.user_id = auth.uid()
    )
  );

drop policy if exists "chat rooms participants read" on public.chat_rooms;
create policy "chat rooms participants read"
  on public.chat_rooms for select
  using (
    customer_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.providers p
      where p.id = provider_id and p.user_id = auth.uid()
    )
  );

drop policy if exists "messages participants read" on public.messages;
create policy "messages participants read"
  on public.messages for select
  using (
    public.is_admin()
    or exists (
      select 1
      from public.chat_rooms cr
      left join public.providers p on p.id = cr.provider_id
      where cr.id = messages.chat_room_id
        and (cr.customer_id = auth.uid() or p.user_id = auth.uid())
    )
  );

drop policy if exists "messages participants insert" on public.messages;
create policy "messages participants insert"
  on public.messages for insert
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.chat_rooms cr
      left join public.providers p on p.id = cr.provider_id
      where cr.id = chat_room_id
        and (cr.customer_id = auth.uid() or p.user_id = auth.uid())
    )
  );

drop policy if exists "payments owner read" on public.payments;
create policy "payments owner read"
  on public.payments for select
  using (customer_id = auth.uid() or public.is_admin());

drop policy if exists "reviews public read" on public.reviews;
create policy "reviews public read"
  on public.reviews for select
  using (true);

drop policy if exists "notifications owner read" on public.notifications;
create policy "notifications owner read"
  on public.notifications for select
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists "notifications owner update" on public.notifications;
create policy "notifications owner update"
  on public.notifications for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "files owner read" on public.files;
create policy "files owner read"
  on public.files for select
  using (visibility = 'PUBLIC' or owner_id = auth.uid() or public.is_admin());

drop policy if exists "admin settings admin only" on public.admin_settings;
create policy "admin settings admin only"
  on public.admin_settings for all
  using (public.is_admin())
  with check (public.is_admin());
