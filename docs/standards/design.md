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

