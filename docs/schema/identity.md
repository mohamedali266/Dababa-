# Identity Schema

### `profiles`

Global account profile linked to Supabase Auth.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK, references `auth.users(id)` on delete cascade |
| `email` | `citext` | nullable, unique where not null |
| `phone_e164` | `text` | nullable, normalized E.164 for contact only, not unique platform-wide |
| `full_name_ar` | `text` | not null |
| `full_name_en` | `text` | nullable |
| `avatar_path` | `text` | nullable |
| `preferred_locale` | `text` | not null default `ar`, check in `('ar','en')` |
| `timezone` | `text` | not null default `Africa/Cairo` |
| `must_change_password` | `boolean` | not null default false |
| `deleted_at` | `timestamptz` | nullable |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |

Indexes:
- unique lower email where `email is not null`.
- `profiles_deleted_at_idx`.

Tenant scoped: no.

### `platform_admins`

Separate platform administrator registry. Platform admin status is not stored on `profiles`.

| Column | Type | Constraints |
|---|---|---|
| `profile_id` | `uuid` | PK, references `profiles(id)` on delete cascade |
| `granted_by` | `uuid` | nullable references `profiles(id)` |
| `mfa_required` | `boolean` | not null default true |
| `created_at` | `timestamptz` | not null default `now()` |
| `revoked_at` | `timestamptz` | nullable |

Rules:
- Writable only by migrations or a protected super-admin function.
- Super admin access requires a live platform admin row and JWT assurance level `aal2` in the current session.
- All super admin tenant reads are audited.

Tenant scoped: no.


### `roles`

Club role definitions and role templates.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` on delete cascade |
| `key` | `text` | not null |
| `name_ar` | `text` | not null |
| `name_en` | `text` | not null |
| `is_system` | `boolean` | not null default false |
| `created_at` | `timestamptz` | not null default `now()` |

Constraints:
- unique `(club_id, key)`.
- role template keys include `owner`, `member`, `trainer`, `reception`, `accountant`, and `manager`.
- custom permission tweaks create or update club-scoped roles; no platform/global role rows are needed.

Tenant scoped: yes.

### `permissions`

Permission registry.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `key` | `text` | not null unique |
| `description` | `text` | not null |
| `created_at` | `timestamptz` | not null default `now()` |

Tenant scoped: no.

### `role_permissions`

Many-to-many role permission assignment.

| Column | Type | Constraints |
|---|---|---|
| `role_id` | `uuid` | references `roles(id)` on delete cascade |
| `permission_id` | `uuid` | references `permissions(id)` on delete cascade |
| `created_at` | `timestamptz` | not null default `now()` |

Constraints:
- PK `(role_id, permission_id)`.

Tenant scoped: inherited through `roles.club_id`.

### `club_members`

Membership/relationship between a profile and a club.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` on delete restrict |
| `profile_id` | `uuid` | not null references `profiles(id)` on delete cascade |
| `member_number` | `text` | not null |
| `phone_e164` | `text` | nullable, normalized E.164, validated on input |
| `role_id` | `uuid` | not null references `roles(id)` |
| `status` | `member_status` | not null default `active` |
| `staff_status` | `staff_status` | nullable |
| `temp_password_required` | `boolean` | not null default false |
| `temp_password_issued_at` | `timestamptz` | nullable |
| `temp_password_expires_at` | `timestamptz` | nullable |
| `sessions_revoked_at` | `timestamptz` | nullable |
| `joined_at` | `timestamptz` | not null default `now()` |
| `left_at` | `timestamptz` | nullable |
| `deactivated_at` | `timestamptz` | nullable |
| `created_by` | `uuid` | nullable references `profiles(id)` |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |

Constraints:
- unique `(club_id, profile_id)` where `left_at is null`.
- unique `(club_id, member_number)`.
- unique `(club_id, phone_e164)` where `phone_e164 is not null`; there is no platform-wide phone uniqueness.
- role must belong to same `club_id` or be an allowed system member role.
- a user cannot update their own `role_id`.
- staff cannot edit their own role or permissions.
- a non-owner staff member cannot edit an owner.
- a creator can grant only permissions they already hold.

Indexes:
- `(profile_id, status)`.
- `(club_id, status)`.
- trigram index on member number and joined profile names through a search view or generated search column.

Tenant scoped: yes.

### `staff_link_requests`

Pending link requests when a staff account email already belongs to an existing profile. There are no email invitations.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `email` | `citext` | not null |
| `role_id` | `uuid` | not null references `roles(id)` |
| `permission_overrides` | `jsonb` | not null default `{}` |
| `requested_by` | `uuid` | not null references `profiles(id)` |
| `target_profile_id` | `uuid` | nullable references `profiles(id)` |
| `expires_at` | `timestamptz` | not null |
| `accepted_at` | `timestamptz` | nullable |
| `declined_at` | `timestamptz` | nullable |
| `cancelled_at` | `timestamptz` | nullable |
| `created_at` | `timestamptz` | not null default `now()` |

Tenant scoped: yes.

Staff account creation rules:
- Owner or a user with `staff.manage` enters full name, login email, role template, and optional permission tweaks.
- The server uses a narrowly scoped service-role server function; permission is re-checked inside the function.
- The function takes `club_id` from the authenticated active-club session, never from request body.
- If the email is new, Supabase Auth creates the account with a random temporary password shown once to the creator.
- New temporary-password staff accounts set `profiles.must_change_password = true`, `club_members.staff_status = 'temp_password_pending'`, `temp_password_issued_at = now()`, and `temp_password_expires_at = temp_password_issued_at + interval '24 hours'`.
- Temporary passwords expire after 24 hours. After expiry, the account stays locked until the creator or another authorized staff manager resets the temporary password.
- The server enforces `must_change_password` on every authenticated request in middleware and in every Server Action/route handler. A flagged session can only call the change-password, sign-out, and reset-request flows.
- Fake or placeholder email domains are not allowed.
- First login with a temporary password is restricted to the change-password screen until changed.
- If the email already exists, no account is created and no enumeration signal is leaked; a `staff_link_requests` row is created for in-app acceptance.
- Reset, suspend, and remove staff revoke existing sessions, are audited, and are rate-limited.
- Tests must cover temp-password lifecycle, login before expiry, login after expiry denied, login after reset allowed, forced change, middleware/action enforcement of `must_change_password`, enumeration resistance, privilege escalation, and session revocation.


## Permission Model

### Permission keys

Initial registry:

- `club.settings`
- `members.read`
- `members.write`
- `members.import`
- `members.deactivate`
- `staff.manage`
- `roles.manage`
- `subscriptions.read`
- `subscriptions.manage`
- `subscriptions.freeze`
- `subscriptions.freeze.override`
- `payments.read`
- `payments.record`
- `payments.approve`
- `payments.void`
- `payments.refund`
- `attendance.scan`
- `attendance.read`
- `plans.manage`
- `plans.assign`
- `progress.read`
- `progress.write_for_member`
- `nutrition.manage`
- `notifications.manage`
- `audit.read`

### Default roles

| Role | Permissions |
|---|---|
| `owner` | all club permissions except platform-only actions |
| `trainer` | `members.read`, `plans.manage`, `plans.assign`, `progress.read`, `progress.write_for_member`, `nutrition.manage` |
| `reception` | `members.read`, `attendance.scan`, `attendance.read`, `subscriptions.read`, `payments.read`, `payments.record` |
| `accountant` | `members.read`, `subscriptions.read`, `payments.read`, `payments.record`, `payments.approve`, `payments.void`, `payments.refund` |
| `manager` | broad operational access: `members.*`, `subscriptions.*` except override unless granted, `payments.read`, `payments.record`, `attendance.*`, `plans.assign`, `progress.read` |
| `member` | self-service only through specific RLS policies, not broad club permissions |
| `super_admin` | platform access through `platform_admins` plus MFA, audited for tenant viewing |

### SQL helper functions

- `current_profile_id() returns uuid`: wraps `auth.uid()`.
- `is_super_admin() returns boolean`: true when current profile has an active `platform_admins` row and `auth.jwt()->>'aal' = 'aal2'`.
- `is_active_club_member(club_id uuid) returns boolean`: membership row where `club_members.status = 'active'`.
- `has_permission(club_id uuid, permission_key text) returns boolean`: active membership with a role granting permission.
- `can_read_member_owned_data(club_id uuid, member_profile_id uuid) returns boolean`: true when requester owns the data, is super admin, or has active membership in the same club and the target member currently has active membership in the same club with the correct permission.
- `club_entitlement(club_id uuid, key text) returns jsonb`: returns a typed JSON object with `allowed boolean`, `limit integer|null`, `current integer|null`, `source text`, and `reason text|null`. It is the single contract used by DB functions and server code for staff limits, member limits, and module availability.

All security-definer helpers must:
- set `search_path = public, pg_temp`.
- validate `auth.uid()` internally.
- be granted only to `authenticated` when needed.
- revoke from `public`.

Security-definer function register:

| Function | Justification |
|---|---|
| `is_super_admin()` | Centralizes platform-admin authorization and verifies a live `platform_admins` row plus JWT `aal2`; avoids duplicating privileged checks in policies. |
| `has_permission(club_id, permission_key)` | Resolves role-permission grants inside RLS without exposing role tables for broad writes. |
| `can_read_member_owned_data(club_id, member_profile_id)` | Keeps sensitive progress-data visibility consistent across workout and measurement policies. |
| `club_entitlement(club_id, key)` | Provides one DB contract for plan limits and module availability used by protected functions and owner counters. |
| `create_staff_account(...)` | Needs a tightly scoped service-role server path to create Supabase Auth users while rechecking caller permission and entitlement in DB. |
| `reset_staff_temporary_password(...)` | Resets a locked temporary-password staff account, revokes sessions, sets 24-hour expiry, and audits the action. |
| `create_member(...)` | Enforces active-club, phone, role, and entitlement checks atomically. |
| `import_members(...)` | Enforces member-limit locking and per-row validation atomically for CSV import. |
| `update_club_module_settings(...)` | Ensures module flags cannot exceed platform entitlements. |
| `freeze_subscription(...)` | Applies freeze limits, shifts later subscriptions, extends end date, and writes audit in one transaction. |
| `record_cash_payment(...)` | Records cash and creates/extends a subscription atomically. |
| `approve_transfer_payment(...)` | Approves proof-based transfer and creates/extends a subscription atomically and idempotently. |
| `void_or_refund_payment(...)` | Enforces correction authority, mandatory reason, immutable original amount, and audit trail. |
| `verify_qr_attendance(...)` | Verifies signed QR claims, same-club staff permission, replay/idempotency, and attendance insertion atomically. |
| `insert_audit_log(...)` | Restricts audit inserts to scrubbed, allow-listed metadata and keeps the table append-only. |
| `run_account_export(...)` | Lets the worker gather private user data and files into an authorized export artifact. |
| `run_account_deletion(...)` | Performs erase/anonymize/retain workflow consistently across private storage and tables. |

Entitlement enforcement:
- staff creation, member creation/import, and module enablement must call protected DB functions that check `club_entitlement`.
- The single locking mechanism is `select 1 from clubs where id = target_club_id for update` before counting current usage.
- `create_staff_account(...)` must lock the club row before counting staff and before creating an auth user or `staff_link_requests` row.
- `create_member(...)` and `import_members(...)` must lock the club row before counting members and before inserting each accepted member row.
- `update_club_module_settings(...)` must lock the club row before checking module entitlement and changing any module flag.
- tests must include two concurrent staff creations at the limit.
- downgrade never deletes data or disables existing accounts; it blocks only new additions above the limit.
- disabled modules become read-only for existing data, not hidden.
- owner usage counters must use the same query/function source as enforcement.

Future billing note:
- billing is out of scope: no invoices, no platform payments, no enforcement by non-payment.
- future monthly amount would use daily `usage_snapshots`, the effective `platform_plan_prices` row for the period, and `min_monthly_fee_minor`.
- intended non-payment behavior is a grace period, then blocking new additions or read-only mode; data is never deleted.

