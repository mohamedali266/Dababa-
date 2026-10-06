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

Binding domain decisions live in [docs/standards/domain-decisions.md](docs/standards/domain-decisions.md).

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

Binding visual identity, design tokens, layout, digital-card, and copy rules live in [docs/standards/design.md](docs/standards/design.md).

## 6a. Motion

Binding motion rules live in [docs/standards/motion.md](docs/standards/motion.md).

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
