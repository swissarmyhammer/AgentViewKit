---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5nsra239m9d0j0ysfr7h69j
  text: |-
    Research (implement):
    - Palette source: EditorKit `ThemeRoleDefaults.terminalPalette` (Sources/EditorTheme/TerminalPalette.swift @3bc9d3e): black = SystemColor.textBackground, brightBlack = systemGray, white = secondaryLabel, brightWhite/foreground = textColor, background = Color.clear. Zed/VSCode importers fall back to it for absent or fully transparent `terminal.background`.
    - The remap can live cleanly in AVK: `ANSIText` (AVK's own SGR parser, the terminal adapter) already chooses the palette entry per SGR code, and it knows whether a code is a text color or a fill. A palette-level remap in EditorKit could not tell foreground from background uses, so no EditorKit change is needed.
    - "Theme sets no terminal.background" = `palette[.background]` resolves fully transparent (same rule the importers use).
    - Kit constraints: FixedColorTests forbids `NSColor.`, `Color(nsColor:` and named colors in Sources; `Color.primary`/`Color.secondary` (label / secondaryLabel, dynamic) are allowed. So the remap uses Color.primary/secondary and opacity tints of Color.primary for fills.
    - TerminalBlockFrame already draws `.clear` under the default palette (EditorKit ^0apj6a2); the no-fill test is a guard, it cannot be red.
    - Terminal snapshot fixture output has no SGR codes, so the remap should not change `terminal-*` images.
  timestamp: 2026-10-24T01:52:38.467042+00:00
- actor: claude-code
  id: 01m5nt7y69vmsh294pr0r3bpww
  text: |-
    Implementation landed (not committed, task left in doing).

    Where it went: the remap is in AVK, inside the terminal adapter (`ANSIText`). EditorKit is unchanged and needs no proposal. A remap at palette level in EditorKit could not tell a text use of a gray from a fill use, and the card needs different colors for each.

    Mapping, used only when `palette[.background]` resolves fully transparent (`TerminalPalette.hasBackground`):
    - Text: 30 and 97 map to `Color.primary` (the label color). 90 and 37 map to `Color.secondary` (secondaryLabel).
    - Fills: 40 and 107 map to `Color.primary.opacity(0.24)`. 100 and 47 map to `Color.primary.opacity(0.12)`.
    - The same palettes cover 38;5;0-15 and 48;5;0-15.
    - Fills are tints of the label color, not solid inverses. A solid label fill would hide the default text on it, because output often sets only a background. A fill in the window color would not show.
    - The full table and its reasons are in Sources/AgentViewKit/Terminal/TerminalPalette+Contrast.swift.
    - `TerminalBlockFrame` now passes `fill: nil` when the palette has no background.
    - A theme that sets a background keeps its palette as it is: `textColors` and `fillColors` return `self`.

    Finding: NSColor(Color.primary) stays dynamic in the EditorKit editor. The hosted test resolves it in .darkAqua and in both high-contrast appearances, and the contrast holds in each.

    Did not work at first: the first test version required 4 color runs. With the remap, 30 and 97 (both primary) merge into one run, because `ANSIText.Output` joins runs that have equal styles. The test now finds the run that covers each gray byte.

    ### implement — changed
    - evidence: TDD red, `swift test --filter TerminalContrastHostedTests`: 16 issues before the fix (text contrast failed in all 4 appearances, fill visibility and legibility failed in all 4). Green after. Guard tests that passed from the start because the behavior already held: no frame fill under the default theme (EditorKit ^0apj6a2 already made it clear), and palette unchanged under DistinctRolesTheme. Full `swift test`: 1787 tests in 219 suites and 229 tests in 31 suites passed. The 7 known issues are the existing withKnownIssue meta-tests. The only warning is the mlx `missing creator` build-system warning from a dependency. Demo: `xcodebuild -scheme AgentViewKitDemo build` printed BUILD SUCCEEDED. No UI run.
    - snapshots: none re-recorded. terminal-light, terminal-dark, terminal-reduce-transparency and terminal-increase-contrast pass unchanged, because the fixture output has no SGR codes.
    - files: Sources/AgentViewKit/Terminal/TerminalPalette+Contrast.swift (new), Sources/AgentViewKit/Terminal/ANSIText.swift, Sources/AgentViewKit/Code/EditorBlockChrome.swift, Tests/AgentViewKitTests/Terminal/TerminalContrastHostedTests.swift (new), plan.md, Docs/decisions/visual-audit.md
    - next: /review
  timestamp: 2026-10-24T02:01:10.601774+00:00
position_column: doing
position_ordinal: '8380'
title: 'Terminal blocks stay clear: remap ANSI black/white so they contrast with whatever shows through'
---
The user's decision, relayed by testudoapp-2c on 2026-10-23: "Terminal blocks: clear, fix the contrast."

Since EditorKit ^0apj6a2 (in AVK at 3bc9d3e), the default terminal palette background (SGR 49) is clear. So `TerminalBlockFrame` (Sources/AgentViewKit/.../EditorBlockChrome.swift:49-52) draws no fill under the default SystemTheme. But ANSI black (SGR 30) maps to the system text-background color, so black output is nearly invisible on a white or app background (measured in ^xqday3k). White (37/97) has the same problem in Light.

## What to do
- [x] Keep TerminalBlockFrame clear under the default theme: no fill (the user's transparent-by-default rule).
- [x] When the theme does NOT set `terminal.background`, remap the colors that can collide with the background so they always contrast with what shows through: SGR 30/90 (black, bright black) and 37/97 (white, bright white), foreground AND background uses, to label-relative system colors (e.g. `.labelColor` / `.secondaryLabelColor`, and their inverse where an SGR background needs contrast with the text on it). Pick the exact mapping, write it down in the code doc, and keep it dynamic so Light, Dark and Increase Contrast all work.
- [x] Decide where the remap lives: the AVK terminal palette adapter, or a proposal to EditorKit if the palette is EditorKit's. If it belongs in EditorKit, ask editorkit-28 rather than editing that repo.
- [x] A theme that sets `terminal.background` keeps its fill AND its palette unchanged.
- [x] Hosted tests (red first): under the default theme, black and white text each have a measurable contrast against the window background in Light and Dark; the frame has no fill; with a `terminal.background` theme, the fill and the original palette stay.
- [x] Re-record only the terminal snapshots that change, and list them.

Acceptance: full `swift test` green; the demo builds. #avk-8 #testudo-request