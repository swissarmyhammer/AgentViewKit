---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4q5pzna1jjy2db66p0z9qj5
  text: |-
    Research done.
    - A scan of Sources and Examples finds four fixed code fonts: PermissionView (`.body.monospaced()` for the command, `.caption.monospaced()` for the working directory), ElicitationURLConsentView (`.callout.monospaced()` for the URL), and MathView (`.system(size: baseSize, design: .monospaced)` for the source fallback). MathView is not on the card; the owner said to fix each such font in the same way.
    - `.monospacedDigit()` is a digit form of the current font, not a code font. It stays.
    - DistinctRolesTheme has `editorFont = .system(.callout, design: .serif)`. Callout is near the body size, so a height test cannot see it. The plan is to make it a large text style, as `proseFont` is.
    - Size rule: use `editorTheme.editorFont` with no size change. The other views (CommandOutputView, EntryTimingView, JSONDisclosure) do the same. Record the rule in Docs/decisions/dynamic-type.md.
  timestamp: 2026-10-12T04:25:10.570530+00:00
- actor: claude-code
  id: 01m4q65a31hbvtxm1m8am6an4m
  text: |-
    Implementation done. Tests first.
    - RED: the four new tests failed for the expected reason. The scan found PermissionView (two lines), ElicitationURLConsentView and MathView. Each hosted test measured the same height with and without the theme (33.08 / 15.0 / 16.0 pt).
    - GREEN: the same four tests passed after the change.
    - Interesting: the MathView fallback used the size of the environment font. It now uses `editorFont` as it is, the same as the other code text. The math glyphs still scale from the environment font.
    - The build prints `warning: missing creator for mutated node: ... mlx-swift_Cmlx.bundle/Contents/MacOS`. It comes from SwiftPM and the mlx-swift bundle, not from this change.
    - Not changed: `.monospacedDigit()` in DiffView, ContextUsageView, UsageRingView, ElicitationFieldViews and InlineCitation. It is a digit form of the current font, not a code font.
  timestamp: 2026-10-12T04:33:00.001537+00:00
- actor: claude-code
  id: 01m4q65dgxkgtcwt87xwtnvty0
  text: |-
    ### implement — changed
    - evidence: 9 files — Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift, Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift, Sources/AgentViewKit/Content/MathView.swift, Docs/decisions/dynamic-type.md, Tests/PackageStructureTests/FixedCodeFontTests.swift (new), Tests/AgentViewKitTests/Theme/DistinctRolesTheme.swift, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift, Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift, Tests/AgentViewKitTests/Content/MathViewHostedTests.swift. Full `swift test`: 1 + 118 + 1149 tests pass, 0 fail, 1 known issue (the old withKnownIssue in HostedLayoutExpectationsTests). Load average 25.31 at the start, 19.44 at the end.
    - next: /review. The task stays in doing.
  timestamp: 2026-10-12T04:33:03.517138+00:00
position_column: doing
position_ordinal: '80'
title: Use editorFont for the code text of PermissionView and ElicitationURLConsentView
---
## What
Two kit views show code text in a fixed system monospaced font, not in the `editorFont` role of the EditorKit theme:
- `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift`: the command uses `.font(.body.monospaced())` and the working directory uses `.font(.caption.monospaced())`.
- `Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift`: the URL uses `.font(.callout.monospaced())`.

The owner decision (the EditorKit theme is the one theme of the kit) says that each font comes from the EditorKit theme. Other views (TerminalView, CommandOutputView, ErrorView, JSONDisclosure, EntryTimingView) already use `editorTheme.editorFont`.

Found during ^bg7j0hc.

## Work
- [x] Decide the size rule: `editorFont` has one size (body). The caption and callout sizes need a decision, for example `editorFont` with no size change, or a rule in the decision record.
- [x] Change the three fonts to come from `editorTheme.editorFont`.
- [x] Hosted test with a theme whose `editorFont` is distinct (as in ProseFontHostedTests).
- [x] Add a scan test, if useful, that no kit view uses `.monospaced()` for code text.
- [x] Search the whole Sources tree for other fixed monospaced fonts and change them in the same way (owner request). The search found one more: the source fallback of `MathView`.

## Result
- Size rule: each view uses `editorFont` with no size change. `Docs/decisions/dynamic-type.md` records the rule.
- `PermissionView`, `ElicitationURLConsentView` and the `MathView` source fallback use `editorTheme.editorFont`.
- `DistinctRolesTheme.editorFont` is now `.system(.title, design: .serif)`, so a height test can see the role.
- Hosted tests: `theCommandUsesTheEditorFontOfTheEditorTheme`, `theURLUsesTheEditorFontOfTheEditorTheme`, `theSourceFallbackUsesTheEditorFontOfTheEditorTheme`.
- Scan test: `Tests/PackageStructureTests/FixedCodeFontTests.swift` (`.monospaced`, `.monospacedSystemFont`, `.userFixedPitchFont`; `.monospacedDigit()` stays allowed).