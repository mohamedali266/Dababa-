# Attendance Schema

### `attendance`

Entry attempts and accepted visits.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `club_member_id` | `uuid` | nullable references `club_members(id)` |
| `scanned_by` | `uuid` | nullable references `profiles(id)` |
| `method` | `attendance_method` | not null |
| `result` | `attendance_result` | not null |
| `qr_jti` | `uuid` | nullable |
| `occurred_at` | `timestamptz` | not null default `now()` |
| `dedupe_key` | `text` | nullable |
| `notes` | `text` | nullable |

Constraints:
- unique `(club_id, club_member_id, dedupe_key)` where `dedupe_key is not null`.
- unique `(club_id, qr_jti)` where `qr_jti is not null` to prevent token replay.

Tenant scoped: yes.


## QR Token and Attendance Dedupe

Token:
- Signed with `jose` using server-only `QR_SIGNING_SECRET`.
- Header includes `kid`.
- Claims: `membership_id`, `club_id`, `iat`, `exp`, `jti`.
- Token TTL is exactly 45 seconds.
- UI refresh interval is exactly 30 seconds.
- Allowed verification clock skew is exactly 5 seconds.
- Member endpoint requires auth, active membership, valid subscription, rate limit.

Verification:
- Staff scan route verifies signature and expiry.
- Staff must have active membership in same club and `attendance.scan`.
- Membership must be active and subscription valid.
- Response includes only reception fields: name, avatar signed URL, member number, plan/subscription state.

Dedupe:
- `qr_jti` unique per club prevents replay in the database. In-memory replay state is forbidden because the app runs on serverless.
- If the same `jti` is scanned twice by an authorized scanner for the same `club_id`, return the original attendance verification result and do not insert a second attendance row.
- The repeated-result response is visible only to staff who currently have `attendance.scan` in the same club, or super admins through audit/support tooling.
- A `jti` presented for another `club_id` is rejected.
- A `jti` presented by staff without same-club access or without `attendance.scan` is rejected before returning any prior result.
- `dedupe_key = club_member_id + floor(occurred_at / 90 seconds)` prevents repeated accepted records from the same scan window.
- Same-window scans with a different valid `jti` return the existing accepted attendance according to the dedupe key and may record a `duplicate` attempt, but never create a second accepted attendance row.

