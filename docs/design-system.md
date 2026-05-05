# Color Anima App — Design System

This is the SwiftUI/macOS design language for the Color Anima public app shell.
It is inspired by Vercel/Geist's restraint-as-engineering philosophy, translated
to native macOS controls, NSColor dynamic appearances, and the
`WorkspaceFoundation` token surface.

The token surface is in
`Sources/ColorAnimaAppWorkspaceDesignSystem/WorkspaceFoundation.swift`. Use the
tokens directly. Do not introduce raw `Color.secondary.opacity(...)`,
`font.system(size:)`, integer `padding(...)`, or integer `cornerRadius(...)` in
view code outside the design-system module — `scripts/scan-design-token-violations.sh`
enforces this and the per-file baseline must trend to zero.

## 1. Visual Theme

The product is a craft tool, not a marketing site, so we keep all UI chrome
achromatic and let the user's artwork carry color. The system has three jobs:

- **Disappear into the canvas.** UI chrome is grayscale, materials are
  near-translucent, and elevation is a whisper.
- **Make hierarchy legible without weight.** Tracking, size, and spacing carry
  hierarchy; bold (700) is forbidden in body copy.
- **Use shadow as border.** Hairline rings do the job CSS borders would. They
  read cleaner at HiDPI and survive corner radii without clipping.

### Key characteristics

- Achromatic palette: `Surface`, `Foreground`, `Stroke`, `Shell` are all neutral
  by construction. The only chromatic accent is destructive red (system).
- Dynamic light/dark via `NSColor(name:)` with `bestMatch(from: [.darkAqua, .aqua])`.
- Materials over solid fills for elevated surfaces (`Surface.material =
  .ultraThinMaterial`).
- Shadow-as-border: `Ring.hairline` (0.08 black / 0.10 white) is the canonical
  ring, applied as `.overlay(RoundedRectangle(...).stroke(...))`.
- Multi-layer card depth: combine `Elevation.cardLift` + `Elevation.cardDepth`
  + `Ring.hairline`.
- Three weights only: `.regular` (read), `.medium` (interact), `.semibold`
  (announce). No bold.
- Tracking-driven display headlines: -2.4 to -0.96pt on display-tier text.

## 2. Color Roles

All color is exposed through `WorkspaceFoundation` enums. The names below are
the role; consult the source for exact values and dark-mode counterparts.

### Surface (`WorkspaceFoundation.Surface`)
| Role | Token | When to use |
|---|---|---|
| Page canvas | `canvas` | Main drawing surface, neutral matte |
| Section background | `sectionBackground` | Faint tint for grouped content |
| Card fill | `cardFill` | Subtle fill for cards and list rows |
| Row highlight | `rowHighlight` | Inline emphasis (badges, manual override) |
| Tag fill | `tagFill` | Tag/chip backgrounds, confidence-bar tracks |
| Raised | `raised` | Elevated panels (one step above canvas) |
| Overlay | `overlay` | Floating popovers, panels |
| Generic translucent | `surfaceFill` | Workspace overlay tinted surface |
| Material | `material` | `.ultraThinMaterial` for chrome surfaces |

### Foreground (`WorkspaceFoundation.Foreground`)
- `primaryLabel` — primary text (system primary)
- `secondaryLabel` — supporting copy
- `disabledForeground` — disabled control text (auditable WCAG token, not raw 0.55)
- `destructiveForeground` — destructive actions only

### Stroke / Ring
- `Stroke.divider` — subtle separators (`.separatorColor` × 0.35)
- `Stroke.interactiveIdleStroke` / `interactiveHoverStroke` — control outlines
- `Stroke.destructiveHoverStroke` — destructive hover ring
- `Stroke.tagBorder` — tag/chip outline
- `Stroke.focusRingStroke` — input focus
- **`Ring.hairline`** — Geist-style shadow-as-border (use this on cards)
- **`Ring.light`** — lighter ring for tabs and image cards

### Selection / Interaction
- `Selection.selectionAccent` — selected-row accent
- `Interaction.interactiveHoverFill` / `interactivePressedFill` — hover/press fills
- `Interaction.destructiveHoverFill` — destructive hover background
- `Interaction.disabledFill` — disabled (transparent by default)

### Shell (`WorkspaceFoundation.Shell`)
Used by the window chrome layer. `background`, `stroke`, `shadow`, `divider`.

## 3. Typography

System font (San Francisco) — we do not bundle Geist. The system font already
gives macOS-native feel; the Vercel-style discipline lives in the **weight,
size, and tracking** rules below, not in the typeface.

### Hierarchy (`WorkspaceFoundation.Typography`)

| Role | Token | Notes |
|---|---|---|
| Display Hero | `displayHero` + `displayHeroTracking` (-2.4) | 48pt semibold |
| Display Section | `displaySection` + `displaySectionTracking` (-1.28) | 32pt semibold |
| Card Title | `displayCardTitle` + `displayCardTitleTracking` (-0.96) | 24pt semibold |
| Section Header | `sectionHeader` | `.subheadline.weight(.semibold)` |
| Body | `primaryLabel` | `.body` |
| Secondary | `secondaryLabel` | `.callout` |
| Caption | `caption` | `.caption` |
| Meta numeric | `metaNumeric` | `.caption.monospacedDigit()` |

### Principles

- **Display-tier always pairs Font + tracking.** Apply both:
  ```swift
  Text("Color Anima")
      .font(WorkspaceFoundation.Typography.displayHero)
      .tracking(WorkspaceFoundation.Typography.displayHeroTracking)
  ```
- **Three weights, strict roles.** `.regular` (400) for reading, `.medium`
  (500) for UI/interactive labels, `.semibold` (600) for headings and emphasis.
  Avoid `.bold` (700) outside tiny micro-badges.
- **Tracking scales with size.** -2.4 at 48pt, -1.28 at 32pt, -0.96 at 24pt,
  zero or near-zero at 16pt and below.

## 4. Components

### Cards

Geist cards are flat in elevation but sit on a hairline ring with a subtle
two-layer drop shadow. SwiftUI equivalent:

```swift
content
    .padding(WorkspaceFoundation.Metrics.space4)
    .background(WorkspaceFoundation.Surface.raised, in: RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.cardCornerRadius, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.cardCornerRadius, style: .continuous)
            .stroke(WorkspaceFoundation.Ring.hairline, lineWidth: WorkspaceFoundation.Ring.width)
    )
    .shadow(color: WorkspaceFoundation.Elevation.cardLiftColor,
            radius: WorkspaceFoundation.Elevation.cardLiftRadius,
            x: 0, y: WorkspaceFoundation.Elevation.cardLiftY)
    .shadow(color: WorkspaceFoundation.Elevation.cardDepthColor,
            radius: WorkspaceFoundation.Elevation.cardDepthRadius,
            x: 0, y: WorkspaceFoundation.Elevation.cardDepthY)
```

### Buttons / Controls

- Functional controls (default): `Metrics.controlRadius` (6), `Metrics.space2`
  vertical / `space4` horizontal padding, `.medium` weight 14pt label.
- Compact chrome controls: `Metrics.compactControlCornerRadius` (9) — current
  workspace standard.
- Pill badges: prefer SwiftUI's native `Capsule()` shape (idiomatic and
  resolution-independent). `Metrics.pillRadius` (9999) exists only as a
  fallback for cases where a `RoundedRectangle` corner-radius API is
  unavoidable; do not reach for it first. Background `Surface.tagFill`,
  border `Stroke.tagBorder`, label 12pt `.medium`.
- Inline code spans: `Metrics.microRadius` (2).

### Focus

Focus rings always use `Stroke.focusRingStroke` (accent × 0.75 opacity) on
text-input controls; standard SwiftUI focus styling everywhere else.

## 5. Spacing & Layout

### 4-pt grid (`WorkspaceFoundation.Metrics`)
1, 2, 3 (micro, off-grid, dense rows / badge insets only),
4 (`space1`), 8 (`space2`), 10 (`space2_5`), 12 (`space3`), 14 (`space3_5`),
16 (`space4`), 20 (`space5`), 24 (`space6`), 28 (`space7`).

Use `space*` tokens. Off-grid micro values exist for density audits and should
not be promoted to general use.

### Whitespace

The Geist site relies on sectional rhythm via huge whitespace and sectional
hairlines. Translate this to macOS by:

- Letting `Spacer()` and large vertical paddings (`space6`, `space7`) carry
  rhythm in informational panels.
- Avoiding visual noise (raised fills, drop shadows) where a hairline
  (`Stroke.divider` or `Ring.hairline`) suffices.

### Corner radii

- `microRadius` (2) — inline spans
- `controlRadius` (6) — Geist-style buttons/links
- `compactControlCornerRadius` (9) — compact chrome controls (workspace standard)
- `footerButtonCornerRadius` (10)
- `rowCornerRadius` (12)
- `cardCornerRadius` (14)
- `frameCardCornerRadius` (16)
- `pillRadius` (9999) — fallback only; prefer `Capsule()` in new code

## 6. Elevation

Elevation is achromatic and minimal. We do not use Material Design-style
elevation curves.

| Level | Treatment | Use |
|---|---|---|
| Flat | No shadow, no ring | Body content, text |
| Ring | `Ring.hairline` overlay | Default surface delineation |
| Light Ring | `Ring.light` overlay | Tabs, image containers |
| Lift | Ring + `Elevation.cardLift` shadow | Standard cards |
| Card | Ring + `cardLift` + `cardDepth` shadows | Featured cards, primary panels |
| Focus | `Stroke.focusRingStroke` outline | Keyboard focus on inputs |

## 7. Do / Don't

### Do
- Use `Ring.hairline` instead of `RoundedRectangle().strokeBorder(Color.gray)`.
- Apply both Font and tracking on display-tier text.
- Stay achromatic — let the user's artwork carry color.
- Use `space*` tokens for padding; never raw integers.
- Pair `Foreground.disabledForeground` with `Interaction.disabledFill` for
  disabled controls.

### Don't
- Don't use `.bold` (700) on body text. `.semibold` is the maximum.
- Don't use `.shadow(radius: 12+)` — Geist depth is whisper-level.
- Don't introduce decorative accent colors. The only chromatic accent is
  destructive red.
- Don't combine `pillRadius` (or `Capsule()`) with primary actions — pills
  are for badges/tags. And in new code, reach for `Capsule()` before
  `pillRadius`; the magic number is a fallback.
- Don't apply positive `.tracking()` on display text — Geist runs tight.
- Don't bypass the design-token gate by suppressing
  `scan-design-token-violations.sh` — increase migration coverage instead.

## 8. Migration Notes

The token surface is mature; view-layer adoption is the remaining work.

1. Run `sh scripts/scan-design-token-violations.sh --list` to see current
   per-file violation counts.
2. Migrate one file at a time: replace raw `font.system(size:)`, integer
   paddings, integer corner radii, and `Color.secondary.opacity(...)` with
   tokens.
3. Re-run `scan-design-token-violations.sh` after each change. Land migrations
   that lower the baseline; keep the trend monotonic toward zero.
4. New components must use Geist-scale tokens (`controlRadius`, `pillRadius`,
   `Ring.hairline`, display-tier typography). Do not retrofit existing
   workspace controls without an audit.

## 9. Reference

- Source of truth: `Sources/ColorAnimaAppWorkspaceDesignSystem/WorkspaceFoundation.swift`
- Lint gate: `scripts/scan-design-token-violations.sh` + `design-token-baseline.txt`
- Inspiration: Vercel/Geist design system. We mirror the philosophy
  (shadow-as-border, monochrome discipline, tracking-driven hierarchy), not the
  literal stylesheet (no Geist font, no CSS, no workflow accent colors).
