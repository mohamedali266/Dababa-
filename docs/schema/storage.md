# Storage, Audit, Export and Deletion Schema

### `audit_log`

Append-only sensitive action log.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | nullable references `clubs(id)` |
| `actor_profile_id` | `uuid` | nullable references `profiles(id)` |
| `action` | `text` | not null |
| `target_table` | `text` | nullable |
| `target_id` | `uuid` | nullable |
| `severity` | `audit_severity` | not null default `info` |
| `metadata` | `jsonb` | not null default `{}` |
| `ip_hash` | `text` | nullable |
| `user_agent` | `text` | nullable |
| `created_at` | `timestamptz` | not null default `now()` |

Constraints:
- UPDATE and DELETE are revoked from all app roles and also blocked by a `before update or delete` trigger that raises an exception.
- metadata must be scrubbed: no payment proof URLs, no secrets, no raw health values unless required for audit.

Tenant scoped: optional. Platform actions have `club_id null`; tenant actions set `club_id`.

Audit readers:
- super admins with MFA can read all audit rows.
- owners can read audit rows for their own club.
- staff with `audit.read` can read audit rows for their own club except platform-admin tenant-viewing entries.
- ordinary members cannot read audit logs.

### `data_export_requests`

Account export workflow.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `profile_id` | `uuid` | not null references `profiles(id)` |
| `status` | `text` | not null check in `queued`, `processing`, `ready`, `failed`, `expired` |
| `export_path` | `text` | nullable |
| `requested_at` | `timestamptz` | not null default `now()` |
| `ready_at` | `timestamptz` | nullable |
| `expires_at` | `timestamptz` | nullable |

Tenant scoped: no.

### `account_deletion_requests`

Account deletion workflow.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `profile_id` | `uuid` | not null references `profiles(id)` |
| `status` | `text` | not null check in `requested`, `exported`, `deleted`, `cancelled`, `failed` |
| `requested_at` | `timestamptz` | not null default `now()` |
| `scheduled_for` | `timestamptz` | not null |
| `completed_at` | `timestamptz` | nullable |

Tenant scoped: no.


## Storage Buckets and Path Policies

Buckets are private.

| Bucket | Paths | Access |
|---|---|---|
| `club-logos` | `{club_id}/logo/{uuid}.{ext}` | read via signed URL to active members; write `club.settings` |
| `member-photos` | `{club_id}/{club_member_id}/{uuid}.{ext}` | read via signed URL to member self and staff with `members.read`; write member self or `members.write` |
| `payment-proofs` | `{club_id}/{club_member_id}/{payment_id}/{uuid}.{ext}` | read staff with `payments.read` and member self; write member self for pending transfer |
| `exports` | `{profile_id}/{request_id}/export.zip` | signed URL for owner only, expires quickly |

Upload rules:
- server validates MIME type and size.
- server renames file; never trust client filename.
- images: allow `image/jpeg`, `image/png`, `image/webp`.
- payment proof max size proposed: 5 MB.
- member photo max size proposed: 3 MB.
- path traversal prevented by generated path segments only.

## Audit Log Design

Audit these actions:
- club create/edit/suspend/archive.
- owner assignment and staff account/link-request acceptance/revocation.
- role and permission changes.
- member creation/import/deactivation.
- subscription create/freeze/cancel/renew.
- payment approve/reject/void/refund.
- attendance manual override.
- super admin viewing tenant data.
- data export request/download.
- account deletion request/completion.
- QR key rotation.

Implementation:
- App calls `insert_audit_log(...)` security-definer function.
- Table has insert-only policy through function; no update/delete for app roles.
- Metadata contains IDs and high-level state changes, not secrets or sensitive raw health data.

## Account Export and Deletion

Export:
- User requests export.
- System creates `data_export_requests`.
- Worker gathers profile, memberships, payments, subscriptions, attendance, workout logs, body measurements, notifications.
- Sensitive files are included through controlled server access.
- Export saved in private `exports` bucket and served with short-lived signed URL.
- Export expires and file is deleted.

Deletion:
- User requests deletion.
- If export not completed, offer export first.
- After grace period, hard delete `auth.users` and cascading `profiles` where legally allowed.
- Business records that must remain for club accounting are retained but anonymized.
- Erased:
  - `profiles.email`, `profiles.phone_e164`, names, avatar path, locale preferences tied only to the person.
  - member photos and payment proof files from storage.
  - member-owned health/progress data: `workout_logs`, `workout_log_sets`, `body_measurements`.
  - push subscriptions and notifications for the deleted profile.
- Anonymized:
  - `club_members.profile_id` is replaced with a deleted-profile tombstone where retention is required, and display fields become "Deleted member".
  - `payments.club_member_id` may remain for accounting continuity, but payment proof path, reference, and personal metadata are cleared or replaced with `[deleted]`.
  - `audit_log.actor_profile_id` is set to null or a deleted-profile tombstone; metadata personal fields are scrubbed.
- Retained:
  - payment amount, currency, method, status, created/reviewed/refunded timestamps, and accounting reason fields.
  - subscription date ranges and club-level financial history.
  - append-only audit rows after scrubbing.
- Member-owned health data is hard deleted.
- Completion is audited without sensitive payload.

