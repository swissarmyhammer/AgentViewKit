# Visual audit (R12)

Status: decided. Source: plan.md §5 and §14 R12.

This file records the measured metrics of the Xcode 27 Coding Intelligence
assistant and of Claude Desktop, and the default values of the layout tokens
that come from them. The kit reads its layout tokens from the shared style of
the EditorKit `EditorStyle` target (`\.editorStyle`), and EditorKit took these
values for `EditorStyle.default` (^7dn35sm, KanbanViewKit plan.md decision 18).
Before that card, the kit held them in its own `AgentTheme`.
`Tests/AgentViewKitTests/Theme/StyleTokenGoldenTests.swift` parses the token
table below. It compares each row with the same token of `EditorStyle.default`.
When EditorKit changes a default, change the table in the same change.

Keep the header and the form of the rows. Put the token and the default value
in backticks. Write a point value as a number, and a weight or a density as
its SwiftUI case name. The table has no color token, no font token, and no
glass token. The colors and the fonts come from the EditorKit theme (see
"Colors and the code font"). The glass is always `.regular` (see "The
removed material level").

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
| `symbolWeight` | `regular` | not in the bundle | `--cds-font-weight-regular` 400 |
| `density` | `balanced` | no density setting | `data-density="comfortable"` |

### The removed material level

D113 answer 3 removes the `materialLevel` token and the `MaterialLevel` enum
from `AgentTheme`. The table had the row `materialLevel`, with the default
`regular`. The floating glass of the kit (now `floatingGlass()` of EditorStyle) is always
`.regular` glass. The Clear look and the Tinted look are system settings,
and the system applies them to `.regular` glass. Thus a theme does not
select the glass variant. This is a breaking change of the public API of
`AgentTheme`: the property `materialLevel`, the init parameter
`materialLevel:`, and the type `AgentTheme.MaterialLevel` are removed.

## Colors and the code font

Decision of the owner, 2026-10-11: the EditorKit themes are the themes of the
kit. The kit has one theme. It is the EditorKit `Theme` in the SwiftUI
environment value `\.editorTheme`. Set it with `.editorTheme(_:)` (module
`EditorSwiftUI`). Every color of the kit views comes from this theme. Each
font also comes from this theme, one for each EditorKit `FontRole` (^wg1hac2):
the UI font for the chrome, the display font for the prose and the text a
person types, and the code font for the code. The kit keeps no copy of a
color and no font.

When the host sets no theme, EditorKit gives `SystemTheme` (`.system`).
`SystemTheme` uses the Apple system colors. These colors follow light mode,
dark mode, increased contrast, and the accent color of the user.
`DefaultTheme.light` and `DefaultTheme.dark` are fixed presets. EditorKit can
also import a Zed, VS Code, or tmTheme file.

The shared style of the EditorKit `EditorStyle` target holds the layout
tokens: spacing, the corner radius scale, symbol weight, and density. The
theme gives the style (`Theme.style`), and `.editorTheme(_:)` writes it into
`\.editorStyle`. Before ^7dn35sm, the kit held these tokens in its own
`AgentTheme`.

Before this decision, `AgentTheme` had the tokens `accent`, `codeFont`, and
`statusColors`. These tokens are removed. EditorKit 95ef6c4 added the
`proseFont` role, so the `AgentTheme` token `proseFont` is also removed.
EditorKit ^wg1hac2 replaced `editorFont` and `proseFont` with the three font
roles `uiFont`, `displayFont` and `codeFont` (decision of 2026-10-23: the
composer, the text fields and the prose draw in the display role). The table
below gives the EditorKit role that replaces each one.

| kit use | EditorKit role | SystemTheme default |
|---|---|---|
| accent color of the kit views | `accent` | `Color.accentColor` |
| running status | `statusRunning` | the `accent` role |
| completed status | `statusSucceeded` | system green |
| failed status | `statusFailed` | the `severityError` role |
| cancelled status | `statusCancelled` | secondary label color |
| pending status | `statusPending` | tertiary label color |
| info notice | `severityInfo` | system blue |
| warning notice, URL warning, not-accepted attachment | `severityWarning` | system orange |
| error notice, error message, validation error | `severityError` | system red |
| code font: code blocks, diffs, commands, terminal and tool output, in SwiftUI text and in the EditorKit editor | `codeFont` | system monospaced font, body text style |
| display font: the prose of a message, the composer, the text fields | `displayFont` | system font, body text style |
| UI font: headers, labels, rows, the completion list, times | `uiFont` | system font, body text style |
| code text | `editorForeground` | `NSColor.textColor` |
| frame and text of a terminal or command output, ANSI colors 0-15 of the output | `terminalPalette` (`[.background]`, `[.foreground]`, `ansiColor(_:)`) | a clear background (EditorKit ^0apj6a2), the editor foreground, and Apple system colors; with a clear background the kit paints the four ANSI grays with label-relative colors (^4rck1pf, `TerminalPalette+Contrast.swift`) |
| selected text | `selection` | `NSColor.selectedTextBackgroundColor` |
| diff bands | `diffAddedBackground`, `diffRemovedBackground` | system green and system red at opacity 0.18 (`DiffTintDefaults.bandOpacity`) |
| +N / −N counts of a diff | `diffAddedText`, `diffRemovedText` | system green and system red at full opacity |

The kit does not draw the role `statusBarBackground` (D113 answers 1 and 4,
[EditorKit `style.md`](../../../EditorKit/style.md) "How the steps apply"). A code block has no
fill. The header row of a code block, a terminal, or command output is
content, not a bar: it has no fill, and a separator line is under it. Before
D113, the table had the row "frame of a code block" with `editorBackground`,
and the row "header bar of a code block, terminal, or command output" with
`statusBarBackground`. D113 replaces these two rows. `EditorThemeViewsTests`
checks the pixels, and `ContentFillTests` forbids the `statusBarBackground`
role and a theme color as a background.

EditorKit ^0apj6a2 (EditorKit main at 69d04fc) makes its views transparent by
default and removes the roles `editorBackground` and `gutterBackground`. The
EditorKit text view of a code block draws no background, which answers
^m231ph5 (the white fill behind the text of a code block). The default
terminal palette has a clear background too, so terminal output shows no fill
with a theme that sets no terminal background, such as `SystemTheme`.

The other roles that the EditorKit views read are `tabBarBackground`,
`tokenTint`, `diffChangedBackground`, and `diffHeaderBackground` (clear by
default). With `SystemTheme`, the code gets the syntax colors of Xcode. The
kit does not set the syntax colors to one color.

The kit maps each status to a role with the helpers in an extension of the
EditorKit `Theme` protocol: `statusColor(for:)` and `tint(for:)`. See
`connection-states.md` for the dot of an MCP server.

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
  the brand choice of the app. The kit uses the `accent` role of the EditorKit
  theme. With `SystemTheme`, this role is the accent color of the user.
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

- Row padding: `EditorStyle.rowPadding` gives `spacing.s` (8 pt) for the
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
  (plan.md §5), so that the host text size setting applies. The fonts come
  from the font roles of the EditorKit theme (decision of 2026-10-11): the
  prose font is `displayFont`, the code font is `codeFont`, and the chrome
  font is `uiFont` (^wg1hac2, decision of 2026-10-23).
- The accent is the `accent` role of the EditorKit theme. With `SystemTheme`,
  it is the accent color of the user, as in Xcode 27.
- The `balanced` density agrees with the comfortable density of Claude
  Desktop.
