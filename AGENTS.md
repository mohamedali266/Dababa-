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

## 2a. Free-only services policy

- Every service, library, and tool must be free for development and the early pilot, with no credit card required.
- Open-source libraries must use a permissive license such as MIT, Apache-2.0, BSD, or ISC.
- Before using any external service, the phase report must state:
  - the free-tier limits, verified from the provider's official docs, with link and check date;
  - what happens when each relevant limit is exceeded;
  - whether the provider's terms allow Dababa's intended use, including later commercial use;
  - any known conflict between the free tier and production use, such as commercial hosting restrictions, database pausing, backup limits, email daily limits, account inactivity deletion, or branding.
- Never rely on memory for pricing, quotas, or limits. Re-check official docs during the phase where the service is proposed or used.
- Every external service must sit behind an adapter/interface configured by environment variables so the provider can be replaced without touching business logic. This applies at minimum to email/SMTP, rate limiting, push notifications, and any future replacement for storage.
- Do not add or configure an external service until the project owner explicitly approves that service and the documented limits.

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

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
