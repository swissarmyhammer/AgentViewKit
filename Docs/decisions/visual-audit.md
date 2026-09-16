# Visual audit (R12)

Status: decided. Source: plan.md §5 and §14 R12.

This file records the measured metrics of the Xcode 27 Coding Intelligence
assistant and of Claude Desktop, and the default values of `AgentTheme` that
come from them. `Tests/AgentViewKitTests/Theme/AgentThemeGoldenTests.swift`
parses the token table below. It compares each row with the same token of
`AgentTheme.default`. `Tests/AgentViewKitTests/Theme/DefaultTokens.json` holds
the same values. Change the table, the JSON file, and `AgentTheme.default`
together.

Keep the header and the form of the rows. Put the token and the default value
in backticks. Write a point value as a number, a font as
`<text style>/<design>`, and a color, a weight, a material level, or a density
as its SwiftUI case name.

## Tokens

| token | default | Xcode 27 | Claude Desktop |
|---|---|---|---|
| `spacing.xs` | `4` | system layout, not in the bundle | `--cds-pad-xs` 4 px (default density) |
| `spacing.s` | `8` | system layout, not in the bundle | `--cds-pad-sm` 8 px (comfortable) |
| `spacing.m` | `12` | system layout, not in the bundle | `--cds-pad-md` 12 px (comfortable) |
| `spacing.l` | `16` | system layout, not in the bundle | `--cds-pad-lg` 16 px (comfortable) |
| `radii.s` | `6` | system shapes, not in the bundle | `--cds-radius--xs` 6 px (comfortable) |
| `radii.m` | `8` | system shapes, not in the bundle | `--cds-radius` 8 px (comfortable) |
| `radii.l` | `10` | system shapes, not in the bundle | `--cds-radius--lg` 10 px (comfortable) |
| `materialLevel` | `regular` | not in the bundle | no glass |
| `symbolWeight` | `regular` | not in the bundle | `--cds-font-weight-regular` 400 |
| `accent` | `accentColor` | the system accent color | `--cds-text-accent` blue |
| `density` | `balanced` | no density setting | `data-density="comfortable"` |
| `proseFont` | `body/default` | SF Pro, body text style, 13 pt | Anthropic Sans, `--cds-font-size-prose` 16 px |
| `codeFont` | `body/monospaced` | SF Mono, 13 pt | SF Mono, `--cds-font-size-code` 13 px |
| `statusColors.running` | `blue` | not in the bundle | `--cds-text-accent` blue |
| `statusColors.completed` | `green` | not in the bundle | `--cds-text-git-added` green |
| `statusColors.failed` | `red` | not in the bundle | `--cds-text-danger` red |
| `statusColors.cancelled` | `gray` | not in the bundle | `--cds-text-git-draft` gray |
| `statusColors.pending` | `secondary` | not in the bundle | `--cds-text-disabled` |

## Sources

### Claude Desktop 1.34493.1

The app loads the conversation from claude.ai. The local window
(`app.asar`, `.vite/renderer/main_window/index.html`) has the full Claude
Design System (CDS) token sheet, and its root element sets
`data-density="comfortable"` and `data-platform="desktop"`. The values below
are from that sheet. They are exact values, not pixel estimates.

| metric | default density | comfortable density |
|---|---|---|
| radius (`--cds-radius`) | 6 px | 8 px |
| radius xs / sm / lg | 5 / 5 / 7 px | 6 / 7 / 10 px |
| padding xs / sm / md / lg / xl | 4 / 6 / 8 / 12 / 20 px | 6 / 8 / 12 / 16 / 24 px |
| gap xs / sm / md / lg / xl | 6 / 8 / 12 / 20 / 32 px | 8 / 12 / 16 / 28 / 40 px |
| body font size | 13 px | 14 px |
| prose font size | 14 px | 16 px |
| prose line height | 20 px | 24 px |
| code font size | 12 px | 13 px |
| code line height | 17 px | 19 px |

- Fonts: the sans font is Anthropic Sans, with the system font as the
  fallback. The mono font is SF Mono. The kit uses the system fonts
  (plan.md §5), so it takes the sizes, not the families.
- Accent: `--cds-text-accent` is blue (`#184f95` light, `#6da7ec` dark). It is
  the brand choice of the app. The kit uses the accent of the host.
- The sheet also has size steps 1 to 5 (`data-step`). Step 2 is the default
  density and step 4 is the comfortable density.

### Xcode 27.0

The assistant is native SwiftUI (`IDEIntelligenceChat.framework`). The bundle
has no metric file. The assistant uses the system text styles and the system
accent. These values are from AppKit on macOS 27:

| metric | value |
|---|---|
| body text style | SF Pro (`.SFNS-Regular`), 13 pt |
| callout text style | 12 pt |
| footnote and caption text styles | 10 pt |
| monospaced system font | SF Mono, 13 pt |
| system font size, small system font size | 13 pt, 11 pt |
| control accent color (blue accent) | sRGB 0, 0.478, 1 |

### Metrics that have no token

- Row padding: `AgentTheme.rowPadding` gives `spacing.s` (8 pt) for the
  `balanced` density. This agrees with the comfortable `--cds-pad-sm` (8 px).
  The `compact` density gives `spacing.xs` (4 pt), the default-density
  `--cds-pad-xs`.
- Message inset: `spacing.l` (16 pt), the comfortable `--cds-pad-lg`.
- Tool row height and usage ring size: the CDS sheet has no token for them.
  The views that show a tool row and the usage ring get their size from the
  text style and the row padding. They do not add a theme token.

### Captures

No screen captures are recorded. The agent that did this audit has no
screen recording permission, and a capture of the screen can show private
content. The Claude Desktop values above are exact stylesheet values. For
Xcode 27, the text sizes and the accent are exact AppKit values. The Xcode 27
spacing and radii are not measured: the kit uses the Claude Desktop values
for them. A person can add captures under `Docs/decisions/visual-audit/`
later. A capture does not change the table unless a new decision changes it.

## Decision

- The default spacing steps are 4, 8, 12, and 16 pt. They are the
  comfortable CDS paddings, with the default-density extra small step, on
  the 4 pt grid of macOS.
- The default radii are 6, 8, and 10 pt, the comfortable CDS radii.
- The default fonts are the system body text style: SF Pro for prose and SF
  Mono for code, 13 pt on macOS. The two apps show code at 13 pt. Claude
  Desktop shows prose at 16 px, but the kit follows the system text styles
  (plan.md §5), so that the host text size setting applies.
- The accent is the accent color of the host, as in Xcode 27.
- The `balanced` density agrees with the comfortable density of Claude
  Desktop.
