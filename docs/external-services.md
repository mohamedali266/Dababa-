# External Services Register

This register records proposed external services before implementation. No service is configured until explicitly approved by the project owner.

Check date: 2026-10-07.

## Policy

- Every service must be free for development and the early pilot, with no credit card required.
- Pricing, quotas, and limits must be verified from official documentation at the time the service is proposed or used.
- Every service must sit behind an adapter/interface configured by environment variables so providers can be replaced without touching business logic.
- Open-source libraries must be permissively licensed.

## Auth Email / SMTP

Status: candidate accepted for password-reset and verification emails only; not added or configured yet.

Provider candidate: Brevo SMTP.

Use scope:
- Supabase Auth password reset emails.
- Supabase Auth verification/confirmation emails.
- No marketing email, campaigns, newsletters, or product announcements.

Environment-driven adapter/configuration:
- `SMTP_PROVIDER`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `SMTP_FROM_EMAIL`
- `SMTP_FROM_NAME`
- `SMTP_REQUIRE_TLS`
- `AUTH_EMAIL_ADAPTER`

Verified official sources:
- Supabase custom SMTP docs, checked 2026-10-07: https://supabase.com/docs/guides/auth/auth-smtp
- Brevo pricing plan docs, checked 2026-10-07: https://help.brevo.com/hc/en-us/articles/208589409-About-Brevo-s-pricing-plans
- Brevo free-plan limits docs, checked 2026-10-07: https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan
- Brevo transactional email page, checked 2026-10-07: https://www.brevo.com/products/transactional-email/
- Brevo inactive free-account docs, checked 2026-10-07: https://help.brevo.com/hc/en-us/articles/4410311028626-About-the-deletion-of-inactive-Free-plan-accounts
- Brevo terms and anti-spam policy entry points, checked 2026-10-07: https://www.brevo.com/legal/termsofuse/ and https://www.brevo.com/legal/antispampolicy/

Verified free-tier limits:
- Brevo Free includes transactional emails and SMTP/API access.
- Brevo Free allows 300 email sends per day.
- Brevo Free has no time limit and requires no credit card.
- Brevo Free stores up to 100,000 contacts.
- Unused daily email sends do not roll over.
- If the transactional daily limit is exceeded, up to 1,000 additional transactional emails are held in a retry queue; emails beyond that queue are not delivered.
- Supabase Auth default SMTP is not production-grade: it is restricted to authorized team email addresses, currently limited to 2 messages per hour, has no delivery/uptime SLA, and is intended only for exploration, demos, and non-mission-critical use.
- Supabase custom SMTP initially has a low rate limit of 30 messages per hour to protect sender reputation.
- Brevo Free accounts unused for 4 months can be automatically deleted, but transactional email activity counts as account activity.

Terms/use assessment:
- Brevo's public pricing and transactional email pages present the service for transactional email and business/customer communication use, with a free tier available.
- No non-commercial-only restriction was found in the official Brevo pages checked on 2026-10-07.
- Use must comply with Brevo's Terms of Service and Anti-Spam Policy; before production, the project owner must approve sender domain, DNS authentication, sender identity, and compliance posture.

Known free-tier / production conflicts:
- 300 emails/day can block password reset or verification delivery during spikes.
- Emails beyond the 1,000 transactional retry queue are not delivered.
- Free-plan branding may appear in emails unless a paid option/add-on removes it.
- Free account inactivity deletion is a risk if no transactional activity occurs for 4 months.
- Supabase's default SMTP is not suitable for production and cannot be relied on for general user emails.
- Custom SMTP requires sender-domain DNS setup and deliverability monitoring before production use.
