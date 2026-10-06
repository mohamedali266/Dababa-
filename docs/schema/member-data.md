# Member Data Schema

### `exercises`

Club exercise library.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `name_ar` | `text` | not null |
| `name_en` | `text` | not null |
| `muscle_group` | `text` | not null |
| `equipment` | `text` | nullable |
| `description_ar` | `text` | nullable |
| `description_en` | `text` | nullable |
| `media_url` | `text` | nullable |
| `is_active` | `boolean` | not null default true |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |

Tenant scoped: yes.

### `training_plans`

Club-owned plan templates or concrete plans.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `name_ar` | `text` | not null |
| `name_en` | `text` | not null |
| `description` | `text` | nullable |
| `is_template` | `boolean` | not null default false |
| `created_by` | `uuid` | references `profiles(id)` |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |

Tenant scoped: yes.

### `training_days`

Days inside a training plan.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `training_plan_id` | `uuid` | not null references `training_plans(id)` on delete cascade |
| `day_number` | `integer` | not null check `> 0` |
| `title_ar` | `text` | not null |
| `title_en` | `text` | not null |
| `sort_order` | `integer` | not null default 0 |

Constraints:
- unique `(training_plan_id, day_number)`.

Tenant scoped: yes.

### `plan_exercises`

Exercise prescription inside a day.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `training_day_id` | `uuid` | not null references `training_days(id)` on delete cascade |
| `exercise_id` | `uuid` | not null references `exercises(id)` |
| `sets` | `integer` | not null check `> 0` |
| `reps_min` | `integer` | nullable check `> 0` |
| `reps_max` | `integer` | nullable check `> 0` |
| `target_weight_minor` | `integer` | nullable check `>= 0` |
| `rest_seconds` | `integer` | nullable check `>= 0` |
| `notes_ar` | `text` | nullable |
| `notes_en` | `text` | nullable |
| `sort_order` | `integer` | not null default 0 |

Tenant scoped: yes.

### `plan_assignments`

Assigns a club training plan to a member.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `club_member_id` | `uuid` | not null references `club_members(id)` |
| `training_plan_id` | `uuid` | not null references `training_plans(id)` |
| `status` | `plan_assignment_status` | not null default `active` |
| `starts_on` | `date` | not null |
| `ends_on` | `date` | nullable |
| `assigned_by` | `uuid` | not null references `profiles(id)` |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |

Indexes:
- `(club_member_id, status, starts_on desc)`.

Tenant scoped: yes.

### `nutrition_plans`

Club-owned nutrition plan.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `name_ar` | `text` | not null |
| `name_en` | `text` | not null |
| `description` | `text` | nullable |
| `is_template` | `boolean` | not null default false |
| `created_by` | `uuid` | references `profiles(id)` |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |

Tenant scoped: yes.

### `nutrition_assignments`

This table is added beyond the minimum list so nutrition plan assignment history mirrors training assignments.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `club_member_id` | `uuid` | not null references `club_members(id)` |
| `nutrition_plan_id` | `uuid` | not null references `nutrition_plans(id)` |
| `status` | `plan_assignment_status` | not null default `active` |
| `starts_on` | `date` | not null |
| `ends_on` | `date` | nullable |
| `assigned_by` | `uuid` | not null references `profiles(id)` |
| `created_at` | `timestamptz` | not null default `now()` |

Tenant scoped: yes.

### `meals`

Meals inside nutrition plans.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `nutrition_plan_id` | `uuid` | not null references `nutrition_plans(id)` on delete cascade |
| `title_ar` | `text` | not null |
| `title_en` | `text` | not null |
| `sort_order` | `integer` | not null default 0 |

Tenant scoped: yes.

### `meal_items`

This table is added because meals need item-level quantities and macros.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `meal_id` | `uuid` | not null references `meals(id)` on delete cascade |
| `name_ar` | `text` | not null |
| `name_en` | `text` | nullable |
| `quantity` | `text` | not null |
| `calories` | `integer` | nullable check `>= 0` |
| `protein_g` | `numeric(6,2)` | nullable check `>= 0` |
| `carbs_g` | `numeric(6,2)` | nullable check `>= 0` |
| `fat_g` | `numeric(6,2)` | nullable check `>= 0` |
| `sort_order` | `integer` | not null default 0 |

Tenant scoped: yes.

### `workout_logs`

Member-owned workout session log.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `profile_id` | `uuid` | not null references `profiles(id)` on delete cascade |
| `club_member_id` | `uuid` | not null references `club_members(id)` |
| `plan_assignment_id` | `uuid` | nullable references `plan_assignments(id)` |
| `training_day_id` | `uuid` | nullable references `training_days(id)` |
| `performed_on` | `date` | not null |
| `started_at` | `timestamptz` | nullable |
| `finished_at` | `timestamptz` | nullable |
| `recorded_by` | `uuid` | not null references `profiles(id)` |
| `source` | `record_source` | not null |
| `client_mutation_id` | `uuid` | nullable |
| `created_at` | `timestamptz` | not null default `now()` |
| `updated_at` | `timestamptz` | not null default `now()` |

Constraints:
- unique `(profile_id, client_mutation_id)` where `client_mutation_id is not null` for offline sync idempotency.
- `profile_id` must match `club_members.profile_id`.

Tenant scoped: yes, but ownership is member profile.

### `workout_log_sets`

Set-level workout data.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `workout_log_id` | `uuid` | not null references `workout_logs(id)` on delete cascade |
| `exercise_id` | `uuid` | not null references `exercises(id)` |
| `set_number` | `integer` | not null check `> 0` |
| `weight_minor` | `integer` | nullable check `>= 0` |
| `reps` | `integer` | nullable check `>= 0` |
| `completed` | `boolean` | not null default false |
| `notes` | `text` | nullable |
| `client_mutation_id` | `uuid` | nullable |
| `created_at` | `timestamptz` | not null default `now()` |

Constraints:
- unique `(workout_log_id, exercise_id, set_number)`.
- unique `(workout_log_id, client_mutation_id)` where `client_mutation_id is not null`.

Tenant scoped: yes, inherited member-owned data.

### `body_measurements`

Member-owned body metrics.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | not null references `clubs(id)` |
| `profile_id` | `uuid` | not null references `profiles(id)` on delete cascade |
| `club_member_id` | `uuid` | not null references `club_members(id)` |
| `measured_on` | `date` | not null |
| `weight_kg` | `numeric(5,2)` | nullable check `> 0` |
| `body_fat_percent` | `numeric(5,2)` | nullable check `>= 0 and <= 100` |
| `chest_cm` | `numeric(5,2)` | nullable |
| `waist_cm` | `numeric(5,2)` | nullable |
| `hip_cm` | `numeric(5,2)` | nullable |
| `arm_cm` | `numeric(5,2)` | nullable |
| `thigh_cm` | `numeric(5,2)` | nullable |
| `recorded_by` | `uuid` | not null references `profiles(id)` |
| `source` | `record_source` | not null |
| `client_mutation_id` | `uuid` | nullable |
| `created_at` | `timestamptz` | not null default `now()` |

Constraints:
- unique `(profile_id, client_mutation_id)` where `client_mutation_id is not null`.
- `profile_id` must match `club_members.profile_id`.

Tenant scoped: yes, but ownership is member profile.

### `notifications`

In-app and web-push notifications.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `club_id` | `uuid` | nullable references `clubs(id)` |
| `profile_id` | `uuid` | not null references `profiles(id)` on delete cascade |
| `channel` | `notification_channel` | not null |
| `status` | `notification_status` | not null default `queued` |
| `title_key` | `text` | not null |
| `body_key` | `text` | not null |
| `payload` | `jsonb` | not null default `{}` |
| `scheduled_for` | `timestamptz` | nullable |
| `sent_at` | `timestamptz` | nullable |
| `read_at` | `timestamptz` | nullable |
| `idempotency_key` | `text` | nullable |
| `created_at` | `timestamptz` | not null default `now()` |

Constraints:
- unique `(profile_id, channel, idempotency_key)` where `idempotency_key is not null`.

Tenant scoped: optional. Club-scoped when `club_id` is set.

### `push_subscriptions`

Needed for Web Push.

| Column | Type | Constraints |
|---|---|---|
| `id` | `uuid` | PK default `gen_random_uuid()` |
| `profile_id` | `uuid` | not null references `profiles(id)` on delete cascade |
| `endpoint_hash` | `text` | not null unique |
| `endpoint` | `text` | not null |
| `p256dh` | `text` | not null |
| `auth` | `text` | not null |
| `user_agent` | `text` | nullable |
| `created_at` | `timestamptz` | not null default `now()` |
| `revoked_at` | `timestamptz` | nullable |

Tenant scoped: no.


## Member-Owned Data Rules

Workout logs and body measurements:

- Always store `profile_id`, `club_id`, and `club_member_id`.
- Member can read all their own records, even after membership ends.
- "Active membership" means `club_members.status = 'active'`; it does not require a valid subscription.
- RLS tests must prove that an expired subscription with active membership still allows club access, while `left` or `suspended` membership closes club access.
- Club staff can read only records where:
  - staff has active membership in that `club_id`,
  - staff has `progress.read`,
  - target member has active membership in that same club at read time,
  - record `club_id` equals active club.
- When membership ends, staff visibility closes immediately; the member keeps the history.
- Staff-written records set `recorded_by` to the staff profile, `source = 'staff'`, and still keep `profile_id` as the member.
- Member-written records set `recorded_by = profile_id` and `source = 'member'`.
- Offline sync uses `client_mutation_id` idempotency.

