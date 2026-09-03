# Master Prompt 3 — Polish Pass (Final)
## Placement Connect

Run this after Master Prompt 1 (functional core) and Master Prompt 2 (premium token system) both exist and work. Pair it with `placement_connect_premium_final.html` as the literal visual and mechanical target — every value below is pulled from that file, not approximated.

---

## Role

Senior product designer doing a refinement pass on a product that already has its identity. Same bones as Master Prompt 2's output — every detail actually finished this time.

---

## What's frozen

- Hex values in `app_colors.dart` / `ColorScheme` in `app_theme.dart`. Exact, not "warmer."
- Fraunces / Inter / IBM Plex Mono. Different weights and sizes are fine — that's styling.
- The status thread's core behavior (track, fill, nodes, meaning).

A fourth color or font anywhere is a redesign, not a polish pass. Stop and ask.

---

## Spacing and grid

Strict 8pt rhythm, 4pt only for tight internal spacing (icon-to-label gaps, badge padding). Concrete scale used throughout the reference file: `4 · 8 · 12 · 16 · 20 · 24 · 32 · 40`. No `12.5px`, no `18px` "because it looked right."

---

## Shape — superellipse corner scale

Corner radius scales with surface size, implemented as `ContinuousRectangleBorder` in Flutter (or a superellipse `clip-path` in the reference HTML, not plain `border-radius`, since a true squircle reads differently at hero sizes):

| Surface | Radius |
|---|---|
| Small controls (chips, inputs, radios) | 12px, plain rounded rect |
| Standard cards (list items, stat tiles) | 22px, continuous corner |
| Hero surfaces (login card, bento primary tile, avatars, detail header) | 28–32px, continuous corner |
| FAB | 20px, continuous corner (square-ish, not a circle — matches the app's overall corner language) |

---

## Depth — elevation system

**Light mode**, three shadow weights by how "above" the surface something is:
- Resting card: `0 2px 4px rgba(20,23,28,.05), 0 4px 12px rgba(20,23,28,.05)`
- Floating (FAB, active drag): `0 10px 24px rgba(20,23,28,.10), 0 24px 48px rgba(20,23,28,.10)`
- Modal / sheet: `0 20px 50px rgba(20,23,28,.16)`

**True-black dark mode** — shadows barely register against `#000000`, so depth comes from surface tinting, three fixed steps:

| Step | Hex | Use |
|---|---|---|
| Base | `#000000` | App background |
| Elevation 1 | `#121316` | Resting cards, list rows, nav bar |
| Elevation 2 | `#1E2024` | Bottom sheets, popovers, the FAB, modals |

Each step is a flat hex, not a shadow — verify visually at low screen brightness, not just in a bright screenshot.

---

## Motion — concrete values

- Stagger delay between list/grid items: `60ms` per item, `rise` keyframe (`opacity 0→1`, `translateY(10px)→0`), duration `550ms`, `cubic-bezier(.2,.8,.2,1)`.
- Tab/panel transitions: `220ms`, same easing.
- Status-thread fill: `500ms`, same easing, on first render only.
- Hero transitions: shared-element (Hero) between a list card's logo/name and the detail header — the logo tile is the anchor.
- Skeleton loaders replace bare spinners everywhere a list or card is fetching — shimmer using `surface-alt` sweeping across `surface`, `1.4s` loop, disabled entirely under reduced-motion (show a static skeleton instead).
- Pull-to-refresh: custom indicator using the brass gradient (`--brass-a` → `--brass-b`), not the platform default spinner.
- Everything above collapses to instant/no-op under `prefers-reduced-motion` / the platform's reduce-motion setting — no exceptions.

---

## Density and hierarchy

Home screen leads with one bento primary tile (active applications count + inline status thread) at roughly 1.3fr against two smaller stat tiles (1fr each) in a 2-row span — this is the only screen that gets the asymmetric bento treatment, because it's the only one where one number is genuinely more important than the others. Lists (Applications, Notices) stay flat rows; don't force a grid where the content is really a list.

---

## Iconography

One source, one stroke weight (`stroke-width="2"` at a 24×24 viewBox, `1.6` inside small login-orb glyphs only), rounded joins. Normalize any earlier pass that mixed filled and outline icons.

---

## States

- **Empty**: icon + one-sentence invitation to act ("No drives open right now — check back after your coordinator publishes this cycle's calendar"), never a bare "No data."
- **Loading**: skeleton shapes matching the real layout's card/row geometry, not a centered spinner.
- **Error**: what happened + what to do, in the interface's voice, no apology, no "something went wrong."

Same visual budget as the happy path — same corner radius scale, same spacing.

---

## Touch ergonomics

Primary action (Apply, Add) lives in a FAB at bottom-right, thumb zone, `right:20px; bottom:` (nav bar height + 20px) — never a top-right button. Destructive/rare actions (sign out, decline offer) sit inside a settings list or a confirmation sheet, deliberately one tap further away.

---

## Android platform-native feel

- **Edge-to-edge**: content draws behind the system status and navigation bars. Status bar padding is `env(safe-area-inset-top)` (or `MediaQuery.of(context).padding.top` in Flutter) added to the existing `14px` top inset, not a fixed value. Bottom nav padding is `10px + env(safe-area-inset-bottom)`.
- **Status bar icon brightness**: light icons on the true-black theme, dark icons on the light theme, switched automatically with theme mode (`SystemUiOverlayStyle` in Flutter).
- **Predictive back**: system back gesture is allowed through (`PopScope` with `canPop` reflecting real navigation state, not swallowed with an empty callback) — a screen mid-transition should show the outgoing screen scaling back and the previous screen revealing underneath, matching Android 14+'s predictive-back preview, not a hard cut.
- **Bottom navigation — floating pill bar**: 4 destinations max (Home, Applications, Timeline, Profile). The bar itself floats above content, inset `16px` from each side and `14px + safe-area-inset-bottom` from the bottom, fully rounded (`border-radius:100px`), `var(--surface-1)` in light / `#0B0C0E` in true-black, `--shadow-3` beneath it, `1px` border in `var(--border)`. Inactive destinations are circular icon-only buttons (`44×44px`, `var(--surface-2)` fill). The active destination expands into a pill that fills the remaining width — icon plus label, brass gradient fill, `var(--on-brass)` icon/text — animating width on selection (`280ms`, same easing as everything else) rather than snapping. Scrollable content gets `96px` bottom padding and the FAB sits at `bottom:104px` so neither is obscured by the floating bar.

---

## Process

1. **Audit first** — screen by screen, name what's still generic (flat spacing, single shadow recipe, spinner-only loading, uniform icon set). Show this list before changing anything.
2. **Confirm the polish-token addendum above** — it extends `design.md`, doesn't replace it. Get sign-off before touching widget code.
3. **Re-pass screen by screen**, same order as Master Prompt 1: auth, student, faculty, TPO, admin. Before/after description, then code.
4. **Self-check**: if the screen would look the same with the brass accent swapped for anyone else's brand, it's not done.

---

## Final QA

- Diff color/font values against `app_colors.dart` / `app_typography.dart` — nothing moved.
- Every spacing value traces to `4/8/12/16/20/24/32/40`.
- True-black theme reads elevation correctly at low screen brightness, verified on-device, not just in a screenshot.
- Motion respects `prefers-reduced-motion` — verify by toggling it, not by inspection.
- Edge-to-edge and predictive back work correctly on a real Android device or emulator, not just visually in a static screenshot.
- No new feature, route, or repository touched — that's scope creep, not polish.
