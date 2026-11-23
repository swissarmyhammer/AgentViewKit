---
assignees:
- claude-code
position_column: todo
position_ordinal: '8580'
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

- [ ] Remove the note, its identifier, its symbol and its UI path.
- [ ] Remove or change the tests of the note.
- [ ] A hosted test: after a resume with replayed items, the banner shows no note, and the replay marker goes away.

## Acceptance Criteria
- [ ] `grep -rn "partialHistory\|can be partial" Sources Tests IntegrationTests/Tests ScreenshotTests/Tests` gives no result.
- [ ] After a resume and its replay, the stream banner shows no bar.
- [ ] The headless suite, the changed hosted suite and the gallery pass.

## Tests
- [ ] Change `aResumeShowsTheReplayMarkerAndThenThePartialHistoryNote` first, so it expects no bar after the replay (it fails before the change). Rename it.
- [ ] `swift test` in the root: all pass, no code warnings.
- [ ] `cd IntegrationTests && swift test --filter SessionStateBannersHostedTests`: all pass.
- [ ] `HOME=<temp> swift test --package-path ScreenshotTests`: all pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.