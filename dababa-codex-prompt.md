# Dababa (دبابة) — Codex Build Prompt Pack

## How to use this file

- **Part A** goes into the repo root as `AGENTS.md`. Codex reads it automatically in every session. It holds the permanent rules.
- **Part B** has one prompt per phase. Paste them into Codex **one at a time**. Never paste the next phase before you have reviewed and approved the current one.
- Every phase ends with a mandatory STOP and a report. You reply with `Approved: Phase N` (or a list of fixes) before the next phase starts.

---

# PART A — AGENTS.md

## 1. Mission

Build **Dababa (دبابة)**: a multi-club gym management system and member app, shipped as an installable **PWA**. It is a non-commercial project. The goal is to connect the member directly to the club every day, not just to track a subscription.

What the system must do:

- Club owner and staff manage the club, members, subscriptions, payments, training plans and nutrition plans.
- Members see the plans their club created for them, show an **electronic membership card** (replaces printed cards), track their own progress (workout weights, reps, body measurements), and see their subscription and payment history.
- A **Super Admin** panel creates clubs and manages users and platform-level settings.
- One member account can belong to **several clubs** and switch between them (workspace-switcher style). Each club has its own plans, schedule data and branding.
- Scope for now: **gyms only**. Design the core generically (club, membership, subscription, card, attendance) so other sports can be added later as optional per-club modules. Do **not** build other sports now.

Stack is fixed. Do not substitute anything without asking.

## 2. Working protocol (non-negotiable)

1. Work **only on the current phase**. Do not start, scaffold or "prepare" the next phase.
2. Before coding a phase: read this file, then restate the phase scope, list assumptions, and list any question that blocks you. If something is ambiguous, **ask**. Do not invent product decisions.
3. Make small, reviewable commits with clear messages. One concern per commit.
4. At the end of every phase you MUST stop and produce a **Phase Report** with:
   - What was built (short, by feature).
   - How to run it and how to run all tests.
   - Test results (real output, not claims) and what is NOT covered.
   - Security checklist status (see section 6), item by item.
   - Decisions you made and why. Deviations from this file, if any.
   - Known issues, risks, and technical debt.
   - Questions for me.
5. After the report, **stop and wait**. Continue only after I write `Approved: Phase N`.
6. Never say a feature works unless you ran it or a test proves it. If you could not run something, say so.
7. Check current official documentation for the installed version of every framework before using its API (Next.js, Supabase, next-intl, Serwist, Motion). Do not rely on memory for APIs that change between versions.
8. Never add a dependency without stating: purpose, license (must be permissive and free: MIT, Apache-2.0, BSD, ISC), maintenance status, bundle impact. No paid services without asking me first.

## 3. Tech stack (fixed)

| Area | Choice |
|---|---|
| Framework | Next.js (App Router) + TypeScript in strict mode |
| Hosting | Vercel |
| Database/Auth/Storage/Realtime | Supabase (Postgres, Auth, Storage) with `@supabase/ssr` |
| Styling | Tailwind CSS + shadcn/ui primitives (Radix) restyled to the Dababa design system |
| i18n | `next-intl`, locales `ar` (default) and `en`, URL prefix `/ar` `/en` |
| Theme | `next-themes`, light and dark, driven by CSS variables |
| PWA | Serwist (service worker, manifest, offline shell) |
| Motion | `motion` package (the Framer Motion successor, MIT, free). Use `motion/react`. |
| Validation | Zod, shared between client and server |
| Forms | react-hook-form + Zod resolver |
| Data fetching | Server Components and Server Actions first. TanStack Query only where client caching is truly needed. |
| Charts | Recharts (or a lighter free alternative if you justify it) |
| Icons | Lucide (outline). No emoji as icons. |
| Unit/integration tests | Vitest |
| E2E | Playwright (Arabic RTL and English LTR, light and dark, mobile and desktop) |
| DB tests | Supabase CLI + pgTAP (`supabase test db`) |
| Lint/format | ESLint + Prettier, TypeScript `strict`, `noUncheckedIndexedAccess` |

All database changes go through **Supabase migrations** in the repo. Never edit the schema by hand in the dashboard.

## 3a. Environment

- Secrets only in environment variables. Provide `.env.example` with every variable and a one-line description. Never commit real values.
- The Supabase **service role key** is used only in server code that truly needs it, never imported in any client bundle, never prefixed `NEXT_PUBLIC_`. Add a lint rule or test that fails the build if it leaks into client code.
- Seed and demo data must be fictional. Never use real people's data.

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

## 5. Quality and logic rules

- Business logic lives in **server-side modules and database functions**, not inside React components. Components only render and call actions.
- Validate every input with Zod on the server, even if the client already validated it.
- Every Server Action and route handler: authenticate, authorize (permission check), validate, then act. In that order. No exceptions.
- Handle every state: loading, empty, error, offline, forbidden, not found. Empty states are designed, not left blank.
- Dates are stored in UTC and displayed in `Africa/Cairo`. Subscription end dates are computed in one tested function. Test month boundaries, leap years and timezone edges.
- Use database constraints for invariants (checks, unique, foreign keys, exclusion constraints for overlapping subscriptions if applicable). Do not rely on UI code to protect data integrity.
- No `any`. No unexplained `// @ts-ignore`. No dead code, no commented-out code, no TODO without an issue note in the report.
- Soft-delete only where the history matters (members, payments). Hard delete for personal data on account deletion requests, with a documented export-then-delete flow.
- Keep files small and cohesive. Name things by domain language.

## 6. Security checklist (verify and report in every phase that touches it)

- RLS enabled on **every** table in `public`. No table without a policy. Default deny.
- RLS tests prove: a user of club A cannot read, insert, update or delete anything of club B; a member cannot read another member's data; staff without a permission cannot perform that action; a user cannot escalate their own role.
- `SECURITY DEFINER` functions: set `search_path` explicitly, validate caller inside the function, grant `EXECUTE` only to the roles that need it, revoke from `public`.
- Storage buckets are **private**. Payment proofs and member photos are served through short-lived signed URLs with path-based policies (`club_id/member_id/...`). Validate type and size on upload, rename files server-side, never trust the client file name.
- Protect against: SQL injection (parameterized queries only), XSS (no `dangerouslySetInnerHTML` without sanitization), CSRF (Server Actions/same-site cookies), open redirects, IDOR (check ownership on every id), mass assignment (explicit field allow-lists), SSRF, and path traversal.
- Security headers: strict CSP (nonce-based), `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, HSTS, frame protection. Service worker must not cache authenticated API responses or other users' data.
- Rate limiting on auth, token issuing, scanning, uploads and any write endpoint. Use a free option that works on Vercel (ask me before adding a service). Failed-auth responses must not reveal whether an account exists.
- Audit log table for sensitive actions (role changes, payment approval, club creation, data export/delete). Append-only.
- No sensitive data in logs, URLs, or client-side storage. Health-related data (weights, measurements, nutrition) is treated as sensitive.
- Account deletion and data export exist and are tested.
- Run `npm audit` and a secret scan in CI and report the output.

## 7. Visual identity and design system

**Character:** strong, not aggressive; friendly and Egyptian in tone; fast and clear for one-handed use in a gym.

**Do NOT produce generic AI-looking UI.** Forbidden: purple/blue gradients, glassmorphism and blurred blobs, default shadcn look left unstyled, Inter / Roboto / system-default fonts, cards nested inside cards, a rounded icon tile above every heading, centered hero-with-three-feature-cards layouts, emoji icons, stock gym photography, gray text on colored backgrounds, pure black or pure gray (always tint), bounce/elastic easing, decorative glow. Every screen must look designed for this product.

**Look to build:** dark charcoal with a single lime accent, large rounded surfaces, big confident numerals, pill buttons, generous spacing, asymmetric layouts, and a weight-plate motif (a circle with an inner ring) used sparingly. The lime is the signature: **one primary lime action per screen**.

**Design tokens** (put them in one place as CSS variables; dark is a first-class theme, not an afterthought; verify WCAG AA contrast in both themes and report any adjustment):

| Token | Dark | Light |
|---|---|---|
| `--bg` | `#1d211f` | `#f4f5ee` |
| `--surface` | `#2a2f2b` | `#ffffff` |
| `--surface-2` | `#343a35` | `#eef0e6` |
| `--text` | `#f1f4ea` | `#1a1d14` |
| `--text-muted` | `#a3aa9a` | `#626858` |
| `--accent` (fills only) | `#c6f432` | `#c6f432` |
| `--on-accent` | `#1b2007` | `#1b2007` |
| `--accent-text` (accent used as text) | `#c6f432` | a darker lime of your choice that passes AA on `--bg` |
| `--danger`, `--warning`, `--success` | derive tinted values that pass AA | same |

Lime is never used as small text on light backgrounds. Club color is shown only as the club logo tile and small indicators; the Dababa identity stays dominant.

**Typography:** Cairo (Arabic and Latin) from Google Fonts via `next/font` (self-hosted at build), weights 400, 500, 800 only. Use **tabular numerals** for weights, reps, money and dates. Use Latin digits (0-9) in both languages. Define a type scale and stick to it.

**Logo and wordmark:** weight-plate mark + "دبابة" (Arabic) with "Dababa" beneath, and the reverse in English. Provide SVG logo, a maskable PWA icon (192, 512), favicon and apple-touch-icon.

**Digital card:** implement exactly like the approved mockup: Dababa brand on one side and the club logo tile and name on the other (club color on the tile only), member avatar, name and member number, a plan panel (plan name, active status chip, progress bar, end date, days left), a white QR panel (always dark-on-white for scanner reliability), and a 30-second countdown bar. It is the **first screen** the member sees on opening the installed app.

**Layout rules**

- Member app: mobile-first, bottom navigation (Card, Plan, Progress, Payments, More), safe-area aware, thumb-reachable controls, targets of at least 44px.
- Club and Super Admin dashboards: desktop-first with a collapsible sidebar, dense tables with search, filter, sort and pagination, and a usable mobile fallback (stacked rows or horizontal scroll with sticky first column).
- Every screen must be checked at 360px, 390px, 768px, 1024px and 1440px, in RTL and LTR, in light and dark, with long Arabic names and large text sizes. No horizontal page overflow, no clipped text, no overlapping.
- Use **logical CSS properties** everywhere (`ms-`, `me-`, `ps-`, `pe-`, `start`, `end`, `inset-inline-*`). Never `left`/`right` for layout. Icons that imply direction (arrows, chevrons) flip in RTL.

**Tone of copy**

- Egyptian colloquial Arabic for motivation, empty states and friendly messages ("لسه مفيش تمرين النهاردة؟ يلا يا بطل").
- Clear, simple Modern Standard Arabic for payments, subscriptions, privacy, errors and legal text. No jokes about money.
- English copy carries the same personality; it is not a literal translation.
- Sentence case, verb-first buttons, no "please", no "successfully", no exclamation marks in system messages.
- All strings live in message files with stable keys. No hard-coded user-facing text in components.

## 6a. Motion

Use the `motion` package (`motion/react`) plus CSS where enough. Wrap the app in `MotionConfig reducedMotion="user"` and honor `prefers-reduced-motion` everywhere (replace movement with a simple fade or nothing).

Use motion with purpose:

- Route/page transitions and shared-element feel between list and detail.
- Staggered entrance for lists and dashboard stats.
- Card: subtle entrance, QR refresh transition, countdown bar.
- Numbers: count-up for stats and personal records.
- Progress ring/bar fill, set-complete check, bottom sheet and dialog enter/exit.
- Button press feedback.

Rules: animate `transform` and `opacity` only; 150 to 400 ms; ease-out curves; no bounce or elastic; no layout shift (CLS); directional animations must respect RTL (slide in from the correct side); lazy-load heavy animation code; never block interaction while animating; keep 60fps on a mid-range phone. Put durations and easings in shared tokens.

## 8. Testing rules

- Every phase ships with tests. A phase is not done if tests are missing or failing.
- **pgTAP tests for every RLS policy** and every security-definer function (positive and negative cases).
- Vitest for business logic (subscription date math, permission checks, token signing/verification, CSV parsing).
- Playwright for critical flows, run in `ar`+RTL and `en`+LTR, light and dark, mobile and desktop viewports.
- Accessibility: automated checks (axe) in Playwright plus keyboard navigation and visible focus on every interactive element.
- CI (GitHub Actions) runs lint, type-check, unit tests, DB tests, E2E, `npm audit`, and a secret scan.

## 9. Things you must never do

- Never disable RLS "temporarily". Never use the service role in client code. Never trust client-supplied `club_id`, `user_id`, role, price or status.
- Never build something from a later phase, even partially.
- Never silently change an agreed decision in this file. Raise it in the report instead.
- Never hide failing tests or lower a threshold to make them pass.

---

# PART B — PHASE PROMPTS

Paste one at a time. Each starts with the same opening line.

## Phase 0 — Foundations

```
Read AGENTS.md fully. We are starting Phase 0 only. Follow the working protocol.

Goal: a clean, secure, empty-but-beautiful foundation. No business features.

Build:
1. Next.js App Router + TypeScript strict project, ESLint, Prettier, Vitest, Playwright, GitHub Actions CI, .env.example, README with setup steps.
2. Supabase project wiring with @supabase/ssr (server, browser and middleware/proxy clients per current docs), local Supabase CLI setup, empty migrations folder, pgTAP test runner working with one trivial test.
3. i18n with next-intl: ar (default, RTL) and en (LTR), URL prefixes, a language switcher, message files with stable keys, locale-aware date/number helpers (Latin digits, Africa/Cairo).
4. Theming with next-themes: light and dark from the design tokens in AGENTS.md, no flash on load, theme switcher.
5. Design system foundation: tokens as CSS variables, Cairo font via next/font, type scale, spacing/radius scale, and restyled primitives: Button (pill), Input, Select, Checkbox, Switch, Dialog, Bottom sheet, Tabs, Toast, Badge/Chip, Skeleton, EmptyState. Logical properties only.
6. Motion foundation: MotionConfig with reducedMotion, shared duration/easing tokens, a PageTransition wrapper, a Stagger list helper, a CountUp component. All RTL-aware.
7. Brand assets: SVG logo (plate mark + wordmark, ar and en), favicon, maskable PWA icons, manifest.
8. PWA shell with Serwist: installable, offline fallback page, update prompt. The service worker must not cache authenticated responses.
9. Security baseline: security headers and nonce-based CSP, a rate-limit utility interface (with a documented free implementation), env validation with Zod that fails fast, and a lint/test guard that fails if the service role key reaches client code.
10. A "design system" preview route (dev only) that shows every primitive in ar/en, light/dark, so I can review the visual identity.

Acceptance: app builds, installs as a PWA, all primitives render correctly at 360/768/1440 in RTL+LTR and light+dark, Lighthouse PWA/accessibility run reported, CI green.

Then STOP and give the Phase Report.
```

## Phase 1A — Data model proposal (no code yet)

```
Phase 0 is approved. Start Phase 1A only: a written proposal, no migrations yet.

Produce docs/schema.md containing:
- Every table with columns, types, constraints, indexes, and which tables are tenant-scoped (club_id).
- An entity relationship diagram (Mermaid).
- The full RLS policy plan per table and per role, in plain language.
- The permission model: roles, permissions, default permission sets for owner and staff types (trainer, reception, accountant).
- The member-owned data rules (workout logs and body measurements belong to the profile, carry club_id, readable by a club only during active membership, only for that club's records).
- The subscription state machine and the single function that computes dates (include edge cases).
- The payment approval function design (idempotent, transactional).
- QR token design and attendance dedupe logic.
- Storage buckets and path conventions with policies.
- Audit log design.
- Account deletion and export design.
- A threat model: the top 15 ways this system could leak data or be abused, and which mechanism stops each one.

Tables expected at minimum: profiles, clubs, club_settings, roles, permissions, role_permissions, club_members, membership_plans (packages), subscriptions, payments, attendance, exercises, training_plans, training_days, plan_exercises, plan_assignments, nutrition_plans, meals, workout_logs, workout_log_sets, body_measurements, notifications, audit_log. Change or add as you see fit and explain why.

STOP and wait for my approval of the design.
```

## Phase 1B — Database, auth and isolation

```
Phase 1A is approved. Start Phase 1B only.

Implement exactly the approved schema as Supabase migrations, with RLS, security-definer helpers, triggers (profile creation on sign-up, updated_at), seed data (fictional: 2 clubs, owners, staff, members), and the permission-check function.
Implement authentication: email + password and magic link (and a password reset), sign-up for members, session handling, protected routes by role, and the active-club selection with server-side re-validation.
Screens: sign in, sign up, reset password, club picker (shown when the user has several memberships), and empty role-based home placeholders. Designed in the Dababa identity, ar/en, light/dark.

Tests (required): pgTAP covering EVERY policy with positive and negative cases, cross-club isolation, privilege-escalation attempts, member-owned data visibility rules (including after membership ends), and the security-definer functions. Vitest for permission helpers. Playwright for auth flows.

Acceptance: a written isolation test matrix in the report showing each table x role x operation and the result.

STOP and give the Phase Report.
```

## Phase 2 — Super Admin, clubs, staff and roles

```
Phase 1B is approved. Start Phase 2 only.

Build:
- Super Admin panel (desktop-first): create/edit/suspend a club, assign the first owner by invitation, list and search users and clubs, view platform stats. Every action is audited. Super admin viewing tenant data must itself be audited.
- Club settings: names (ar/en), logo upload, accent color, member photo requirement, module flags.
- Staff management for owners: invite staff by email, assign a staff type and fine-grained permissions, deactivate staff. Invitations are single-use, expiring and tied to the club.
- Permission-aware UI: hide what a user cannot do, but the server and RLS are the real enforcement (prove it in tests by calling the actions directly as a user who lacks the permission).
- Club dashboard shell with sidebar navigation and a designed empty state for each section.

Tests: pgTAP, Vitest, Playwright (including attempts to perform forbidden actions via direct calls).
STOP and give the Phase Report.
```

## Phase 3 — Members, packages, subscriptions, payments

```
Phase 2 is approved. Start Phase 3 only.

Build for club owner/staff:
- Members list (search, filters, pagination), add member (creates or links a profile), member detail, status changes, photo upload.
- Membership packages (monthly, 3 months, yearly, custom) with prices in minor units.
- Subscriptions: create, renew, freeze, cancel, with the single tested date function. Overlap prevention in the database.
- Payments: record cash payments; review queue for transfer proofs (approve/reject with reason); receipts view; refunds; daily cash summary.
- CSV import for existing members (validate, preview, report errors per row, dry-run before commit, handles Arabic names and phone formats, idempotent on re-import).
- Expiring-soon list and overdue list.

Build for members: my subscription, payment history, and the "pay by transfer" flow (choose package, see the club's transfer instructions, upload proof and reference, track status).

Security focus: proof uploads (type/size validation, private bucket, signed URLs), idempotent approval, IDOR tests on every id.
Tests: pgTAP, Vitest (date math edge cases, CSV parser), Playwright.
STOP and give the Phase Report.
```

## Phase 4 — Digital card, QR, attendance, club switcher

```
Phase 3 is approved. Start Phase 4 only.

Build:
- Member home = the digital card, pixel-faithful to the approved mockup (brand + club tile, avatar, name, member number, plan panel, QR panel, countdown bar), ar/en, light/dark, all screen sizes. Polished motion per AGENTS.md.
- QR token issuing endpoint and client refresh every 30 seconds, with the security design from AGENTS.md. Handle backgrounded tabs, clock drift and failed refresh gracefully.
- Offline behaviour as specified (card opens offline, no QR without connection, member number shown).
- Staff scanner screen in the PWA using the device camera (free, open-source library; justify the choice), plus manual lookup by member number or phone. Result screen with clear states: valid, expired subscription, frozen, wrong club, invalid/expired code. Large, readable, usable one-handed.
- Attendance recording with dedupe window and an attendance list for the club.
- Club switcher for members with several clubs, with a smooth transition and each card showing its club's branding.

Tests: token sign/verify/expiry/replay/wrong-club tests, rate-limit tests, pgTAP for attendance, Playwright for scan flows (mock the camera).
STOP and give the Phase Report.
```

## Phase 5 — Training and progress

```
Phase 4 is approved. Start Phase 5 only.

Build:
- Exercise library per club (name ar/en, muscle group, equipment, optional image/video link), with a starter set of common gym exercises (fictional descriptions are fine, no copyrighted media).
- Training plans: plan > days > exercises with sets, reps, rest, notes; reusable templates; assign a plan to a member with start/end dates; assignment history.
- Member plan view: today's workout first, clear day structure.
- Workout logging (the most important UX in the app): start a session from the assigned day, big tap targets, previous values prefilled, quick +/- steppers for weight and reps, rest timer, set-complete animation, works with a flaky connection (queue writes locally and sync safely and idempotently), no data loss if the app is closed mid-workout.
- Progress: body measurements (weight, body fat, circumferences), exercise history and personal records, charts with range filters, count-up and chart-draw animations.
- Trainer view: see assigned members' logs and progress for the active club only, per the member-owned data rules.
- Member can add their own entries; the club can add entries on the member's behalf (clearly marked as such).

Tests: pgTAP for visibility rules (including after membership ends), Vitest for PR calculation and offline queue/sync logic, Playwright for logging flow on a mobile viewport in RTL.
STOP and give the Phase Report.
```

## Phase 6 — Nutrition and notifications

```
Phase 5 is approved. Start Phase 6 only.

Build:
- Nutrition plans: plan > meals > items with quantities and optional macros; templates; assign to a member; member view. Treat as sensitive data.
- Notifications: in-app notification center; Web Push for subscription expiry reminders (configurable days before), plan assignment, and payment status. Opt-in flow with a clear explanation. iOS requires the PWA to be installed to receive push: build a clear, friendly install-guidance screen for iOS and Android.
- Notification preferences per user. Locale-aware message text.
- A scheduled job (Supabase scheduled function or Vercel cron, free tier) for expiry reminders; idempotent so it never double-sends.

Tests: reminder scheduling logic, idempotency, push subscription handling, RLS.
STOP and give the Phase Report.
```

## Phase 7 — Hardening, accessibility, performance, release

```
Phase 6 is approved. Start Phase 7 only. No new features.

Do:
- Full security review against the AGENTS.md checklist. Re-run the entire RLS isolation matrix. Add missing negative tests. Review CSP, headers, rate limits, storage policies, service worker caching, logs. Account deletion and data export end-to-end.
- Accessibility pass to WCAG 2.2 AA: keyboard, focus, screen-reader labels in Arabic and English, contrast in both themes, reduced motion.
- Responsive pass on every screen at 360/390/768/1024/1440 in RTL+LTR, light+dark, with long names and large text. Produce screenshots in the report.
- Performance: Lighthouse on key screens, bundle analysis, image optimization, lazy loading, no layout shift, animation smoothness on a throttled CPU.
- Polish pass on motion and empty/error states. (Optional: run the Impeccable skill's audit and critique on the UI and report which findings you applied.)
- Documentation: README, architecture overview, runbook (deploy to Vercel + Supabase, env vars, migrations, backups, key rotation for the QR signing secret), and a user guide outline for owners, staff and members.
- Release checklist and a list of known limitations.

STOP and give the final report.
```
