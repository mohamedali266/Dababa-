# Dababa (دبابة)

Dababa is a multi-club gym management system and member PWA. Phase 0 is only the secure foundation: no business features, no real tenant data, and no production Supabase schema yet.

## Requirements

- Node.js 22+
- npm 10+
- Docker Desktop for local Supabase database tests

## Setup

```bash
npm install
copy .env.example .env.local
npm run dev
```

Open `http://127.0.0.1:3000/ar` for Arabic RTL or `http://127.0.0.1:3000/en` for English LTR.

## Environment

Do not commit `.env` or `.env.local`.

- `NEXT_PUBLIC_SUPABASE_URL`: public Supabase project URL.
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: public anon key; RLS still protects data.
- `SUPABASE_SERVICE_ROLE_KEY`: server-only key, never used in client code.
- `QR_SIGNING_SECRET`: future QR token signing secret.
- `ADMIN_LOGIN_EMAIL`, `ADMIN_LOGIN_USERNAME`, `ADMIN_LOGIN_PASSWORD`: optional fictional bootstrap admin credentials for local/demo setup.

## Commands

```bash
npm run lint
npm run typecheck
npm test
npm run build
npm run test:e2e
npm run test:db
npm run audit
npm run secret-scan
```

`npm run test:db` needs Docker and uses the local Supabase CLI package.

## Phase 0 Scope

- Next.js App Router, TypeScript strict, ESLint, Prettier, Vitest, Playwright and CI.
- next-intl routing with `/ar` and `/en`.
- Cairo font, Dababa design tokens, light/dark theme, and motion provider.
- Initial restyled primitives and dev design preview at `/ar/design-system` and `/en/design-system`.
- Supabase SSR client wiring and local Supabase config with a pgTAP smoke test.
- PWA manifest, icons, offline shell, and Serwist service worker setup.
- Security headers, CSP nonce plumbing, env validation, rate-limit interface, service role leak guard, and secret scan.

## Dependency Notes

All added runtime packages are free and permissively licensed in the npm ecosystem. Main choices:

- `next`, `react`, `react-dom`: app framework.
- `@supabase/ssr`, `@supabase/supabase-js`: Supabase cookie-based SSR auth wiring.
- `next-intl`: locale routing and messages.
- `next-themes`: class-based light/dark themes.
- `@serwist/next`, `serwist`: installable PWA and service worker.
- `motion`: purposeful UI motion through `motion/react`.
- `zod`, `react-hook-form`, `@hookform/resolvers`: validation/forms foundation for later phases.
- `@radix-ui/*`: accessible primitive behavior.
- `lucide-react`: outline icons.

Dev dependencies cover linting, formatting, unit tests, E2E, accessibility checks, Supabase CLI, CI guards, and maintenance scans.
