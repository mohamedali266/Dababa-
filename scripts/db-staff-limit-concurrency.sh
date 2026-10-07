#!/usr/bin/env bash
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_dababa-local}"
PSQL=(docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q)

"${PSQL[@]}" <<'SQL'
insert into auth.users (id, email) values
  ('90000000-0000-0000-0000-000000000001', 'concurrency-manager@example.test'),
  ('90000000-0000-0000-0000-000000000002', 'concurrency-one@example.test'),
  ('90000000-0000-0000-0000-000000000003', 'concurrency-two@example.test');

insert into public.profiles (id, email, full_name_ar, must_change_password) values
  ('90000000-0000-0000-0000-000000000001', 'concurrency-manager@example.test', 'Concurrency Manager', false),
  ('90000000-0000-0000-0000-000000000002', 'concurrency-one@example.test', 'Concurrency One', true),
  ('90000000-0000-0000-0000-000000000003', 'concurrency-two@example.test', 'Concurrency Two', true);

update public.platform_plans set max_staff = 2 where code = 'pilot_free';

insert into public.clubs (id, slug, platform_plan_id, name_ar, name_en, status)
values ('90000000-0000-0000-0000-000000000010', 'concurrency-club', (select id from public.platform_plans where code = 'pilot_free'), 'Concurrency Club', 'Concurrency Club', 'active');

update public.profiles
set provisioned_by_club_id = '90000000-0000-0000-0000-000000000010'
where id in ('90000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000003');

insert into public.roles (id, club_id, key, name_ar, name_en, is_system) values
  ('90000000-0000-0000-0000-000000000101', '90000000-0000-0000-0000-000000000010', 'manager', 'Manager', 'Manager', true),
  ('90000000-0000-0000-0000-000000000102', '90000000-0000-0000-0000-000000000010', 'trainer', 'Trainer', 'Trainer', true);

insert into public.permissions (id, key, description)
values ('90000000-0000-0000-0000-000000000201', 'staff.manage', 'Manage staff')
on conflict (key) do nothing;

insert into public.role_permissions (role_id, permission_id)
select '90000000-0000-0000-0000-000000000101', id from public.permissions where key = 'staff.manage';

insert into public.club_members (id, club_id, profile_id, member_number, role_id, status, created_by)
values ('90000000-0000-0000-0000-000000000301', '90000000-0000-0000-0000-000000000010', '90000000-0000-0000-0000-000000000001', 'C-001', '90000000-0000-0000-0000-000000000101', 'active', '90000000-0000-0000-0000-000000000001');
SQL

run_add() {
  local profile_id="$1"
  "${PSQL[@]}" <<SQL
set role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', false);
select set_config('request.jwt.claim.role', 'authenticated', false);
select public.create_club_member_for_new_profile(
  '90000000-0000-0000-0000-000000000010',
  '$profile_id',
  '90000000-0000-0000-0000-000000000102'
);
SQL
}

set +e
run_add '90000000-0000-0000-0000-000000000002' > /tmp/dababa-concurrency-1.log 2>&1 &
pid1=$!
run_add '90000000-0000-0000-0000-000000000003' > /tmp/dababa-concurrency-2.log 2>&1 &
pid2=$!
wait "$pid1"; status1=$?
wait "$pid2"; status2=$?
set -e

successes=0
failures=0
[[ "$status1" -eq 0 ]] && successes=$((successes + 1)) || failures=$((failures + 1))
[[ "$status2" -eq 0 ]] && successes=$((successes + 1)) || failures=$((failures + 1))

cat /tmp/dababa-concurrency-1.log
cat /tmp/dababa-concurrency-2.log

if [[ "$successes" -ne 1 || "$failures" -ne 1 ]]; then
  echo "Expected exactly one concurrent staff add to succeed, got successes=$successes failures=$failures" >&2
  exit 1
fi

echo "staff-limit concurrency: successes=1 failures=1"
