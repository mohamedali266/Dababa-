create schema if not exists extensions;
create schema if not exists private;
revoke all on schema private from public;

create extension if not exists citext with schema extensions;
create extension if not exists pgcrypto with schema extensions;

do $$
begin
  create type public.club_status as enum ('active', 'suspended', 'archived');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.member_status as enum ('active', 'inactive', 'suspended', 'left');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.staff_status as enum ('active', 'temp_password_pending', 'locked', 'suspended');
exception when duplicate_object then null;
end $$;

create table if not exists public.clubs (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name_ar text not null,
  name_en text,
  status public.club_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.clubs
  add column if not exists status public.club_status not null default 'active';
alter table public.clubs
  add column if not exists name_ar text;
alter table public.clubs
  add column if not exists name_en text;
alter table public.clubs
  add column if not exists updated_at timestamptz not null default now();
alter table public.staff_link_requests
  add column if not exists requested_by_super_admin boolean not null default false;

create table if not exists public.club_member_counters (
  club_id uuid primary key references public.clubs(id) on delete cascade,
  next_member_number integer not null default 1 check (next_member_number > 0)
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email extensions.citext,
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

alter table public.profiles
  add column if not exists provisioned_by_club_id uuid references public.clubs(id) on delete restrict;

create unique index if not exists profiles_email_lower_unique_idx
  on public.profiles (lower(email::text))
  where email is not null;
create index if not exists profiles_deleted_at_idx on public.profiles (deleted_at);

create table if not exists public.platform_admins (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  granted_by uuid references public.profiles(id),
  mfa_required boolean not null default true,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  key text not null,
  name_ar text not null,
  name_en text not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  constraint roles_club_key_unique unique (club_id, key),
  constraint roles_club_id_id_unique unique (club_id, id)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.roles'::regclass
      and conname = 'roles_club_id_id_unique'
  ) then
    alter table public.roles
      add constraint roles_club_id_id_unique unique (club_id, id);
  end if;
end $$;

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  description text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references public.profiles(id),
  club_id uuid references public.clubs(id) on delete restrict,
  action text not null,
  target_table text not null,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists staff_link_requests_one_pending_profile_idx
  on public.staff_link_requests (club_id, target_profile_id)
  where target_profile_id is not null
    and accepted_at is null
    and declined_at is null
    and cancelled_at is null;

create table if not exists public.club_members (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  member_number text not null,
  phone_e164 text,
  role_id uuid not null,
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
  constraint club_members_status_left_at_check check (
    (status = 'left' and left_at is not null)
    or (status <> 'left' and left_at is null)
  ),
  constraint club_members_role_same_club_fk
    foreign key (club_id, role_id)
    references public.roles (club_id, id)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.club_members'::regclass
      and conname = 'club_members_status_left_at_check'
  ) then
    alter table public.club_members
      add constraint club_members_status_left_at_check check (
        (status = 'left' and left_at is not null)
        or (status <> 'left' and left_at is null)
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.club_members'::regclass
      and conname = 'club_members_role_same_club_fk'
  ) then
    alter table public.club_members
      add constraint club_members_role_same_club_fk
      foreign key (club_id, role_id)
      references public.roles (club_id, id);
  end if;
end $$;

create unique index if not exists club_members_active_profile_unique_idx
  on public.club_members (club_id, profile_id)
  where left_at is null;
create unique index if not exists club_members_member_number_unique_idx
  on public.club_members (club_id, member_number);
create unique index if not exists club_members_phone_unique_idx
  on public.club_members (club_id, phone_e164)
  where phone_e164 is not null;
create index if not exists club_members_profile_status_idx on public.club_members (profile_id, status);
create index if not exists club_members_club_status_idx on public.club_members (club_id, status);

alter table public.profiles enable row level security;
alter table public.platform_admins enable row level security;
alter table public.clubs enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.audit_logs enable row level security;
alter table public.club_members enable row level security;
alter table public.club_members force row level security;

create or replace function private.prevent_audit_log_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  raise exception 'audit logs are append-only' using errcode = '42501';
end;
$$;

drop trigger if exists audit_logs_append_only on public.audit_logs;
create trigger audit_logs_append_only
  before update or delete or truncate on public.audit_logs
  for each statement
  execute function private.prevent_audit_log_mutation();

create or replace function private.prevent_profile_security_column_update()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if (select auth.uid()) is not null
    and (
      old.must_change_password is distinct from new.must_change_password
      or old.provisioned_by_club_id is distinct from new.provisioned_by_club_id
      or old.deleted_at is distinct from new.deleted_at
    ) then
    raise exception 'profile security columns are protected' using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_protect_security_columns on public.profiles;
create trigger profiles_protect_security_columns
  before update on public.profiles
  for each row
  execute function private.prevent_profile_security_column_update();

create or replace function private.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select auth.uid() is not null
    and coalesce(auth.jwt()->>'aal', '') = 'aal2'
    and exists (
      select 1
      from public.platform_admins as platform_admin
      where platform_admin.profile_id = auth.uid()
        and platform_admin.revoked_at is null
    );
$$;

create or replace function private.is_club_member(target_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select auth.uid() is not null
    and target_club_id is not null
    and exists (
      select 1
      from public.clubs as club
      join public.club_members as club_member
        on club_member.club_id = club.id
      where club.id = target_club_id
        and club.status = 'active'
        and club_member.profile_id = auth.uid()
        and club_member.status = 'active'
        and club_member.left_at is null
    );
$$;

create or replace function private.has_permission(target_club_id uuid, permission_key text)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select auth.uid() is not null
    and target_club_id is not null
    and permission_key is not null
    and exists (
      select 1
      from public.clubs as club
      join public.club_members as club_member
        on club_member.club_id = club.id
      join public.roles as member_role
        on member_role.id = club_member.role_id
       and member_role.club_id = club_member.club_id
      join public.role_permissions as role_permission
        on role_permission.role_id = member_role.id
      join public.permissions as permission
        on permission.id = role_permission.permission_id
      where club.id = target_club_id
        and club.status = 'active'
        and club_member.profile_id = auth.uid()
        and club_member.status = 'active'
        and club_member.left_at is null
        and permission.key = permission_key
    );
$$;

create or replace function private.write_audit(
  audit_action text,
  audit_club_id uuid,
  audit_target_table text,
  audit_target_id uuid,
  audit_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  inserted_audit_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  insert into public.audit_logs (
    actor_profile_id,
    club_id,
    action,
    target_table,
    target_id,
    metadata
  )
  values (
    auth.uid(),
    audit_club_id,
    audit_action,
    audit_target_table,
    audit_target_id,
    coalesce(audit_metadata, '{}'::jsonb)
  )
  returning id into inserted_audit_id;

  return inserted_audit_id;
end;
$$;

create or replace function private.role_permissions_are_subset(target_club_id uuid, target_role_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select not exists (
    select permission.key
    from public.roles as target_role
    join public.role_permissions as target_role_permission
      on target_role_permission.role_id = target_role.id
    join public.permissions as permission
      on permission.id = target_role_permission.permission_id
    where target_role.club_id = target_club_id
      and target_role.id = target_role_id
      and not private.has_permission(target_club_id, permission.key)
  );
$$;

create or replace function private.role_is_staff(target_club_id uuid, target_role_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select exists (
    select 1
    from public.roles as target_role
    where target_role.club_id = target_club_id
      and target_role.id = target_role_id
      and target_role.key <> 'member'
  );
$$;

create or replace function private.next_club_member_number(target_club_id uuid)
returns text
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  assigned_number integer;
begin
  insert into public.club_member_counters (club_id, next_member_number)
  values (target_club_id, 2)
  on conflict (club_id) do update
  set next_member_number = public.club_member_counters.next_member_number + 1
  returning public.club_member_counters.next_member_number - 1 into assigned_number;

  return lpad(assigned_number::text, 6, '0');
end;
$$;

create or replace function private.profile_has_permission(
  target_profile_id uuid,
  target_club_id uuid,
  permission_key text
)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select target_profile_id is not null
    and target_club_id is not null
    and permission_key is not null
    and exists (
      select 1
      from public.clubs as club
      join public.club_members as club_member
        on club_member.club_id = club.id
      join public.roles as member_role
        on member_role.id = club_member.role_id
       and member_role.club_id = club_member.club_id
      join public.role_permissions as role_permission
        on role_permission.role_id = member_role.id
      join public.permissions as permission
        on permission.id = role_permission.permission_id
      where club.id = target_club_id
        and club.status = 'active'
        and club_member.profile_id = target_profile_id
        and club_member.status = 'active'
        and club_member.left_at is null
        and permission.key = permission_key
    );
$$;

create or replace function private.profile_role_permissions_are_subset(
  target_profile_id uuid,
  target_club_id uuid,
  target_role_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  select not exists (
    select permission.key
    from public.roles as target_role
    join public.role_permissions as target_role_permission
      on target_role_permission.role_id = target_role.id
    join public.permissions as permission
      on permission.id = target_role_permission.permission_id
    where target_role.club_id = target_club_id
      and target_role.id = target_role_id
      and not private.profile_has_permission(target_profile_id, target_club_id, permission.key)
  );
$$;

create or replace function private.check_member_or_staff_limit(target_club_id uuid, target_role_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  plan_limits record;
  current_count integer;
begin
  select platform_plan.max_staff, platform_plan.max_members
  into plan_limits
  from public.clubs as locked_club
  join public.platform_plans as platform_plan
    on platform_plan.id = locked_club.platform_plan_id
  where locked_club.id = target_club_id
    and locked_club.status = 'active'
  for update of locked_club;

  if not found then
    raise exception 'club is not active' using errcode = '42501';
  end if;

  if private.role_is_staff(target_club_id, target_role_id) then
    select count(*)::integer
    into current_count
    from public.club_members as club_member
    join public.roles as member_role
      on member_role.club_id = club_member.club_id
     and member_role.id = club_member.role_id
    where club_member.club_id = target_club_id
      and club_member.status = 'active'
      and club_member.left_at is null
      and member_role.key <> 'member';

    if plan_limits.max_staff is not null and current_count >= plan_limits.max_staff then
      raise exception 'staff limit exceeded' using errcode = '23514';
    end if;
  else
    select count(*)::integer
    into current_count
    from public.club_members as club_member
    join public.roles as member_role
      on member_role.club_id = club_member.club_id
     and member_role.id = club_member.role_id
    where club_member.club_id = target_club_id
      and club_member.status = 'active'
      and club_member.left_at is null
      and member_role.key = 'member';

    if plan_limits.max_members is not null and current_count >= plan_limits.max_members then
      raise exception 'member limit exceeded' using errcode = '23514';
    end if;
  end if;
end;
$$;

create or replace function private.add_new_profile_club_member(
  target_club_id uuid,
  target_profile_id uuid,
  target_role_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  inserted_member_id uuid;
  target_role_key text;
  generated_member_number text;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not private.is_super_admin() and not private.has_permission(target_club_id, 'staff.manage') then
    raise exception 'missing staff.manage' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles as target_profile
    where target_profile.id = target_profile_id
      and target_profile.must_change_password
      and target_profile.provisioned_by_club_id = target_club_id
  ) then
    raise exception 'existing profiles require acceptance flow' using errcode = '42501';
  end if;

  select role_to_assign.key
  into target_role_key
  from public.roles as role_to_assign
  where role_to_assign.club_id = target_club_id
    and role_to_assign.id = target_role_id;

  if target_role_key is null then
    raise exception 'role must belong to club' using errcode = '23503';
  end if;
  if not private.is_super_admin() and target_role_key = 'owner' then
    raise exception 'cannot assign owner role' using errcode = '42501';
  end if;
  if not private.is_super_admin() and not private.role_permissions_are_subset(target_club_id, target_role_id) then
    raise exception 'cannot grant permissions caller lacks' using errcode = '42501';
  end if;

  perform private.check_member_or_staff_limit(target_club_id, target_role_id);
  generated_member_number := private.next_club_member_number(target_club_id);

  insert into public.club_members (club_id, profile_id, member_number, role_id, status, created_by)
  values (target_club_id, target_profile_id, generated_member_number, target_role_id, 'active', auth.uid())
  returning id into inserted_member_id;

  perform private.write_audit(
    'club_member.create',
    target_club_id,
    'club_members',
    inserted_member_id,
    jsonb_build_object('source', 'new_profile')
  );

  return inserted_member_id;
end;
$$;

create or replace function private.create_staff_link_request(
  target_club_id uuid,
  target_email extensions.citext,
  target_role_id uuid,
  target_profile_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  inserted_request_id uuid;
  target_role_key text;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if target_profile_id = auth.uid() then
    raise exception 'cannot create request for self' using errcode = '42501';
  end if;

  if not private.is_super_admin() and not private.has_permission(target_club_id, 'staff.manage') then
    raise exception 'missing staff.manage' using errcode = '42501';
  end if;

  select role_to_assign.key
  into target_role_key
  from public.roles as role_to_assign
  where role_to_assign.club_id = target_club_id
    and role_to_assign.id = target_role_id;

  if target_role_key is null then
    raise exception 'role must belong to club' using errcode = '23503';
  end if;
  if not private.is_super_admin() and target_role_key = 'owner' then
    raise exception 'cannot assign owner role' using errcode = '42501';
  end if;
  if not private.is_super_admin() and not private.role_permissions_are_subset(target_club_id, target_role_id) then
    raise exception 'cannot grant permissions caller lacks' using errcode = '42501';
  end if;

  perform private.check_member_or_staff_limit(target_club_id, target_role_id);

  insert into public.staff_link_requests (
    club_id,
    email,
    role_id,
    requested_by,
    target_profile_id,
    requested_by_super_admin,
    expires_at
  )
  values (
    target_club_id,
    target_email,
    target_role_id,
    auth.uid(),
    target_profile_id,
    private.is_super_admin(),
    now() + interval '7 days'
  )
  returning id into inserted_request_id;

  perform private.write_audit(
    'staff_link_request.create',
    target_club_id,
    'staff_link_requests',
    inserted_request_id,
    jsonb_build_object('target_profile_id', target_profile_id)
  );

  return inserted_request_id;
end;
$$;

create or replace function private.accept_staff_link_request(target_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  request_row public.staff_link_requests%rowtype;
  inserted_member_id uuid;
  target_role_key text;
  generated_member_number text;
  left_member_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select *
  into request_row
  from public.staff_link_requests as link_request
  where link_request.id = target_request_id
  for update;

  if not found then
    raise exception 'request not found' using errcode = '02000';
  end if;
  if request_row.target_profile_id is distinct from auth.uid() then
    raise exception 'request belongs to another profile' using errcode = '42501';
  end if;
  if request_row.accepted_at is not null
    or request_row.declined_at is not null
    or request_row.cancelled_at is not null
    or request_row.expires_at <= now()
  then
    raise exception 'request is not acceptable' using errcode = '42501';
  end if;

  perform private.check_member_or_staff_limit(request_row.club_id, request_row.role_id);

  if not request_row.requested_by_super_admin
    and not private.profile_has_permission(request_row.requested_by, request_row.club_id, 'staff.manage') then
    raise exception 'request creator lost staff.manage' using errcode = '42501';
  end if;
  if not request_row.requested_by_super_admin
    and not private.profile_role_permissions_are_subset(
    request_row.requested_by,
    request_row.club_id,
    request_row.role_id
  ) then
    raise exception 'request role exceeds creator permissions' using errcode = '42501';
  end if;

  select role_to_assign.key
  into target_role_key
  from public.roles as role_to_assign
  where role_to_assign.club_id = request_row.club_id
    and role_to_assign.id = request_row.role_id;

  if target_role_key is null then
    raise exception 'role must belong to club' using errcode = '23503';
  end if;
  if not request_row.requested_by_super_admin and target_role_key = 'owner' then
    raise exception 'cannot assign owner role' using errcode = '42501';
  end if;

  update public.staff_link_requests as link_request
  set accepted_at = now()
  where link_request.id = target_request_id;

  select club_member.id
  into left_member_id
  from public.club_members as club_member
  where club_member.club_id = request_row.club_id
    and club_member.profile_id = auth.uid()
    and club_member.status = 'left'
    and club_member.left_at is not null
  for update;

  if left_member_id is not null then
    update public.club_members as club_member
    set role_id = request_row.role_id,
        status = 'active',
        left_at = null,
        updated_at = now()
    where club_member.id = left_member_id
    returning club_member.id into inserted_member_id;
  else
    generated_member_number := private.next_club_member_number(request_row.club_id);

    insert into public.club_members (
      club_id,
      profile_id,
      member_number,
      role_id,
      status,
      created_by
    )
    values (
      request_row.club_id,
      auth.uid(),
      generated_member_number,
      request_row.role_id,
      'active',
      request_row.requested_by
    )
    returning id into inserted_member_id;
  end if;

  perform private.write_audit(
    'staff_link_request.accept',
    request_row.club_id,
    'club_members',
    inserted_member_id,
    jsonb_build_object('request_id', target_request_id)
  );

  return inserted_member_id;
end;
$$;

create or replace function private.change_club_member_role(
  target_member_id uuid,
  new_role_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  existing_member public.club_members%rowtype;
  existing_role_key text;
  new_role_key text;
  existing_club_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select member_to_locate.club_id
  into existing_club_id
  from public.club_members as member_to_locate
  where member_to_locate.id = target_member_id;

  if not found then
    raise exception 'member not found' using errcode = '02000';
  end if;

  perform 1
  from public.clubs as locked_club
  where locked_club.id = existing_club_id
    and locked_club.status = 'active'
  for update;
  if not found then
    raise exception 'club is not active' using errcode = '42501';
  end if;

  select *
  into existing_member
  from public.club_members as member_to_change
  where member_to_change.id = target_member_id
  for update;

  if existing_member.status <> 'active' or existing_member.left_at is not null then
    raise exception 'target member must be active' using errcode = '42501';
  end if;

  if existing_member.profile_id = auth.uid() then
    raise exception 'cannot edit self' using errcode = '42501';
  end if;
  if not private.is_super_admin() and not private.has_permission(existing_member.club_id, 'staff.manage') then
    raise exception 'missing staff.manage' using errcode = '42501';
  end if;

  select existing_role.key
  into existing_role_key
  from public.roles as existing_role
  where existing_role.club_id = existing_member.club_id
    and existing_role.id = existing_member.role_id;
  if not private.is_super_admin() and existing_role_key = 'owner' then
    raise exception 'cannot edit owner' using errcode = '42501';
  end if;
  if not private.is_super_admin()
    and not private.role_permissions_are_subset(existing_member.club_id, existing_member.role_id) then
    raise exception 'cannot edit target with permissions caller lacks' using errcode = '42501';
  end if;

  select role_to_assign.key
  into new_role_key
  from public.roles as role_to_assign
  where role_to_assign.club_id = existing_member.club_id
    and role_to_assign.id = new_role_id;
  if new_role_key is null then
    raise exception 'role must belong to club' using errcode = '23503';
  end if;
  if not private.is_super_admin() and new_role_key = 'owner' then
    raise exception 'cannot assign owner role' using errcode = '42501';
  end if;
  if not private.is_super_admin() and not private.role_permissions_are_subset(existing_member.club_id, new_role_id) then
    raise exception 'cannot grant permissions caller lacks' using errcode = '42501';
  end if;

  if private.role_is_staff(existing_member.club_id, existing_member.role_id)
    is distinct from private.role_is_staff(existing_member.club_id, new_role_id) then
    perform private.check_member_or_staff_limit(existing_member.club_id, new_role_id);
  end if;

  update public.club_members as member_to_change
  set role_id = new_role_id,
      updated_at = now()
  where member_to_change.id = target_member_id
    and member_to_change.club_id = existing_member.club_id
    and member_to_change.profile_id = existing_member.profile_id
    and member_to_change.created_by is not distinct from existing_member.created_by;

  perform private.write_audit(
    'club_member.role_change',
    existing_member.club_id,
    'club_members',
    target_member_id,
    jsonb_build_object('from_role_id', existing_member.role_id, 'to_role_id', new_role_id)
  );
end;
$$;

create or replace function private.change_club_member_status(
  target_member_id uuid,
  new_status public.member_status
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  existing_member public.club_members%rowtype;
  existing_role_key text;
  existing_club_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select member_to_locate.club_id
  into existing_club_id
  from public.club_members as member_to_locate
  where member_to_locate.id = target_member_id;

  if not found then
    raise exception 'member not found' using errcode = '02000';
  end if;

  perform 1 from public.clubs as locked_club
  where locked_club.id = existing_club_id
    and locked_club.status = 'active'
  for update;
  if not found then
    raise exception 'club is not active' using errcode = '42501';
  end if;

  select *
  into existing_member
  from public.club_members as member_to_leave
  where member_to_leave.id = target_member_id
  for update;

  if existing_member.profile_id = auth.uid() then
    raise exception 'cannot edit self' using errcode = '42501';
  end if;
  if not private.is_super_admin() and not private.has_permission(existing_member.club_id, 'staff.manage') then
    raise exception 'missing staff.manage' using errcode = '42501';
  end if;

  select existing_role.key
  into existing_role_key
  from public.roles as existing_role
  where existing_role.club_id = existing_member.club_id
    and existing_role.id = existing_member.role_id;
  if not private.is_super_admin() and existing_role_key = 'owner' then
    raise exception 'cannot remove owner' using errcode = '42501';
  end if;
  if not private.is_super_admin()
    and not private.role_permissions_are_subset(existing_member.club_id, existing_member.role_id) then
    raise exception 'cannot edit target with permissions caller lacks' using errcode = '42501';
  end if;

  if existing_member.status = 'left' and new_status = 'active' then
    raise exception 'left members must rejoin by acceptance' using errcode = '42501';
  end if;
  if not (
    (existing_member.status = 'active' and new_status in ('inactive', 'suspended', 'left'))
    or (existing_member.status = 'inactive' and new_status in ('active', 'suspended', 'left'))
    or (existing_member.status = 'suspended' and new_status in ('active', 'inactive', 'left'))
    or (existing_member.status = new_status)
  ) then
    raise exception 'invalid member status transition' using errcode = '23514';
  end if;

  if existing_member.status <> 'active' and new_status = 'active' then
    perform private.check_member_or_staff_limit(existing_member.club_id, existing_member.role_id);
  end if;

  update public.club_members as member_to_leave
  set status = new_status,
      left_at = case when new_status = 'left' then now() else null end,
      updated_at = now()
  where member_to_leave.id = target_member_id;

  perform private.write_audit(
    'club_member.status_change',
    existing_member.club_id,
    'club_members',
    target_member_id,
    jsonb_build_object('from_status', existing_member.status, 'to_status', new_status)
  );
end;
$$;

create or replace function private.leave_club()
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  own_member public.club_members%rowtype;
  own_member_id uuid;
  own_club_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select club_member.id, club_member.club_id
  into own_member_id, own_club_id
  from public.club_members as club_member
  where club_member.profile_id = auth.uid()
    and club_member.status = 'active'
    and club_member.left_at is null
  order by club_member.joined_at desc
  limit 1
  for update;

  if not found then
    raise exception 'active membership not found' using errcode = '02000';
  end if;

  perform 1
  from public.clubs as locked_club
  where locked_club.id = own_club_id
    and locked_club.status = 'active'
  for update;
  if not found then
    raise exception 'club is not active' using errcode = '42501';
  end if;

  select *
  into own_member
  from public.club_members as club_member
  where club_member.id = own_member_id
  for update;

  update public.club_members as club_member
  set status = 'left',
      left_at = now(),
      updated_at = now()
  where club_member.id = own_member.id;

  perform private.write_audit(
    'club_member.self_leave',
    own_member.club_id,
    'club_members',
    own_member.id,
    '{}'::jsonb
  );
end;
$$;

create or replace function public.create_club_member_for_new_profile(
  target_club_id uuid,
  target_profile_id uuid,
  target_role_id uuid
)
returns uuid
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.add_new_profile_club_member(target_club_id, target_profile_id, target_role_id);
$$;

create or replace function public.create_staff_link_request(
  target_club_id uuid,
  target_email extensions.citext,
  target_role_id uuid,
  target_profile_id uuid
)
returns uuid
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.create_staff_link_request(target_club_id, target_email, target_role_id, target_profile_id);
$$;

create or replace function public.accept_staff_link_request(target_request_id uuid)
returns uuid
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.accept_staff_link_request(target_request_id);
$$;

create or replace function public.change_club_member_role(target_member_id uuid, new_role_id uuid)
returns void
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.change_club_member_role(target_member_id, new_role_id);
$$;

create or replace function public.change_club_member_status(
  target_member_id uuid,
  new_status public.member_status
)
returns void
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.change_club_member_status(target_member_id, new_status);
$$;

create or replace function public.leave_club()
returns void
language sql
security definer
set search_path = public, private, pg_temp
as $$
  select private.leave_club();
$$;

revoke all on all functions in schema public from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_super_admin() to authenticated;
grant execute on function private.is_club_member(uuid) to authenticated;
grant execute on function private.has_permission(uuid, text) to authenticated;
grant execute on function public.create_club_member_for_new_profile(uuid, uuid, uuid) to authenticated;
grant execute on function public.create_staff_link_request(uuid, extensions.citext, uuid, uuid) to authenticated;
grant execute on function public.accept_staff_link_request(uuid) to authenticated;
grant execute on function public.change_club_member_role(uuid, uuid) to authenticated;
grant execute on function public.change_club_member_status(uuid, public.member_status) to authenticated;
grant execute on function public.leave_club() to authenticated;

revoke insert, update, delete, truncate on public.club_members from authenticated;
revoke insert, update, delete, truncate on public.audit_logs from authenticated;
grant select on public.club_members to authenticated;

drop policy if exists "profiles_select_own_or_super_admin" on public.profiles;
create policy "profiles_select_own_or_super_admin"
  on public.profiles
  for select
  to authenticated
  using (profiles.id = (select auth.uid()) or private.is_super_admin());

drop policy if exists "profiles_insert_own_or_super_admin" on public.profiles;
create policy "profiles_insert_own_or_super_admin"
  on public.profiles
  for insert
  to authenticated
  with check (profiles.id = (select auth.uid()) or private.is_super_admin());

drop policy if exists "profiles_update_own_or_super_admin" on public.profiles;
create policy "profiles_update_own_or_super_admin"
  on public.profiles
  for update
  to authenticated
  using (profiles.id = (select auth.uid()) or private.is_super_admin())
  with check (profiles.id = (select auth.uid()) or private.is_super_admin());

drop policy if exists "platform_admins_select_super_admin" on public.platform_admins;
create policy "platform_admins_select_super_admin"
  on public.platform_admins
  for select
  to authenticated
  using (private.is_super_admin());

drop policy if exists "clubs_select_member_or_super_admin" on public.clubs;
create policy "clubs_select_member_or_super_admin"
  on public.clubs
  for select
  to authenticated
  using (private.is_super_admin() or private.is_club_member(clubs.id));

drop policy if exists "roles_select_club_member_or_super_admin" on public.roles;
create policy "roles_select_club_member_or_super_admin"
  on public.roles
  for select
  to authenticated
  using (private.is_super_admin() or private.is_club_member(roles.club_id));

drop policy if exists "permissions_select_authenticated" on public.permissions;
create policy "permissions_select_authenticated"
  on public.permissions
  for select
  to authenticated
  using ((select auth.uid()) is not null);

drop policy if exists "role_permissions_select_club_member_or_super_admin" on public.role_permissions;
create policy "role_permissions_select_club_member_or_super_admin"
  on public.role_permissions
  for select
  to authenticated
  using (
    private.is_super_admin()
    or exists (
      select 1
      from public.roles as visible_role
      where visible_role.id = role_permissions.role_id
        and private.is_club_member(visible_role.club_id)
    )
  );

drop policy if exists "audit_logs_select_super_admin" on public.audit_logs;
create policy "audit_logs_select_super_admin"
  on public.audit_logs
  for select
  to authenticated
  using (private.is_super_admin());

drop policy if exists "club_members_select_authorized" on public.club_members;
create policy "club_members_select_authorized"
  on public.club_members
  for select
  to authenticated
  using (
    club_members.profile_id = (select auth.uid())
    or private.has_permission(club_members.club_id, 'members.read')
    or private.has_permission(club_members.club_id, 'staff.manage')
  );
