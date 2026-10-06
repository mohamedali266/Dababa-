# Platform Schema

### `platform_plans`

Dababa platform plans for clubs. These are not member packages; member packages remain `membership_plans`.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `code` | `text` | not null unique |
| `name_ar` | `text` | not null |
| `name_en` | `text` | not null |
| `max_staff` | `integer` | nullable means unlimited, check `> 0` when not null |
| `max_members` | `integer` | nullable means unlimited, check `> 0` when not null |
| `min_monthly_fee_minor` | `integer` | not null default 0, check `>= 0` |
| `allowed_modules` | `text[]` | not null, constrained to `core`, `nutrition`, `notifications`, `csv_import`, `attendance_scanner` |
| `is_active` | `boolean` | not null default true |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |

Seed:
- One default plan allows all currently available modules, with unlimited limits unless the project owner approves stricter launch limits.

Tenant scoped: no.

### `platform_plan_prices`

Versioned per-active-member prices for future billing. Nothing bills in current scope.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `platform_plan_id` | `uuid` | not null references `platform_plans(id)` |
| `price_per_active_member_minor` | `integer` | not null check `>= 0` |
| `currency` | `char(3)` | not null default `EGP` |
| `effective_from` | `date` | not null |
| `created_by` | `uuid` | not null references `profiles(id)` |
| `created_at` | `timestamptz` | not null default `now()` |

Constraints:
- unique `(platform_plan_id, effective_from)`.
- price changes never mutate prior rows.

Tenant scoped: no.

### `clubs`

Top-level tenant.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `slug` | `text` | not null unique, lowercase slug check |
| `status` | `club_status` | not null default `active` |
| `platform_plan_id` | `uuid` | not null references `platform_plans(id)` |
| `trial_started_at` | `timestamptz` | nullable |
| `trial_ends_at` | `timestamptz` | nullable |
| `created_by` | `uuid` | references `profiles(id)` |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |
| `suspended_at` | `timestamptz` | nullable |
| `archived_at` | `timestamptz` | nullable |

Indexes:
- `clubs_status_idx`.

Tenant scoped: tenant root, no parent `club_id`.

### `club_plan_history`

Manual plan/trial changes by super admins.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `from_platform_plan_id` | `uuid` | nullable references `platform_plans(id)` |
| `to_platform_plan_id` | `uuid` | not null references `platform_plans(id)` |
| `from_trial_ends_at` | `timestamptz` | nullable |
| `to_trial_ends_at` | `timestamptz` | nullable |
| `changed_by` | `uuid` | not null references `profiles(id)` |
| `reason` | `text` | not null |
| `created_at` | `timestamptz` | not null default `now()` |

Rules:
- Only super admins can change plan or trial values.
- Owners can read their club plan, trial status, usage, and history summary, but cannot change any of it.
- During trial, the club has the entitlements of the assigned plan; metering continues but no billing happens.
- Trial expiry enforcement is a future design decision; Phase 1B only stores fields and policy boundaries.

Tenant scoped: yes.

### `usage_snapshots`

Daily append-only usage snapshots for future billing and owner usage displays.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `snapshot_date` | `date` | not null |
| `active_member_count` | `integer` | not null check `>= 0` |
| `staff_count` | `integer` | not null check `>= 0` |
| `created_by` | `uuid` | nullable references `profiles(id)` |
| `created_at` | `timestamptz` | not null default `now()` |

Constraints:
- unique `(club_id, snapshot_date)`.
- append-only; only the scheduled job and super admins can write.

Definition:
- Platform billing/metering "active member" means `club_members.status = 'active'` and at least one subscription valid on `snapshot_date`.
- A person in several clubs counts once per club.
- A member with active club membership but expired subscription is not counted for platform metering, even though the club may still read member-owned data under the member-owned data rule.
- Snapshot job is idempotent and runs once per day; reruns for the same `(club_id, snapshot_date)` update nothing or no-op through conflict handling.

Tenant scoped: yes.

### `club_settings`

One row per club.

| Column | Type | Constraints |
|---|---|---|
| `club_id` | `uuid` | PK, references `clubs(id)` on delete cascade |
| `name_ar` | `text` | not null |
| `name_en` | `text` | not null |
| `logo_path` | `text` | nullable |
| `accent_color` | `text` | nullable, hex color check |
| `member_photo_required` | `boolean` | not null default false |
| `require_member_phone` | `boolean` | not null default true |
| `gym_module_enabled` | `boolean` | not null default true |
| `nutrition_module_enabled` | `boolean` | not null default false |
| `notifications_module_enabled` | `boolean` | not null default false |
| `csv_import_enabled` | `boolean` | not null default false |
| `attendance_scanner_enabled` | `boolean` | not null default true |
| `transfer_instructions_ar` | `text` | nullable |
| `transfer_instructions_en` | `text` | nullable |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |

Tenant scoped: yes, `club_id`.

Module enablement must be checked against `club_entitlement(club_id, key)` in the protected update function, not only in the UI.


## Realtime

Realtime is disabled for now. No tables are added to Supabase Realtime publications in Phase 1B. If later enabled, the design must list exact tables and payload fields before implementation.

## Platform Plan Downgrade Behavior

Downgrades never delete data and never disable existing accounts.

| Entitlement/module | When downgraded below current usage or disabled |
|---|---|
| `max_staff` | Existing staff keep access. New staff creation and staff link acceptance are blocked until usage is below limit or plan changes. |
| `max_members` | Existing members remain. New member creation/import rows above limit are blocked; CSV import must fail only rows that exceed the limit and report them. |
| `nutrition` | Existing nutrition plans and assignments are read-only. Creating/editing/assigning nutrition plans is blocked. |
| `notifications` | Existing notifications remain readable. New automated notifications and new push subscription prompts are blocked. |
| `csv_import` | Manual member management remains available subject to `max_members`; CSV import is blocked. |
| `attendance_scanner` | Existing attendance records remain readable. QR/manual scan creation is blocked; member card display remains unaffected. |

Role templates and platform plans are both checked: the role controls what a staff user can do, while the platform plan controls what the club is entitled to use or add.

## Auth Email and SMTP

Supabase's default email sender is not production-grade and should be used only for development/testing. Password reset and member verification still send email.

Brevo SMTP is approved as a candidate for development and the pilot only, for password-reset and verification emails only. It is not the final production email decision. The provider must stay behind an environment-configured adapter (`AUTH_EMAIL_ADAPTER`, `SMTP_PROVIDER`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM_EMAIL`, `SMTP_FROM_NAME`, `SMTP_REQUIRE_TLS`).

Verified official sources, checked 2026-10-07:
- Supabase custom SMTP docs: https://supabase.com/docs/guides/auth/auth-smtp
- Brevo pricing plan docs: https://help.brevo.com/hc/en-us/articles/208589409-About-Brevo-s-pricing-plans
- Brevo free-plan limits docs: https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan
- Brevo transactional email page: https://www.brevo.com/products/transactional-email/
- Brevo sender/domain authentication docs: https://help.brevo.com/hc/en-us/articles/12163873383186-Authenticate-your-domain-with-Brevo-Brevo-code-DKIM-DMARC
- Brevo sender requirements for Gmail/Yahoo/Microsoft: https://help.brevo.com/hc/en-us/articles/14925263522578-Comply-with-Gmail-Yahoo-and-Microsoft-s-requirements-for-email-senders
- Supabase pricing page for custom domain cost: https://supabase.com/pricing

Verified Brevo candidate limits:
- Free plan includes transactional emails and SMTP/API access.
- Free plan allows 300 email sends per day.
- Free plan requires no credit card and has no time limit.
- When the transactional daily limit is exceeded, up to 1,000 additional transactional emails are held in a retry queue; emails beyond that queue are not delivered.
- Sender/domain deliverability requires a professional sender domain and DNS authentication with DKIM and DMARC; SPF/return-path alignment must be reviewed before production.
- A custom sender domain is not free because Dababa must own or buy the domain, and Supabase custom domains are a paid platform feature. Production email/domain choice is deferred.

Do not add Brevo or any SMTP service until the project owner explicitly approves the service, sender domain, DNS setup, and limits for that environment.

