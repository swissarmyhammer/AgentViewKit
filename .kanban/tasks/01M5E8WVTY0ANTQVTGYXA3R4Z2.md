---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5eb27r0we2vrfxhn8m0fr4a
  text: |-
    Research:
    - Only one `.foregroundStyle(.tint)` is in `Sources/AgentViewKit`: the listening symbol in `Input/SpeechInputButton.swift`. A search for `.tint` as a shape style, `TintShapeStyle`, `.tint(` modifiers and `ShapeStyle.tint` finds no other use. The other `tint` matches are property names (`Appearance.tint`, `Tick.tint`) and the functions `EditorTheme.Theme.tint(for:)` (status colors of the theme, not the tint shape style). Thus the list of other uses to change is empty.
    - `HostedViewHarness` gives only accessibility snapshots (label, value, frame), not the foreground style of a view. Thus a unit test cannot read the foreground style of the listening label. The acceptance is a structure test.
    - Plan: add a structure test to `GlassPlacementTests` (next to the test that Send is the one prominent action of `Input/`) that no file of `Input/` has `.foregroundStyle(.tint)`. It reuses `GlassPlacementTests.uses(of:inSwiftFilesBelow:relativeTo:allowing:)`, `GlassForm.callPattern(_:)` and `WordPattern.wholeWord(_:)`. The kit-wide guard stays with AVK-8t (^78jx8yr).
  timestamp: 2026-10-21T04:21:14.112660+00:00
- actor: claude-code
  id: 01m5eb8h56ycvac469mnfgt4ym
  text: |-
    Implementation:
    - `Sources/AgentViewKit/Input/SpeechInputButton.swift`: the listening symbol now has `.foregroundStyle(.primary)`, not `.foregroundStyle(.tint)`. The doc comment of `label` tells why: only Send has a tint.
    - List of other `.foregroundStyle(.tint)` and `.tint` shape style uses in `Sources/AgentViewKit`: none. Nothing else to change.
    - Listening state without the tint: the symbol changes from `SharedSymbol.microphone` to `SharedSymbol.listening` (a different shape), the variable value shows the input level, and the accessibility value is "Recording". Thus a person can see the state without the tint, and no comment on AVK-8u (^8q34yt8) is necessary. The screenshot check of AVK-8u still covers it.
    - Acceptance: `HostedViewHarness` cannot read a foreground style, so no unit test reads it. A structure test holds the change in the composer now: `GlassPlacementTests.noControlOfTheInputUsesTheTintAsAForegroundStyle` (pattern `GlassPlacementTests.tintForegroundStylePattern`, built from `GlassForm.callPattern(_:)` and `WordPattern.wholeWord(_:)`). The kit-wide guard is AVK-8t (^78jx8yr); it can move this pattern to the kit scope. The commit must record: "structure test, because the view tree does not show the foreground style".
    - TDD: RED: the new test failed with `["Sources/AgentViewKit/Input/SpeechInputButton.swift:85"]`. GREEN: it passed after the change.
  timestamp: 2026-10-21T04:24:40.358930+00:00
- actor: claude-code
  id: 01m5eb8m878eh58qpn14eccdv0
  text: |-
    ### implement — changed
    - evidence: 2 files — Sources/AgentViewKit/Input/SpeechInputButton.swift, Tests/PackageStructureTests/GlassPlacementTests.swift. `swift test`: 1448 tests in 176 suites passed, 2 known issues that existed before (HostedLayoutExpectationsTests, ThemeHeightExpectationsTests); only warning is the mlx bundle warning that existed before.
    - next: /review
  timestamp: 2026-10-21T04:24:43.527588+00:00
- actor: claude-code
  id: 01m5ebd80w62s2c50e67419egq
  text: |-
    ### test — green
    - evidence: swift test (one run, 110 s). Test run 1: 1448 tests in 176 suites passed with 2 known issues. Test run 2: 167 tests in 23 suites passed. Test run 3: 1 test in 1 suite passed. 0 failures, 0 skipped.
    - PackageStructureTests ran and passed (GlassPlacementTests, ManifestTests, ImportBoundaryTests, SymbolNameTests and others).
    - warnings: only the mlx bundle build warning that existed before. No new warnings.
    - known issues: 2, the same as before (HostedLayoutExpectationsTests, ThemeHeightExpectationsTests).
    - next: review
  timestamp: 2026-10-21T04:27:14.844693+00:00
depends_on:
- 01M5DFBC5CXFEGX6P4XB316BQV
position_column: doing
position_ordinal: '80'
title: 'AVK-8ai SpeechInputButton: remove .foregroundStyle(.tint) on the recording symbol (SpeechInputButton.swift:85) and use .primary (D113 answer 5)'
---
## Why

D113 answer 5 and `style.md` "Tint": "Only the primary action of an area has a tint (for example Send, with `.glassProminent`). Other controls use `.primary` or `.secondary`, and no `.foregroundStyle(.tint)`." The dictation button is not the primary action.

## Files and lines

- `Sources/AgentViewKit/Input/SpeechInputButton.swift:83-85` (the listening symbol with `.foregroundStyle(.tint)`).
- Tests of the button in `Tests/AgentViewKitTests/Input/`.

## What to do

- [x] Replace `.foregroundStyle(.tint)` with `.foregroundStyle(.primary)`. The variable value of the symbol (`variableValue: level`) still shows that the button listens.
- [x] If a person cannot see the listening state without the tint, record this in a comment on AVK-8u (^8q34yt8) for the screenshot check. Do not add a tint.
- [x] Search `Sources/AgentViewKit` for each other `.foregroundStyle(.tint)` and `.tint` shape style. Change each one that is not on the primary action. Record the list in a comment on this card.

## Acceptance

- No `.foregroundStyle(.tint)` in `Sources/AgentViewKit` (a structure test of AVK-8t holds this later).
- A unit test reads the foreground style of the listening label if the view tree permits it; otherwise the AVK-8t structure test is the acceptance. Record which one in the commit.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8