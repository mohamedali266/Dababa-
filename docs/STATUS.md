# Dababa Status

## Done

- Phase 0 baseline and Phase 1A schema design are approved.
- Phase 1A review gaps are documented in the split schema files under `docs/schema/`.
- Slice 1B-1 foundation is approved: Supabase foundation migration, pgTAP foundation tests, CI workflow, README test notes, and free-only CI documentation.
- Database tests have run green in GitHub Actions on branch `phase-1b-1-db-ci`.

## Next

- Stop here until the project owner starts the next fresh session.
- In the next session, read only `docs/STATUS.md`, `AGENTS.md`, and `docs/schema/identity.md`.
- Do not start slice (a) or Phase 1B-2 until explicitly approved.

## Key Decisions

- Docker is unavailable locally; GitHub Actions is the reference environment for database tests.
- Hosted Supabase event triggers are not relied on. Migrations must use explicit revokes/default privileges; PostgreSQL function `EXECUTE` grants are cleaned by explicit migration revokes plus pgTAP catalog tests that fail if public functions grant `EXECUTE` to `anon`, `authenticated`, or `public`.
- The public-function execute allowlist is empty for now.
- Brevo SMTP is only a candidate for development and pilot emails; no service is added yet.
- Documentation is split by domain to control context cost.

## How To Run Tests

- Local app checks: `npm run lint`, `npm run typecheck`, and `npm test`.
- Local DB checks for machines with Docker: `npm run test:db`.
- CI DB reference: push to GitHub and inspect `.github/workflows/db-tests.yml`; it runs `supabase start`, `supabase db reset`, and `supabase test db`, then uploads full logs.
