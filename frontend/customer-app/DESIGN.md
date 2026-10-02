# Customer app colors

Source of truth: `lib/core/theme/app_theme.dart`. The brand palette matches
`../landing-page/src/app/globals.css`.

| Role | Token | Color |
| --- | --- | --- |
| Primary actions, selection, links | `primary` | `#006B5B` |
| Lighter teal | `primaryLight` | `#00806D` |
| Decorative mint accent | `accent` | `#00C896` |
| Page background | `background` | `#F5F3EE` |
| Mint containers | `primaryContainer` | `#E6F4F1` |
| Cards and form surfaces | `surface` | `#FFFFFF` |
| Main text and dark surfaces | `textPrimary`, `darkSurface` | `#0D1117` |
| Supporting text and placeholders | `textSecondary`, `textHint` | `#536471` |
| Accent orange | `secondary` | `#FF6B35` |
| Borders and dividers | `border`, `divider` | `#E2DDD5` |

Use `AppColors` rather than repeating brand hex values in screens. Authentication,
navigation, booking, caregiver cards, and settings share these tokens.

App-specific companion colors support readable controls: `primaryDark` is
`#004F43`; orange foregrounds use `secondaryStrong` (`#A43F16`) on
`secondaryContainer` (`#FFF0E8`). Text on solid orange uses `onSecondary`
(`#0D1117`). Small supporting text uses the darker landing-page muted color,
rather than its lighter slate metadata color.

Success uses teal/mint; pending and warning states use dark orange/pale orange.
Error and information colors retain their semantic roles. Third-party identity
marks, including Google, retain their original colors.

The existing app typography, layout, and interaction patterns remain the basis
of the customer UI. Header gradients use dark teal through primary teal to
`primaryLight`; all three stops support white text.
