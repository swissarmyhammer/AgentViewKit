---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5pjkvsjxh51jcp9hzqwqraq
  text: |-
    ### user decision (relayed by testudoapp-2c, 2026-10-24)
    YES to moving AgentKeymap onto D137 / EditorKit StandardChords:
    - Copy Thread: ⌃⌘C (was ⇧⌘C)
    - Next/Previous Prompt: ⌃⌘↓ / ⌃⌘↑ (was ⌥↓ / ⌥↑)
    - Next/Previous Request: ⌃⌘] / ⌃⌘[ (was ⇧⌘} / ⇧⌘{)
    - Copy Message stays ⌃⇧⌘C
    No deprecation aliases for the old chords (no-shims rule). Testudo UI tests press none of the old chords (MenuTests reads "Next Prompt" by title only), so Testudo needs no change.
  timestamp: 2026-10-24T09:07:07.186406+00:00
- actor: claude-code
  id: 01m5pkxyntv69r3mj8r9vnqqax
  text: |-
    ### research (implement)
    - EditorKit resolves at 3bc9d3e. `StandardChords` (EditorCommands, already imported by AgentKeymap.swift) offers: submitNow ⌘↩, stop ⌘., leave ⎋, previousItem ⌃⌘↑, nextItem ⌃⌘↓, previousWaiting ⌃⌘[, nextWaiting ⌃⌘], copyItemAsText ⌃⌘C. No constant for Copy Message ⌃⇧⌘C (and none of macKeys/kitCommands equals it), so it stays the one AgentKeymap literal.
    - Plan: defaultChords reads the constants for send/cancel/copyThread/jumpTo*/previous/nextRequest; drop AgentKeymap.commandReturn/commandPeriod/commandShiftC/optionUp/optionDown/commandShiftLeftBracket/commandShiftRightBracket (no shims). Tests that read commandPeriod/commandReturn move to StandardChords.stop/submitNow.
    - KeyChordTranslator spells from charactersIgnoringModifiers and upper-cases a printable key under ⌃/⌥/⌘; with Control the bracket key stays `[`/`]` (no Shift fold), so ⌃⌘[ / ⌃⌘] match by raw value.
    - Docs: no README/ARCHITECTURE/plan keymap table lists the chords; only the AgentKeymap doc table and comparison.md (`.help("Copy  ⇧⌘C")`) name the old keys. Demo sources and UI tests press no agent chords; MainMenuEndToEndTests reads menus by title.
  timestamp: 2026-10-24T09:30:06.394819+00:00
- actor: claude-code
  id: 01m5pmjz9p3sd3r5s2wrvctzd0
  text: |-
    ### implementation landed
    - `AgentKeymap.defaultChords` now reads StandardChords: send=submitNow, cancel=[stop, leave], copyThread=copyItemAsText (⌃⌘C), jumpToPrevious/Next=previousItem/nextItem (⌃⌘↑/⌃⌘↓), previous/nextRequest=previousWaiting/nextWaiting (⌃⌘[/⌃⌘]). Copy Message keeps `controlShiftCommandC` (⌃⇧⌘C), the only chord with no StandardChords constant and the only chord literal left in the type.
    - Removed public constants with no shims: `commandReturn`, `commandPeriod`, `commandShiftC`, `optionUp`, `optionDown`, `commandShiftLeftBracket`, `commandShiftRightBracket`. AVK tests that read `commandReturn`/`commandPeriod` now read `StandardChords.submitNow`/`.stop`.
    - Tests: AgentCommandsTests keymap table has the new spellings; new `theKitChordsAreTheStandardChords` and `copyMessageIsAKitChordThatTheSharedTableDoesNotUse` (the Copy Message re-check: ⌃⇧⌘C is in neither macKeys nor kitCommands). AgentKeymapKeyEventTests is now one parameterized test that sends real Control-Command events for C, Up, Down, [ and ]. It went RED on the old keymap (translator spelled ⌃⌘] against ⇧⌘}) and GREEN after the change.
    - Docs: the AgentKeymap doc table (with a StandardChords column) and comparison.md §5.6 (`.help("Copy  ⌃⌘C")`). README, ARCHITECTURE, plan.md and Docs list no agent chords. The demo sources press no agent chords.

    ### downstream impact (TestudoApp) — not fixed here, outside this repo
    The relayed note says Testudo needs no change, but TestudoApp reads two of the removed constants and will not compile once it moves to this AVK revision:
    - TestudoApp/Sources/SAHKit/Commands/AppCommandSpec.swift: `AgentKeymap.commandPeriod` (session.stop) and `AgentKeymap.commandReturn` (task.doIt)
    - TestudoApp/Tests/SAHKitTests/AgentMenuTests.swift and SessionStopTests.swift: `AgentKeymap.commandPeriod`
    The fix is `StandardChords.stop` / `StandardChords.submitNow` (same chords, ⌘. and ⌘↩). Testudo should take this together with the AVK bump.
  timestamp: 2026-10-24T09:41:35.158913+00:00
- actor: claude-code
  id: 01m5pmk5aa1rg91645g7kyja2y
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Commands/AgentKeymap.swift, Tests/AgentViewKitTests/Commands/AgentKeymapKeyEventTests.swift, Tests/AgentViewKitTests/Commands/AgentCommandsTests.swift, Tests/AgentViewKitTests/Commands/AgentCommandPlacementTests.swift, Tests/AgentViewKitTests/Commands/AgentCommandGroupTests.swift, comparison.md. `swift test`: 1798 tests in 220 suites passed with 7 known issues (plus 229 and 1 in the other bundles), no warnings from repo sources. Demo `xcodebuild -skipMacroValidation -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile ... build`: BUILD SUCCEEDED, no repo-source warnings. `Scripts/test-examples.sh AgentViewKitDemo` (under the shared UI-test lock): 7 UI tests, 0 failures, TEST SUCCEEDED.
    - next: /review. TestudoApp must switch `AgentKeymap.commandPeriod`/`commandReturn` to `StandardChords.stop`/`submitNow` when it bumps AVK (see the comment above).
  timestamp: 2026-10-24T09:41:41.322204+00:00
- actor: claude-code
  id: 01m5pmygr0519qh4fy3gw79fxn
  text: |-
    ### test — green
    - evidence: swift test — 1798 tests in 220 suites passed, 7 known issues (expected), 0 failures; xcodebuild -project Examples/AgentViewKitDemo/AgentViewKitDemo.xcodeproj -scheme AgentViewKitDemo build — BUILD SUCCEEDED, 0 warnings from repo sources; Scripts/test-examples.sh AgentViewKitDemo — 7 UI tests, 0 failures, gate passed (under the shared UI-test lock)
    - next: review/commit. Nothing committed; no draft files left.
  timestamp: 2026-10-24T09:47:53.472936+00:00
position_column: doing
position_ordinal: '8380'
title: 'AgentKeymap: move the agent keys to the D137 kit key rule (StandardChords)'
---
Found while doing ^5nyqhzc. TestudoApp D137 (features/decisions.md) and EditorKit `StandardChords` (3bc9d3e) say each kit command uses Control-Command, and name the keys: Copy Thread ⌃⌘C, Jump to Previous/Next ⌃⌘↑/⌃⌘↓, previous/next Request ⌃⌘[/⌃⌘]. EditorKit's header says "`AgentKeymap` (AgentViewKit) and `BoardKeymap` (KanbanViewKit) use these constants and have no chord text of their own."

AgentKeymap at HEAD still binds the pre-D137 keys: Copy Thread ⇧⌘C, Next/Previous Prompt ⌥↓/⌥↑, Next/Previous Request ⇧⌘}/⇧⌘{. ^5nyqhzc gave Copy Message ⌃⇧⌘C (Control-Command plus Shift, so it stays clear of the ⌃⌘C that D137 gives Copy Thread).

## What to do
- [x] Ask the user/Testudo to confirm the D137 move for AVK before changing keys (it changes shipped defaults).
- [x] Make `AgentKeymap.defaultChords` read the `StandardChords` constants (copyItemAsText / previousItem / nextItem / previousWaiting / nextWaiting) and drop its own chord literals where a constant exists.
- [x] Re-check Copy Message ⌃⇧⌘C against the new table.
- [x] Update AgentKeymapKeyEventTests, AgentCommandsTests keymap table, and the AgentKeymap doc table. #avk-8