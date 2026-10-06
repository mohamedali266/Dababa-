begin;

select plan(36);

select has_extension('pgcrypto');
select has_extension('btree_gist');
select has_extension('pg_trgm');
select has_extension('citext');

select ok(to_regtype('public.club_status') is not null, 'club_status enum exists');
select ok(to_regtype('public.member_status') is not null, 'member_status enum exists');
select ok(to_regtype('public.staff_status') is not null, 'staff_status enum exists');
select ok(to_regtype('public.record_source') is not null, 'record_source enum exists');

select ok(to_regclass('public.profiles') is not null, 'profiles table exists');
select ok(to_regclass('public.platform_admins') is not null, 'platform_admins table exists');
select ok(to_regclass('public.platform_plans') is not null, 'platform_plans table exists');
select ok(to_regclass('public.platform_plan_prices') is not null, 'platform_plan_prices table exists');
select ok(to_regclass('public.clubs') is not null, 'clubs table exists');
select ok(to_regclass('public.club_plan_history') is not null, 'club_plan_history table exists');
select ok(to_regclass('public.usage_snapshots') is not null, 'usage_snapshots table exists');
select ok(to_regclass('public.club_settings') is not null, 'club_settings table exists');
select ok(to_regclass('public.roles') is not null, 'roles table exists');
select ok(to_regclass('public.permissions') is not null, 'permissions table exists');
select ok(to_regclass('public.role_permissions') is not null, 'role_permissions table exists');
select ok(to_regclass('public.club_members') is not null, 'club_members table exists');
select ok(to_regclass('public.staff_link_requests') is not null, 'staff_link_requests table exists');

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'must_change_password'
  ),
  'profiles.must_change_password column exists'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'club_settings'
      and column_name = 'require_member_phone'
  ),
  'club_settings.require_member_phone column exists'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'club_members'
      and column_name = 'phone_e164'
  ),
  'club_members.phone_e164 column exists'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'club_members'
      and column_name = 'temp_password_expires_at'
  ),
  'club_members.temp_password_expires_at column exists'
);

select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'must_change_password'
  ),
  'false',
  'profiles.must_change_password defaults false'
);

select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'club_settings'
      and column_name = 'require_member_phone'
  ),
  'true',
  'club_settings.require_member_phone defaults true'
);

select ok(
  (
    select count(*) = 13
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = any(array[
        'profiles',
        'platform_admins',
        'platform_plans',
        'platform_plan_prices',
        'clubs',
        'club_plan_history',
        'usage_snapshots',
        'club_settings',
        'roles',
        'permissions',
        'role_permissions',
        'club_members',
        'staff_link_requests'
      ])
      and c.relrowsecurity
  ),
  'Phase 1B-1 tables have RLS enabled'
);

select ok(
  not has_table_privilege('anon', 'public.profiles', 'select'),
  'anon has no implicit select on profiles'
);

select ok(
  not has_table_privilege('authenticated', 'public.profiles', 'select'),
  'authenticated has no implicit select on profiles'
);

create table public.phase_1b_1_throwaway_default_privileges (
  id integer generated always as identity primary key
);

create function public.phase_1b_1_throwaway_default_privileges_fn()
returns integer
language sql
as $$
  select 1;
$$;

revoke execute on all functions in schema public from public, anon, authenticated;

select ok(
  not has_table_privilege('anon', 'public.phase_1b_1_throwaway_default_privileges', 'select')
    and not has_table_privilege('authenticated', 'public.phase_1b_1_throwaway_default_privileges', 'select'),
  'default table privileges do not leak to anon or authenticated'
);

select ok(
  not has_sequence_privilege('anon', 'public.phase_1b_1_throwaway_default_privileges_id_seq', 'usage')
    and not has_sequence_privilege('authenticated', 'public.phase_1b_1_throwaway_default_privileges_id_seq', 'usage'),
  'default sequence privileges do not leak to anon or authenticated'
);

select ok(
  not has_function_privilege('anon', 'public.phase_1b_1_throwaway_default_privileges_fn()', 'execute')
    and not has_function_privilege('authenticated', 'public.phase_1b_1_throwaway_default_privileges_fn()', 'execute'),
  'explicit function revokes do not leak to anon or authenticated'
);

select ok(
  not exists (
    with allowlist(function_identity) as (
      select unnest(array[]::text[])
    )
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where n.nspname = 'public'
      and p.oid::regprocedure::text not in (select function_identity from allowlist)
      and acl.privilege_type = 'EXECUTE'
      and acl.grantee in (
        0,
        (select oid from pg_roles where rolname = 'anon'),
        (select oid from pg_roles where rolname = 'authenticated')
      )
  ),
  'no public function grants execute to anon, authenticated, or public'
);

select is(
  (select code from public.platform_plans where code = 'pilot_free'),
  'pilot_free',
  'pilot_free platform plan is seeded'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'club_members'
      and indexname = 'club_members_phone_e164_uidx'
  ),
  'club member phone uniqueness is scoped by club'
);

select * from finish();

rollback;
