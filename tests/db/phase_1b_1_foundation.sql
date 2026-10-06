begin;

select plan(35);

select has_extension('pgcrypto');
select has_extension('btree_gist');
select has_extension('pg_trgm');
select has_extension('citext');

select has_enum('public', 'club_status');
select has_enum('public', 'member_status');
select has_enum('public', 'staff_status');
select has_enum('public', 'record_source');

select has_table('public', 'profiles');
select has_table('public', 'platform_admins');
select has_table('public', 'platform_plans');
select has_table('public', 'platform_plan_prices');
select has_table('public', 'clubs');
select has_table('public', 'club_plan_history');
select has_table('public', 'usage_snapshots');
select has_table('public', 'club_settings');
select has_table('public', 'roles');
select has_table('public', 'permissions');
select has_table('public', 'role_permissions');
select has_table('public', 'club_members');
select has_table('public', 'staff_link_requests');

select has_column('public', 'profiles', 'must_change_password');
select has_column('public', 'club_settings', 'require_member_phone');
select has_column('public', 'club_members', 'phone_e164');
select has_column('public', 'club_members', 'temp_password_expires_at');

select col_default_is('public', 'profiles', 'must_change_password', 'false');
select col_default_is('public', 'club_settings', 'require_member_phone', 'true');

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
  'default function privileges do not leak to anon or authenticated'
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
