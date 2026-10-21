# Caregiver app colors

Source of truth: `lib/core/theme/app_theme.dart`. The brand palette matches
`customer-app` and `../landing-page/src/app/globals.css`.

| Role | Token | Color |
| --- | --- | --- |
| Primary actions, active navigation, links | `primary` | `#006B5B` |
| Lighter teal | `primaryLight` | `#00806D` |
| Decorative mint accent | `accent` | `#00C896` |
| Page background | `background` | `#F5F3EE` |
| Mint containers / badge background | `primaryContainer` | `#E6F4F1` |
| Cards and form surfaces | `surface` | `#FFFFFF` |
| Main text and dark surfaces | `textPrimary`, `darkSurface` | `#0D1117` |
| Supporting text and placeholders | `textSecondary`, `textHint` | `#536471` |
| Accent orange / star ratings | `secondary` | `#FF6B35` |
| Borders and dividers | `border`, `divider` | `#E2DDD5` |

Use `AppColors` rather than repeating brand hex values in screens. Authentication,
navigation, shift cards, status badges, earnings, and settings share these tokens.

Companion colors support readable controls: `primaryDark` is `#004F43`;
orange foregrounds use `secondaryStrong` (`#A43F16`) on `secondaryContainer` (`#FFF0E8`).
Text on solid orange uses `onSecondary` (`#0D1117`).

Shift status tokens map seamlessly:
- Confirmed / Completed / In Progress use teal and mint (`success`, `primary`, `primaryContainer`).
- Pending / Waiting states use warm warning colors (`warning`, `warningLight`).
- Cancelled states use secondary text color on light neutral backgrounds.
- Crisis / SOS states retain standard error red (`error`, `errorLight`).
