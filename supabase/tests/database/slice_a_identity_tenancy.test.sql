begin;

select no_plan();

select has_table('public', 'club_members', 'club_members table exists');
select has_table('public', 'audit_logs', 'audit_logs table exists');
select has_function('private', 'write_audit', array['text', 'uuid', 'text', 'uuid', 'jsonb']::name[], 'private write_audit helper exists');
select isnt_empty($$select 1 from pg_trigger where tgname = 'audit_logs_append_only' and tgrelid = 'public.audit_logs'::regclass$$, 'audit_logs has append-only trigger');
select has_function('private', 'is_super_admin', array[]::name[], 'private is_super_admin helper exists');
select has_function('private', 'is_club_member', array['uuid']::name[], 'private is_club_member helper exists');
select has_function('private', 'has_permission', array['uuid', 'text']::name[], 'private has_permission helper exists');
select policies_are('public', 'club_members', array['club_members_select_authorized'], 'club_members has only select policy');
select isnt_empty($$select 1 from pg_policies where schemaname = 'public' and tablename = 'club_members' and policyname = 'club_members_select_authorized' and qual is not null and qual like '%SELECT auth.uid%' and with_check is null$$, 'club_members select uses explicit USING with select auth.uid');
select isnt_empty($$select 1 from information_schema.table_privileges where table_schema = 'public' and table_name = 'club_members' and grantee = 'authenticated' and privilege_type = 'SELECT'$$, 'authenticated can select club_members');
select is_empty($$select 1 from information_schema.table_privileges where table_schema = 'public' and table_name = 'club_members' and grantee = 'authenticated' and privilege_type in ('INSERT','UPDATE','DELETE')$$, 'authenticated cannot directly mutate club_members');
select isnt_empty($$select 1 from information_schema.table_constraints where table_schema = 'public' and table_name = 'club_members' and constraint_name = 'club_members_role_same_club_fk' and constraint_type = 'FOREIGN KEY'$$, 'club_members has composite role same-club FK');
select isnt_empty($$select 1 from information_schema.table_constraints where table_schema = 'public' and table_name = 'roles' and constraint_name = 'roles_club_id_id_unique' and constraint_type = 'UNIQUE'$$, 'roles has unique (club_id,id)');
select isnt_empty($$select 1 from information_schema.table_constraints where table_schema = 'public' and table_name = 'club_members' and constraint_name = 'club_members_status_left_at_check' and constraint_type = 'CHECK'$$, 'club_members has status/left_at check');
select is_empty($$select 1 from pg_constraint where confrelid = 'public.club_members'::regclass and confdeltype = 'c'$$, 'no FK references club_members with ON DELETE CASCADE');
select is_empty($$select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace join information_schema.routine_privileges rp on rp.routine_schema = n.nspname and rp.routine_name = p.proname where n.nspname = 'public' and rp.grantee in ('anon','public')$$, 'no public function executable by anon or public');
select set_eq(
  $$select rp.routine_name from information_schema.routine_privileges rp where rp.routine_schema = 'public' and rp.grantee = 'authenticated' order by 1$$,
  $$values ('accept_staff_link_request'), ('change_club_member_role'), ('change_club_member_status'), ('create_club_member_for_new_profile'), ('create_staff_link_request'), ('leave_club')$$,
  'authenticated can execute exactly the public RPC wrapper allowlist'
);
select is_empty($$select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace join information_schema.routine_privileges rp on rp.routine_schema = n.nspname and rp.routine_name = p.proname where n.nspname = 'private' and rp.grantee in ('anon','public')$$, 'no private function executable by anon or public');
select set_eq(
  $$select rp.routine_name from information_schema.routine_privileges rp where rp.routine_schema = 'private' and rp.grantee = 'authenticated' order by 1$$,
  $$values ('has_permission'), ('is_club_member'), ('is_super_admin')$$,
  'authenticated can execute only private helper functions'
);
select isnt_empty($$select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace join pg_roles r on r.oid = p.proowner where n.nspname = 'private' and p.proname in ('is_super_admin','is_club_member','has_permission') and p.prosecdef and r.rolbypassrls group by r.rolbypassrls having count(*) = 3$$, 'helper function owner has BYPASSRLS');
select isnt_empty($$select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'check_member_or_staff_limit' and pg_get_functiondef(p.oid) ilike '%for update of locked_club%'$$, 'concurrent add guarded by FOR UPDATE entitlement lock');

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'owner@example.test'),
  ('00000000-0000-0000-0000-000000000002', 'manager@example.test'),
  ('00000000-0000-0000-0000-000000000003', 'member@example.test'),
  ('00000000-0000-0000-0000-000000000004', 'other@example.test'),
  ('00000000-0000-0000-0000-000000000005', 'new@example.test'),
  ('00000000-0000-0000-0000-000000000006', 'super@example.test'),
  ('00000000-0000-0000-0000-000000000007', 'limit-one@example.test'),
  ('00000000-0000-0000-0000-000000000008', 'limit-two@example.test'),
  ('00000000-0000-0000-0000-000000000009', 'accepted@example.test');

insert into public.profiles (id, email, full_name_ar) values
  ('00000000-0000-0000-0000-000000000001', 'owner@example.test', 'Owner'),
  ('00000000-0000-0000-0000-000000000002', 'manager@example.test', 'Manager'),
  ('00000000-0000-0000-0000-000000000003', 'member@example.test', 'Member'),
  ('00000000-0000-0000-0000-000000000004', 'other@example.test', 'Other'),
  ('00000000-0000-0000-0000-000000000005', 'new@example.test', 'New'),
  ('00000000-0000-0000-0000-000000000006', 'super@example.test', 'Super'),
  ('00000000-0000-0000-0000-000000000007', 'limit-one@example.test', 'Limit One'),
  ('00000000-0000-0000-0000-000000000008', 'limit-two@example.test', 'Limit Two'),
  ('00000000-0000-0000-0000-000000000009', 'accepted@example.test', 'Accepted');

update public.profiles
set must_change_password = true
where id in (
  '00000000-0000-0000-0000-000000000007',
  '00000000-0000-0000-0000-000000000008'
);

insert into public.platform_admins (profile_id) values ('00000000-0000-0000-0000-000000000006');
update public.platform_plans set max_staff = 4, max_members = 10 where code = 'pilot_free';

insert into public.clubs (id, slug, platform_plan_id, name_ar, name_en, status) values
  ('10000000-0000-0000-0000-000000000001', 'club-a', (select id from public.platform_plans where code = 'pilot_free'), 'Club A', 'Club A', 'active'),
  ('10000000-0000-0000-0000-000000000002', 'club-b', (select id from public.platform_plans where code = 'pilot_free'), 'Club B', 'Club B', 'active'),
  ('10000000-0000-0000-0000-000000000003', 'club-suspended', (select id from public.platform_plans where code = 'pilot_free'), 'Club S', 'Club S', 'suspended');

update public.profiles
set provisioned_by_club_id = '10000000-0000-0000-0000-000000000001'
where id in (
  '00000000-0000-0000-0000-000000000007',
  '00000000-0000-0000-0000-000000000008'
);

insert into public.roles (id, club_id, key, name_ar, name_en, is_system) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'owner', 'Owner', 'Owner', true),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'manager', 'Manager', 'Manager', true),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'member', 'Member', 'Member', true),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'member', 'Member', 'Member', true),
  ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'reader', 'Reader', 'Reader', true),
  ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000003', 'manager', 'Manager', 'Manager', true),
  ('20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000001', 'accountant', 'Accountant', 'Accountant', true);

insert into public.permissions (id, key, description) values
  ('30000000-0000-0000-0000-000000000001', 'staff.manage', 'Manage staff'),
  ('30000000-0000-0000-0000-000000000002', 'members.read', 'Read members'),
  ('30000000-0000-0000-0000-000000000003', 'roles.manage', 'Manage roles'),
  ('30000000-0000-0000-0000-000000000004', 'payments.approve', 'Approve payments');

insert into public.role_permissions (role_id, permission_id) values
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002'),
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003'),
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000004'),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000002'),
  ('20000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000004');

insert into public.club_members (id, club_id, profile_id, member_number, role_id, status, created_by) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'A-001', '20000000-0000-0000-0000-000000000001', 'active', '00000000-0000-0000-0000-000000000001'),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'A-002', '20000000-0000-0000-0000-000000000002', 'active', '00000000-0000-0000-0000-000000000001'),
  ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'A-003', '20000000-0000-0000-0000-000000000007', 'active', '00000000-0000-0000-0000-000000000001'),
  ('40000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000004', 'B-001', '20000000-0000-0000-0000-000000000004', 'active', '00000000-0000-0000-0000-000000000004'),
  ('40000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 'S-001', '20000000-0000-0000-0000-000000000006', 'active', '00000000-0000-0000-0000-000000000002');

select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select results_eq($$select count(*)::integer from public.club_members$$, array[1], 'plain member cannot read other members');
select results_eq($$select count(*)::integer from public.club_members where club_id = '10000000-0000-0000-0000-000000000002'$$, array[0], 'cross-club member read denied');
select ok(private.is_club_member('10000000-0000-0000-0000-000000000001'), 'is_club_member works with FORCE RLS enabled');
select ok(not private.has_permission('10000000-0000-0000-0000-000000000001', 'members.read'), 'plain member lacks members.read');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select results_eq($$select count(*)::integer from public.club_members where club_id = '10000000-0000-0000-0000-000000000001'$$, array[3], 'staff.manage can read club members');
select ok(private.has_permission('10000000-0000-0000-0000-000000000001', 'staff.manage'), 'staff.manage helper positive');
select ok(not private.has_permission('10000000-0000-0000-0000-000000000003', 'staff.manage'), 'suspended club staff lose permissions');

reset role;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select throws_ok($$select public.change_club_member_role('40000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000005')$$, '42501', null, 'staff.manage cannot grant role with permissions they lack');
select throws_ok($$select public.change_club_member_role('40000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003')$$, '42501', null, 'caller cannot edit accountant target with payments.approve they lack');
select throws_ok($$select public.change_club_member_role('40000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001')$$, '42501', null, 'cannot assign owner');
select throws_ok($$select public.change_club_member_role('40000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003')$$, '42501', null, 'caller cannot edit self');
select throws_ok($$select public.change_club_member_status('40000000-0000-0000-0000-000000000001', 'left')$$, '42501', null, 'owner target blocked');
select throws_ok($$select public.create_club_member_for_new_profile('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003')$$, '42501', null, 'cannot add existing profile without acceptance');

set local role authenticated;
select throws_ok($$update public.club_members set profile_id = '00000000-0000-0000-0000-000000000005' where id = '40000000-0000-0000-0000-000000000003'$$, '42501', null, 'cannot change profile_id directly');
select throws_ok($$update public.club_members set club_id = '10000000-0000-0000-0000-000000000002' where id = '40000000-0000-0000-0000-000000000003'$$, '42501', null, 'cannot change club_id directly');
select throws_ok($$update public.club_members set created_by = '00000000-0000-0000-0000-000000000003' where id = '40000000-0000-0000-0000-000000000003'$$, '42501', null, 'cannot change created_by directly');
select throws_ok($$delete from public.club_members where id = '40000000-0000-0000-0000-000000000003'$$, '42501', null, 'cannot delete directly');
select throws_ok($$update public.profiles set must_change_password = true where id = '00000000-0000-0000-0000-000000000002'$$, '42501', null, 'cannot change must_change_password directly');
select throws_ok($$update public.profiles set provisioned_by_club_id = '10000000-0000-0000-0000-000000000001' where id = '00000000-0000-0000-0000-000000000002'$$, '42501', null, 'cannot change provisioned_by_club_id directly');

reset role;
select throws_ok($$insert into public.club_members (club_id, profile_id, member_number, role_id, status, created_by) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 'A-005', '20000000-0000-0000-0000-000000000004', 'active', '00000000-0000-0000-0000-000000000002')$$, '23503', null, 'cross-club role fails at DB level');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000006', true);
select set_config('request.jwt.claim.aal', 'aal1', true);
set local role authenticated;
select ok(not private.is_super_admin(), 'aal1 super admin denied');
select results_eq($$select count(*)::integer from public.club_members$$, array[0], 'direct super-admin SELECT is not available through club_members policy');
reset role;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select lives_ok($$select public.create_club_member_for_new_profile('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000002')$$, 'staff limit at limit-1 allows add up to limit');
select results_eq($$select count(*)::integer from public.audit_logs where action = 'club_member.create' and metadata->>'source' = 'new_profile'$$, array[1], 'add member writes exactly one audit row');
select throws_ok($$select public.create_club_member_for_new_profile('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000008', '20000000-0000-0000-0000-000000000002')$$, '23514', null, 'staff limit at limit blocks limit+1 add');

update public.platform_plans set max_staff = 8 where code = 'pilot_free';

select lives_ok($$select public.create_staff_link_request('10000000-0000-0000-0000-000000000001', 'accepted@example.test'::extensions.citext, '20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000009')$$, 'create staff-link request succeeds');
select results_eq($$select count(*)::integer from public.audit_logs where action = 'staff_link_request.create'$$, array[1], 'create staff-link request writes exactly one audit row');
select ok((select expires_at between now() + interval '6 days 23 hours' and now() + interval '7 days 1 minute' from public.staff_link_requests where target_profile_id = '00000000-0000-0000-0000-000000000009'), 'staff-link request expiry is server-fixed at seven days');
select throws_ok($$select public.create_staff_link_request('10000000-0000-0000-0000-000000000001', 'accepted@example.test'::extensions.citext, '20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000009')$$, '23505', null, 'max one pending staff-link request per club profile');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000009', true);
select lives_ok($$select public.accept_staff_link_request((select id from public.staff_link_requests where target_profile_id = '00000000-0000-0000-0000-000000000009'))$$, 'add member via accepted request succeeds');
select results_eq($$select count(*)::integer from public.audit_logs where action = 'staff_link_request.accept'$$, array[1], 'accepted request writes exactly one audit row');
select lives_ok($$select public.leave_club()$$, 'member can leave club themself');
select results_eq($$select count(*)::integer from public.audit_logs where action = 'club_member.self_leave'$$, array[1], 'leave_club writes exactly one audit row');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select lives_ok($$select public.create_staff_link_request('10000000-0000-0000-0000-000000000001', 'accepted@example.test'::extensions.citext, '20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000009')$$, 'create rejoin request for left member succeeds');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000009', true);
select lives_ok($$select public.accept_staff_link_request((select id from public.staff_link_requests where target_profile_id = '00000000-0000-0000-0000-000000000009' and accepted_at is null))$$, 'left member rejoins through acceptance');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select lives_ok($$select public.change_club_member_role('40000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002')$$, 'owner can change member role within caller permissions');
select results_eq($$select count(*)::integer from public.audit_logs where action = 'club_member.role_change'$$, array[1], 'change role writes exactly one audit row');
select lives_ok($$select public.change_club_member_status('40000000-0000-0000-0000-000000000003', 'left')$$, 'change status to left succeeds');
select results_eq($$select count(*)::integer from public.audit_logs where action = 'club_member.status_change'$$, array[1], 'change status writes exactly one audit row');
select throws_ok($$select public.change_club_member_status('40000000-0000-0000-0000-000000000003', 'active')$$, '42501', null, 'left to active is blocked without acceptance');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select ok(not private.has_permission('10000000-0000-0000-0000-000000000001', 'staff.manage'), 'member with status left loses permissions');

select throws_ok($$update public.audit_logs set metadata = '{}'::jsonb$$, '42501', null, 'audit log is immutable on update');
select throws_ok($$delete from public.audit_logs$$, '42501', null, 'audit log is immutable on delete');
select throws_ok($$truncate public.audit_logs$$, '42501', null, 'audit log is immutable on truncate');

select finish();

rollback;
