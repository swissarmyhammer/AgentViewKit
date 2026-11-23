---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m850wj9x82ymwyr6ex1evfj0
  text: |-
    Implementation notes:
    - RED: the renamed hosted test `aResumeShowsTheReplayMarkerAndThenNoBar` failed at its last check (`!Self.showsAStreamBar(in: harness)`) before the change. GREEN after the change.
    - The new helper `showsAStreamBar(in:)` finds each element whose identifier starts with `session-stream-`. Thus it also finds a bar that no test names, and the test needs no identifier of the removed note.
    - `aResumeWithNoReplayedEntryShowsNoPartialHistoryNote` is now `aResumeWithNoReplayedEntryShowsNoBar`.
    - Also removed: the two strings of the note in `Localizable.xcstrings`, the note in the doc of `AgentThreadView`, the note in README.md, and "can be partial" in `Docs/decisions/acp-version.md` (now: the agent replays all the history that it retains).
    - The gallery note of `ReviewGalleryNotes.gallery` now tells that since ^tnwtcws the detail shows no stream banner after the replay; the new image is not judged yet.
    - The gallery command keeps no PNG on disk: the images are test attachments only.
  timestamp: 2026-11-23T20:17:18.141766+00:00
- actor: claude-code
  id: 01m850wp0fz5rq3x0kg2000k80
  text: |-
    ### implement — changed
    - evidence: root `swift test` 1653 + 59 tests pass, no code warnings; `swift test --filter SessionStateBannersHostedTests` 13 pass; `swift build --build-tests` in IntegrationTests and ScreenshotTests pass; gallery 45 tests pass. 12 files: Sources/AgentViewKit/Status/SessionStreamBanner.swift, Sources/AgentViewKit/Items/AgentSymbol.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Resources/Localizable.xcstrings, Tests/AgentViewKitTests/Status/PartialHistoryNoteTests.swift (deleted), Tests/AgentViewKitTests/Status/StatusBarEffectTests.swift, Tests/AgentViewKitTests/Items/SymbolConceptTests.swift, IntegrationTests/Tests/IntegrationTests/Status/SessionStateBannersHostedTests.swift, ScreenshotTests/Tests/ScreenshotTests/ReviewGalleryNotes.swift, Docs/decisions/acp-version.md, README.md
    - next: /review
  timestamp: 2026-11-23T20:17:21.935960+00:00
- actor: claude-code
  id: 01m851041f0gd7c3w9syj9cmm1
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit 7ed0132c): 0 findings, 0 confirmed, 0 refuted; 8 files reviewed. No validator matches Docs/decisions/acp-version.md, README.md and Localizable.xcstrings. The tool rules did not read PartialHistoryNoteTests.swift because the change deletes that file. Implement evidence: swift test 1653 + 59 pass; SessionStateBannersHostedTests 13 pass; the IntegrationTests and ScreenshotTests build-tests pass; gallery 45 pass.
    - next: none. The task is in done.
  timestamp: 2026-11-23T20:19:14.607921+00:00
position_column: done
position_ordinal: ffffffff9980
title: Remove the partial-history note of SessionStreamBanner
---
## What
The user (quoted by TestudoApp, card 01M84ZW63K5DPHT0ZJCFGBDS9Q): "the caveat message 'the history can be partial' is -- weasel words, we should no fooling have the actual transcript and message and no excuses thanks. and not have this warning". The agent side (foundationmodelsrouter-09) makes the history complete and stops the client from setting `.retained`.

Remove the note and each part of it. Add no other excuse text.

Files:
- `Sources/AgentViewKit/Status/SessionStreamBanner.swift`: remove `partialHistoryMessage`, `partialHistoryIdentifier`, `showsPartialHistoryNote(isHistoryRetained:isReplaying:hasEntries:)`, `isHistoryRetained`, the row of the note in `shownBars`, and the doc text about the note.
- `Sources/AgentViewKit/Items/AgentSymbol.swift`: remove `AgentSymbol.partialHistory`.
- `Tests/AgentViewKitTests/Status/PartialHistoryNoteTests.swift`: delete the file.
- `Tests/AgentViewKitTests/Status/StatusBarEffectTests.swift` and `Tests/AgentViewKitTests/Items/SymbolConceptTests.swift`: remove the entries of the note.
- `IntegrationTests/Tests/IntegrationTests/Status/SessionStateBannersHostedTests.swift`: the resume tests check that no partial-history text shows after a replay.

- [x] Remove the note, its identifier, its symbol and its UI path.
- [x] Remove or change the tests of the note.
- [x] A hosted test: after a resume with replayed items, the banner shows no note, and the replay marker goes away.

## Acceptance Criteria
- [x] `grep -rn "partialHistory\|can be partial" Sources Tests IntegrationTests/Tests ScreenshotTests/Tests` gives no result.
- [x] After a resume and its replay, the stream banner shows no bar.
- [x] The headless suite, the changed hosted suite and the gallery pass.

## Tests
- [x] Change `aResumeShowsTheReplayMarkerAndThenThePartialHistoryNote` first, so it expects no bar after the replay (it fails before the change). Rename it.
- [x] `swift test` in the root: all pass, no code warnings.
- [x] `cd IntegrationTests && swift test --filter SessionStateBannersHostedTests`: all pass.
- [x] `HOME=<temp> swift test --package-path ScreenshotTests`: all pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.