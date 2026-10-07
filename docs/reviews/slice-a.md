# Slice A Review SQL

Direct super-admin tenant reads are not allowed in slice (a). Super-admin tenant reads will use audited `SECURITY DEFINER` functions in the admin-screens slice.

`private` is not exposed through PostgREST because `supabase/config.toml` has `api.schemas = ["public"]`. Public invocation is through this exact authenticated RPC allowlist only: `create_club_member_for_new_profile`, `create_staff_link_request`, `accept_staff_link_request`, `change_club_member_role`, `change_club_member_status`, `leave_club`.

Per-staff permission overrides do not exist in slice (a). Permission tweaks are custom club-scoped roles; assignment is allowed only when the role permissions are a subset of the caller's current permissions.

Profiles are anonymized, never hard-deleted. Audit logs are append-only; `UPDATE`, `DELETE`, and `TRUNCATE` are blocked and revoked from `authenticated`.

First owner assignment is a super-admin path: a super admin provisions/links the initial owner role. Staff-link owner acceptance checks `requested_by_super_admin`, captured when the creator makes the request, not the acceptor's status.

Staff-link request rate limiting is not a DB counter in slice (a); app/server middleware must rate-limit request creation by actor, club, target profile, and IP/device.

## Schema SQL

```sql
alter table public.roles add constraint roles_club_id_id_unique unique (club_id, id);
alter table public.club_members add constraint club_members_role_same_club_fk foreign key (club_id, role_id) references public.roles (club_id, id);
alter table public.club_members add constraint club_members_status_left_at_check check ((status = 'left' and left_at is not null) or (status <> 'left' and left_at is null));
alter table public.profiles add column if not exists provisioned_by_club_id uuid references public.clubs(id) on delete restrict;
alter table public.staff_link_requests add column if not exists requested_by_super_admin boolean not null default false;
create unique index if not exists staff_link_requests_one_pending_profile_idx on public.staff_link_requests (club_id, target_profile_id) where target_profile_id is not null and accepted_at is null and declined_at is null and cancelled_at is null;
create table if not exists public.club_member_counters (club_id uuid primary key references public.clubs(id) on delete cascade, next_member_number integer not null default 1 check (next_member_number > 0));
create table if not exists public.audit_logs (id uuid primary key default gen_random_uuid(), actor_profile_id uuid references public.profiles(id), club_id uuid references public.clubs(id) on delete restrict, action text not null, target_table text not null, target_id uuid, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
create policy "audit_logs_select_super_admin" on public.audit_logs for select to authenticated using (private.is_super_admin());
```

FK ON DELETE review result: no foreign key references `public.club_members` with `ON DELETE CASCADE`; CI has a catalog test.

## Policy SQL

```sql
create policy "club_members_select_authorized"
  on public.club_members
  for select
  to authenticated
  using (
    club_members.profile_id = (select auth.uid())
    or private.has_permission(club_members.club_id, 'members.read')
    or private.has_permission(club_members.club_id, 'staff.manage')
  );
```

## Required Helper SQL

```sql
create or replace function private.prevent_audit_log_mutation() returns trigger language plpgsql security definer set search_path = public, private, pg_temp as $$
begin
  raise exception 'audit logs are append-only' using errcode = '42501';
end;
$$;

create or replace function private.role_permissions_are_subset(target_club_id uuid, target_role_id uuid) returns boolean language sql stable security definer set search_path = public, private, pg_temp as $$
  select not exists (
    select permission.key
    from public.roles as target_role
    join public.role_permissions as target_role_permission on target_role_permission.role_id = target_role.id
    join public.permissions as permission on permission.id = target_role_permission.permission_id
    where target_role.club_id = target_club_id
      and target_role.id = target_role_id
      and not private.has_permission(target_club_id, permission.key)
  );
$$;

create or replace function private.profile_has_permission(target_profile_id uuid, target_club_id uuid, permission_key text) returns boolean language sql stable security definer set search_path = public, private, pg_temp as $$
  select target_profile_id is not null and target_club_id is not null and permission_key is not null
    and exists (
      select 1
      from public.clubs as club
      join public.club_members as club_member on club_member.club_id = club.id
      join public.roles as member_role on member_role.id = club_member.role_id and member_role.club_id = club_member.club_id
      join public.role_permissions as role_permission on role_permission.role_id = member_role.id
      join public.permissions as permission on permission.id = role_permission.permission_id
      where club.id = target_club_id and club.status = 'active'
        and club_member.profile_id = target_profile_id and club_member.status = 'active'
        and club_member.left_at is null and permission.key = permission_key
    );
$$;

create or replace function private.profile_role_permissions_are_subset(target_profile_id uuid, target_club_id uuid, target_role_id uuid) returns boolean language sql stable security definer set search_path = public, private, pg_temp as $$
  select not exists (
    select permission.key
    from public.roles as target_role
    join public.role_permissions as target_role_permission on target_role_permission.role_id = target_role.id
    join public.permissions as permission on permission.id = target_role_permission.permission_id
    where target_role.club_id = target_club_id
      and target_role.id = target_role_id
      and not private.profile_has_permission(target_profile_id, target_club_id, permission.key)
  );
$$;

create or replace function private.check_member_or_staff_limit(target_club_id uuid, target_role_id uuid) returns void language plpgsql security definer set search_path = public, private, pg_temp as $$
declare
  plan_limits record;
  current_count integer;
begin
  select platform_plan.max_staff, platform_plan.max_members into plan_limits
  from public.clubs as locked_club
  join public.platform_plans as platform_plan on platform_plan.id = locked_club.platform_plan_id
  where locked_club.id = target_club_id and locked_club.status = 'active'
  for update of locked_club;
  if not found then raise exception 'club is not active' using errcode = '42501'; end if;
  if private.role_is_staff(target_club_id, target_role_id) then
    select count(*)::integer into current_count from public.club_members as club_member join public.roles as member_role on member_role.club_id = club_member.club_id and member_role.id = club_member.role_id where club_member.club_id = target_club_id and club_member.status = 'active' and club_member.left_at is null and member_role.key <> 'member';
    if plan_limits.max_staff is not null and current_count >= plan_limits.max_staff then raise exception 'staff limit exceeded' using errcode = '23514'; end if;
  else
    select count(*)::integer into current_count from public.club_members as club_member join public.roles as member_role on member_role.club_id = club_member.club_id and member_role.id = club_member.role_id where club_member.club_id = target_club_id and club_member.status = 'active' and club_member.left_at is null and member_role.key = 'member';
    if plan_limits.max_members is not null and current_count >= plan_limits.max_members then raise exception 'member limit exceeded' using errcode = '23514'; end if;
  end if;
end;
$$;
```

## Write Function Contracts

The public RPC wrappers are the only exposed invocation path. Each write function does: authenticate, permission check before entitlement, lock club row first, lock member/request row second, validate same-club role, validate role-permission subset, block self-edit, block owner target unless super-admin path, generate member number internally, write exactly one audit row.

Status transition table:

| From | Allowed To |
|---|---|
| `active` | `inactive`, `suspended`, `left` |
| `inactive` | `active`, `suspended`, `left` |
| `suspended` | `active`, `inactive`, `left` |
| `left` | blocked; rejoin requires accepted staff-link request |

```sql
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
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  select club_member.id, club_member.club_id into own_member_id, own_club_id
  from public.club_members as club_member
  where club_member.profile_id = auth.uid() and club_member.status = 'active' and club_member.left_at is null
  order by club_member.joined_at desc limit 1 for update;
  if not found then raise exception 'active membership not found' using errcode = '02000'; end if;
  perform 1 from public.clubs as locked_club where locked_club.id = own_club_id and locked_club.status = 'active' for update;
  if not found then raise exception 'club is not active' using errcode = '42501'; end if;
  select * into own_member from public.club_members as club_member where club_member.id = own_member_id for update;
  update public.club_members as club_member set status = 'left', left_at = now(), updated_at = now() where club_member.id = own_member.id;
  perform private.write_audit('club_member.self_leave', own_member.club_id, 'club_members', own_member.id, '{}'::jsonb);
end;
$$;
```

## Public RPC Wrappers

```sql
create function public.create_club_member_for_new_profile(uuid, uuid, uuid) returns uuid security definer as $$ select private.add_new_profile_club_member($1, $2, $3); $$ language sql;
create function public.create_staff_link_request(uuid, extensions.citext, uuid, uuid) returns uuid security definer as $$ select private.create_staff_link_request($1, $2, $3, $4); $$ language sql;
create function public.accept_staff_link_request(uuid) returns uuid security definer as $$ select private.accept_staff_link_request($1); $$ language sql;
create function public.change_club_member_role(uuid, uuid) returns void security definer as $$ select private.change_club_member_role($1, $2); $$ language sql;
create function public.change_club_member_status(uuid, public.member_status) returns void security definer as $$ select private.change_club_member_status($1, $2); $$ language sql;
create function public.leave_club() returns void security definer as $$ select private.leave_club(); $$ language sql;
```

## Test Names

- club_members table exists
- audit_logs table exists
- private write_audit helper exists
- audit_logs has append-only trigger
- private is_super_admin helper exists
- private is_club_member helper exists
- private has_permission helper exists
- club_members has only select policy
- club_members select uses explicit USING with select auth.uid
- authenticated can select club_members
- authenticated cannot directly mutate club_members
- club_members has composite role same-club FK
- roles has unique (club_id,id)
- club_members has status/left_at check
- no FK references club_members with ON DELETE CASCADE
- no public function executable by anon or public
- authenticated can execute exactly the public RPC wrapper allowlist
- no private function executable by anon or public
- authenticated can execute only private helper functions
- helper function owner has BYPASSRLS
- concurrent add guarded by FOR UPDATE entitlement lock
- plain member cannot read other members
- cross-club member read denied
- is_club_member works with FORCE RLS enabled
- plain member lacks members.read
- staff.manage can read club members
- staff.manage helper positive
- suspended club staff lose permissions
- staff.manage cannot grant role with permissions they lack
- caller cannot edit accountant target with payments.approve they lack
- cannot assign owner
- caller cannot edit self
- owner target blocked
- cannot add existing profile without acceptance
- cannot change profile_id directly
- cannot change club_id directly
- cannot change created_by directly
- cannot delete directly
- cannot change must_change_password directly
- cannot change provisioned_by_club_id directly
- cross-club role fails at DB level
- aal1 super admin denied
- direct super-admin SELECT is not available through club_members policy
- staff limit at limit-1 allows add up to limit
- add member writes exactly one audit row
- staff limit at limit blocks limit+1 add
- create staff-link request succeeds
- create staff-link request writes exactly one audit row
- staff-link request expiry is server-fixed at seven days
- max one pending staff-link request per club profile
- add member via accepted request succeeds
- accepted request writes exactly one audit row
- member can leave club themself
- leave_club writes exactly one audit row
- create rejoin request for left member succeeds
- left member rejoins through acceptance
- owner can change member role within caller permissions
- change role writes exactly one audit row
- change status to left succeeds
- change status writes exactly one audit row
- left to active is blocked without acceptance
- member with status left loses permissions
- audit log is immutable on update
- audit log is immutable on delete
- audit log is immutable on truncate
- staff-limit concurrency: successes=1 failures=1
