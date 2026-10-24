---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5pk11djd4m0hwy72zz8n0zp
  text: 'Correction to the description: plan.md now gives the decision in the first sentences of "Button styles first" and "Tint and accent", and in "Three actions, always available". The rest of the "Button styles first" item and of the "Tint and accent" item still gives the earlier prominent styles. When this card changes the code, also change that text so that plan.md and the code agree.'
  timestamp: 2026-10-24T09:14:18.930537+00:00
- actor: claude-code
  id: 01m5qja5bgvfw87rcjfvbgw4q3
  text: |-
    Research (implement):
    - Prominent styles in Sources/: `DefaultPromptAccessory` (ActionStyle enum + style(of:for:) + fileprivate actionStyle helper), `RequestActionStyle.swift` (RequestActionStyle .glassProminent/.borderedProminent cases, RequestDeckPlace.style(of:) table, modifier switch). Doc comments that name them: RequestDeck.swift, ElicitationView.swift (ElicitationFooter), ElicitationURLConsentView.swift. No prominent style in Examples/.
    - Submit is the only `.keyboardShortcut(.defaultAction)` today (ElicitationFooter); it keeps it and its order. No other default action is added.
    - EditorKit/EditorStyle (checkout c39c0a4 and local main fd2ce62) has no shared action-button style (only the private TagChipButtonStyle; `.selectionSurface` is a selection fill, card ^y2mrfxt territory). So the kit keeps the system `.glass` / `.bordered` styles; no EK bump is needed for this card.
    - Plan: once primary == secondary in every place, DefaultPromptAccessory's Action/ActionStyle/style(of:for:)/actionStyle helper is dead, so Send and Stop write `.buttonStyle(.glass)` directly (no shim). RequestAction keeps .primary (it names the default action of a card; semantic, used by 4 call sites) but RequestActionStyle loses its two prominent cases.
    - Tests to change: RequestDeckSurfaceTests tables, GlassPlacementTests (Input/ has no `.glassProminent` line), ThemeInjectionTests (new `prominentButtonStyle` form over kit + demo support + demo, fixture lines appended so existing line numbers keep), ComposerProminentActionTests (rewritten: both buttons write `.buttonStyle(.glass)`), doc comments in GlassAccessibilityTests, SystemStructureTests look-alike line that quotes the old table row.
  timestamp: 2026-10-24T18:21:03.728174+00:00
- actor: claude-code
  id: 01m5qk9yd50en01sdnzez17pt5
  text: |-
    Implementation landed (not committed, card stays in doing).
    - Sources: RequestActionStyle lost .glassProminent/.borderedProminent; RequestDeckPlace.style(of:) gives .bordered for every action in .bar, .glass for every action in .barWithoutGlass, .glass for primary/secondary in content, .inherited for standard in content. DefaultPromptAccessory: dropped Action/ActionStyle/style(of:for:)/fileprivate actionStyle helper (dead once both buttons are .glass); Send and Stop write `.buttonStyle(.glass)` directly. Submit keeps `.keyboardShortcut(.defaultAction)` and its last place in the row. Doc comments updated in RequestDeck, ElicitationView (footer), ElicitationURLConsentView, PermissionView.
    - Tests: RequestDeckSurfaceTests tables; GlassPlacementTests `theInputHasNoProminentGlassButtonStyle`; ThemeInjectionTests new form `prominentButtonStyle` (whole-word glassProminent / borderedProminent / GlassProminentButtonStyle / BorderedProminentButtonStyle, over kit + DemoSupport + demo, no allow list), samples, look-alikes, fixture lines 33-34 appended to Violating/TintAndTheme.swift so existing line numbers keep; ComposerProminentActionTests rewritten to a source check (Send and Stop each `.buttonStyle(.glass)`); doc-only updates in GlassAccessibilityTests, SystemStructureTests look-alike line.
    - plan.md: "Glass only on floating controls", "Button styles first", "Tint and accent", "Three actions, always available" now match the code (the "earlier rule" sentence now names only ^y2mrfxt).
    - Discovery: the old composer-field-running-* snapshots showed a large accent-blue area (~77k px across the field band, x23-937 y115-256 at 3x) from the prominent Stop glass blending in the container; the new images are neutral (light mean rgb 0.98, dark 0.37, 0 saturated px). bottom-bar-buttons-*.png did not change.
    - Note: no image viewer is available in this session (native Read disabled, files tool rejects PNG), so I checked the four re-recorded PNGs by pixel analysis (scratchpad diff.swift) rather than by eye. A human look is still worthwhile.

    ### implement — changed
    - evidence: `swift test` 1787 tests / 218 suites passed with 7 known issues; re-recorded 4 PNGs (GlassSnapshotTests/composer-field-running-{light,dark,increase-contrast,reduce-transparency}.png); generate_xcodeproj.rb + demo xcodebuild BUILD SUCCEEDED, 0 warnings from repo sources (1 appintentsmetadataprocessor tool line); Scripts/test-examples.sh AgentViewKitDemo passed (10 UI tests, 0 failures, "The example gate passed.")
    - files: Sources/AgentViewKit/{HumanInTheLoop/RequestActionStyle.swift, HumanInTheLoop/RequestDeck.swift, HumanInTheLoop/PermissionView.swift, Input/DefaultPromptAccessory.swift, Elicitation/ElicitationView.swift, Elicitation/ElicitationURLConsentView.swift}; Tests/AgentViewKitTests/{HumanInTheLoop/RequestDeckSurfaceTests.swift, Input/ComposerProminentActionTests.swift, Theme/GlassAccessibilityTests.swift, 4 snapshot PNGs}; Tests/PackageStructureTests/{ThemeInjectionTests.swift, GlassPlacementTests.swift, SystemStructureTests.swift, Fixtures/ThemeInjection/Violating/TintAndTheme.swift, Fixtures/ThemeInjection/Clean/ThemeInText.swift}; plan.md
    - next: /review
  timestamp: 2026-10-24T18:38:25.189849+00:00
- actor: claude-code
  id: 01m5qkpqc51w8my70bsfbpanta
  text: |-
    ### test — green
    - evidence: swift test — 1787 tests in 218 suites passed, 7 known issues (expected), 0 failures; xcodeproj regenerated and xcodebuild AgentViewKitDemo BUILD SUCCEEDED, 0 warnings from repo sources (only the Xcode tool's appintentsmetadataprocessor notice); Scripts/test-examples.sh AgentViewKitDemo — 10 UI tests, 0 failures, example gate passed under the UI-test lock, 0 skipped
    - next: review/commit; no files changed by this step
  timestamp: 2026-10-24T18:45:23.973921+00:00
position_column: doing
position_ordinal: '8380'
title: Use plain glass and bordered styles for Send, Stop, Submit and the request actions (accent only for selection and focus)
---
User decision (2026-10-24, relayed by kanbanviewkit-84), shared style rule 2, strict: the accent is only for the selection and the focus. A prominent button style gives the accent tint, so the kit uses no prominent button style.

To do:
- Send and Stop of the composer use `.glass`, not `.glassProminent` (`DefaultPromptAccessory.style(of:for:)`).
- `RequestDeckPlace.style(of:)` and `requestActionStyle(_:)`: the primary action uses `.glass` in content and in a bar with no glass, and `.bordered` on the deck glass in a bar. No `.glassProminent` and no `.borderedProminent`.
- The Submit action of an elicitation card uses the same place style (plan.md "Three actions, always available").
- Keep the primary action clear without a tint: it is the default action (`.keyboardShortcut(.defaultAction)` where it is the default today), and it keeps its order in the row.
- Update `GlassPlacementTests` (no `.glassProminent` line in `Input/`), `RequestDeckSurfaceTests` (the style of each action in each place), and add to `ThemeInjectionTests` a form that forbids `.glassProminent` and `.borderedProminent` in the kit, the demo support and the demo.
- plan.md "Button styles first" and "Tint and accent" already state the decision; keep the text and the code the same.

Acceptance:
- No `.glassProminent` and no `.borderedProminent` in Sources/ or the demo; a structure test checks it.
- `swift test` is green, and the demo builds.
- Re-record only the snapshots whose look changes (for example `bottom-bar-buttons-*.png`), listed by name with their PNG paths. #avk-8