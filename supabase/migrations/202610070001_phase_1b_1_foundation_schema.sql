create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists citext with schema extensions;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from anon, authenticated;
revoke all on all functions in schema public from public;

do $$
declare
  creator_role name;
begin
  foreach creator_role in array array['postgres', 'supabase_admin']
  loop
    if exists (select 1 from pg_roles where rolname = creator_role)
      and (
        creator_role = current_user
        or pg_has_role(current_user, creator_role, 'member')
      )
    then
      execute format(
        'alter default privileges for role %I in schema public revoke all on tables from anon, authenticated',
        creator_role
      );
      execute format(
        'alter default privileges for role %I in schema public revoke all on sequences from anon, authenticated',
        creator_role
      );
      execute format(
        'alter default privileges for role %I in schema public revoke all on functions from anon, authenticated',
        creator_role
      );
      execute format(
        'alter default privileges for role %I in schema public revoke all on functions from public',
        creator_role
      );
    end if;
  end loop;

  execute 'alter default privileges in schema public revoke all on tables from anon, authenticated';
  execute 'alter default privileges in schema public revoke all on sequences from anon, authenticated';
  execute 'alter default privileges in schema public revoke all on functions from anon, authenticated';
  execute 'alter default privileges in schema public revoke all on functions from public';
end $$;

create type public.club_status as enum ('active', 'suspended', 'archived');
create type public.member_status as enum ('active', 'inactive', 'suspended', 'left');
create type public.staff_status as enum ('temp_password_pending', 'active', 'suspended', 'removed');
create type public.subscription_status as enum ('pending', 'active', 'frozen', 'expired', 'cancelled');
create type public.payment_method as enum ('cash', 'wallet_transfer', 'instapay_transfer', 'bank_transfer', 'manual_adjustment');
create type public.payment_status as enum ('pending', 'approved', 'rejected', 'refunded');
create type public.attendance_method as enum ('qr', 'manual_member_number', 'manual_phone');
create type public.attendance_result as enum (
  'accepted',
  'duplicate',
  'expired_subscription',
  'frozen_subscription',
  'wrong_club',
  'invalid_token',
  'not_found'
);
create type public.plan_assignment_status as enum ('active', 'paused', 'completed', 'cancelled');
create type public.notification_channel as enum ('in_app', 'web_push');
create type public.notification_status as enum ('queued', 'sent', 'read', 'failed');
create type public.audit_severity as enum ('info', 'warning', 'critical');
create type public.record_source as enum ('member', 'staff');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email extensions.citext unique,
  phone_e164 text,
  full_name_ar text not null,
  full_name_en text,
  avatar_path text,
  preferred_locale text not null default 'ar' check (preferred_locale in ('ar', 'en')),
  timezone text not null default 'Africa/Cairo',
  must_change_password boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_deleted_at_idx on public.profiles(deleted_at);

create table public.platform_admins (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  granted_by uuid references public.profiles(id),
  mfa_required boolean not null default true,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table public.platform_plans (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique,
  name_ar text not null,
  name_en text not null,
  max_staff integer check (max_staff is null or max_staff > 0),
  max_members integer check (max_members is null or max_members > 0),
  min_monthly_fee_minor integer not null default 0 check (min_monthly_fee_minor >= 0),
  allowed_modules text[] not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint platform_plans_allowed_modules_check check (
    allowed_modules <@ array[
      'core',
      'nutrition',
      'notifications',
      'csv_import',
      'attendance_scanner'
    ]::text[]
  )
);

create table public.platform_plan_prices (
  id uuid primary key default extensions.gen_random_uuid(),
  platform_plan_id uuid not null references public.platform_plans(id),
  price_per_active_member_minor integer not null check (price_per_active_member_minor >= 0),
  currency char(3) not null default 'EGP',
  effective_from date not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (platform_plan_id, effective_from)
);

create table public.clubs (
  id uuid primary key default extensions.gen_random_uuid(),
  slug text not null unique check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  status public.club_status not null default 'active',
  platform_plan_id uuid not null references public.platform_plans(id),
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  suspended_at timestamptz,
  archived_at timestamptz,
  constraint clubs_trial_range_check check (
    trial_started_at is null
    or trial_ends_at is null
    or trial_ends_at >= trial_started_at
  )
);

create index clubs_status_idx on public.clubs(status);

create table public.club_plan_history (
  id uuid primary key default extensions.gen_random_uuid(),
  club_id uuid not null references public.clubs(id),
  from_platform_plan_id uuid references public.platform_plans(id),
  to_platform_plan_id uuid not null references public.platform_plans(id),
  from_trial_ends_at timestamptz,
  to_trial_ends_at timestamptz,
  changed_by uuid not null references public.profiles(id),
  reason text not null,
  created_at timestamptz not null default now()
);

create table public.usage_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  club_id uuid not null references public.clubs(id),
  snapshot_date date not null,
  active_member_count integer not null check (active_member_count >= 0),
  staff_count integer not null check (staff_count >= 0),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (club_id, snapshot_date)
);

create table public.club_settings (
  club_id uuid primary key references public.clubs(id) on delete cascade,
  name_ar text not null,
  name_en text not null,
  logo_path text,
  accent_color text check (accent_color is null or accent_color ~ '^#[0-9a-fA-F]{6}$'),
  member_photo_required boolean not null default false,
  require_member_phone boolean not null default true,
  gym_module_enabled boolean not null default true,
  nutrition_module_enabled boolean not null default false,
  notifications_module_enabled boolean not null default false,
  csv_import_enabled boolean not null default false,
  attendance_scanner_enabled boolean not null default true,
  transfer_instructions_ar text,
  transfer_instructions_en text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.roles (
  id uuid primary key default extensions.gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  key text not null,
  name_ar text not null,
  name_en text not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  unique (club_id, key)
);

create table public.permissions (
  id uuid primary key default extensions.gen_random_uuid(),
  key text not null unique,
  description text not null,
  created_at timestamptz not null default now()
);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create table public.club_members (
  id uuid primary key default extensions.gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  member_number text not null,
  phone_e164 text,
  role_id uuid not null references public.roles(id),
  status public.member_status not null default 'active',
  staff_status public.staff_status,
  temp_password_required boolean not null default false,
  temp_password_issued_at timestamptz,
  temp_password_expires_at timestamptz,
  sessions_revoked_at timestamptz,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  deactivated_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint club_members_phone_e164_check check (
    phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{1,14}$'
  ),
  constraint club_members_temp_password_range_check check (
    temp_password_issued_at is null
    or temp_password_expires_at is null
    or temp_password_expires_at > temp_password_issued_at
  )
);

create unique index club_members_active_profile_uidx
  on public.club_members(club_id, profile_id)
  where left_at is null;

create unique index club_members_member_number_uidx
  on public.club_members(club_id, member_number);

create unique index club_members_phone_e164_uidx
  on public.club_members(club_id, phone_e164)
  where phone_e164 is not null;

create index club_members_profile_status_idx on public.club_members(profile_id, status);
create index club_members_club_status_idx on public.club_members(club_id, status);

create table public.staff_link_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  club_id uuid not null references public.clubs(id),
  email extensions.citext not null,
  role_id uuid not null references public.roles(id),
  permission_overrides jsonb not null default '{}'::jsonb,
  requested_by uuid not null references public.profiles(id),
  target_profile_id uuid references public.profiles(id),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  declined_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  constraint staff_link_requests_resolution_check check (
    num_nonnulls(accepted_at, declined_at, cancelled_at) <= 1
  )
);

create index staff_link_requests_club_email_idx on public.staff_link_requests(club_id, email);

alter table public.profiles enable row level security;
alter table public.platform_admins enable row level security;
alter table public.platform_plans enable row level security;
alter table public.platform_plan_prices enable row level security;
alter table public.clubs enable row level security;
alter table public.club_plan_history enable row level security;
alter table public.usage_snapshots enable row level security;
alter table public.club_settings enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.club_members enable row level security;
alter table public.staff_link_requests enable row level security;

insert into public.platform_plans (
  code,
  name_ar,
  name_en,
  max_staff,
  max_members,
  min_monthly_fee_minor,
  allowed_modules
) values (
  'pilot_free',
  'خطة التجربة المجانية',
  'Free pilot plan',
  null,
  null,
  0,
  array['core', 'nutrition', 'notifications', 'csv_import', 'attendance_scanner']::text[]
);
