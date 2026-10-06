## 4. Domain decisions (already made, follow them)

**Identity and tenancy**

- One global account per person (`profiles`, linked to `auth.users`). Membership in a club is a separate record (`club_members`). A person can have many memberships.
- The **active club** is chosen by the user and stored server-side or in a signed cookie, then **re-validated against the database on every request**. Never trust a `club_id` coming from the client without checking membership.
- Every tenant table has a `club_id` column and Row Level Security. Tenant isolation is enforced **in the database**, not only in application code.

**Roles**

- `super_admin` (platform), `owner`, `staff` with granular permissions, `member`.
- Do NOT hard-code role checks all over the code. Use `roles`, `permissions`, and a single permission-check function in SQL and a matching helper in TypeScript. Example permissions: `members.read`, `members.write`, `subscriptions.manage`, `payments.record`, `payments.approve`, `plans.manage`, `attendance.scan`, `club.settings`.
- A user must never be able to change their own role or permissions.

**Member-owned data**

- Workout logs and body measurements belong to the **member's profile**, and every record carries the `club_id` where it was created.
- A club can read member-owned data **only while that member has an active membership in that club**, and only the records created under that `club_id`. When membership ends, club access closes; the member keeps their own history.
- Training plans, nutrition plans, plan templates, exercise library entries, packages and branding belong to the **club**.

**Payments**

- Cash is recorded manually by staff. Online-wallet / InstaPay-style transfers use a **proof-of-payment flow**: the member uploads a screenshot and reference number, staff reviews and approves or rejects, and approval activates or extends the subscription.
- `payments` has `method`, `status` (`pending`, `approved`, `rejected`, `refunded`), `amount`, `currency`, `reference`, `proof_path`, `reviewed_by`, `reviewed_at`. A payment gateway with webhooks will be added later without changing this table's meaning.
- Money is stored as integer minor units (piasters). Never floats.
- Approving a payment must be **idempotent** and **transactional** (one database function), so double clicks or retries cannot create two subscriptions.

**Digital card and QR**

- The QR contains a **server-signed, short-lived token** (use `jose`, signed with a server-only secret, include `kid` to allow rotation). Claims: membership id, club id, `iat`, `exp` (about 45 seconds, UI refreshes every 30), random `jti`.
- The member app fetches a fresh token from an authenticated endpoint. Rate-limit it.
- Staff scan from the PWA. Verification runs **on the server**: signature, expiry, staff belongs to the same club and has `attendance.scan`, membership is active and the subscription is valid. Response contains only what reception needs (name, photo, plan state). Record attendance with a dedupe window so one scan cannot create duplicates.
- Offline: the member's card page opens offline (name, club, member number, last known status) but **does not show a QR without a connection**; show a clear message and the member number so reception can look the member up manually. Do not store signing secrets on the device.

**Per-club settings**

- Branding: name (ar/en), logo, one accent color. Feature flags for modules (gym module only now). Whether a profile photo is required for members.

