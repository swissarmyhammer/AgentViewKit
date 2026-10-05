---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4646r06g75v71vqs7hnx29v
  text: |-
    Research done. Discoveries:
    - `MessageActions.swift` has no `.system` case. `MessageActions.plainText` is in `AgentCommandTarget.swift`. No change to `MessageActions.swift` is necessary.
    - The card does not name these sites, but they use `.system` too: `Activity/TurnSummary.swift` (`isAgentItem`), `Model/ThreadChange.swift` (doc of `closeStreaming`), `Tests/.../Model/AgentThreadStreamingTests.swift`, and `Tests/.../Thread/RegistryResolutionTests.swift` (the `systemPromptView` override). I change them also, because the acceptance criteria say that no source uses `.system`.
    - `ThreadExporter` already omits `.system`. Thus the golden file `thread-export.md` has no system prompt text and does not change. Only the input thread of `ThreadExporterTests` changes.
    - README: the override table row `.systemPromptView` goes, as the compaction task did. The Components line `SystemPromptView` stays (task ^g95wwbs removes it with plan.md §9).
    - Names for `RemovedVocabularyTests`: `SystemPrompt`, `SystemPromptView`, `systemPromptView`, `systemPromptViewOverride`. Each is a whole word that matches only the removed code.
  timestamp: 2026-10-05T13:31:44.518365+00:00
- actor: claude-code
  id: 01m464h33mjn886q16yrat26q5
  text: |-
    Implementation landed.
    - RED: I added `SystemPrompt`, `SystemPromptView`, `systemPromptView` and `systemPromptViewOverride` to `RemovedVocabularyTests.removedSymbols`. `sourcesUseNoRemovedSymbol` failed with 15 uses in `Sources/`.
    - GREEN: I deleted `Model/SystemPrompt.swift` and `Items/SystemPromptView.swift`. I removed `.system` from `ThreadItem` (case, `record`, `kindName` and its doc), `ItemPatch` (case, `applyFields`, `emptyItem`), `AgentThread.finalTextPatch`, `ItemRow`, `ItemViewOverrides` (environment key and modifier), `ThreadMinimapView.tint`, `ThreadExporter` (case and doc), `AgentCommandTarget.plainText`, and the `closeStreaming` doc in `ThreadChange`.
    - `TurnSummary.isAgentItem` now returns `!isTurnStart(item)`. Before, it was a switch with `.userMessage, .system` and a `default`. The new body removes the `default` and the copy of the `isTurnStart` logic.
    - Tests: I removed the three system prompt tests of `MessageViewsHostedTests` and its `instructions` constant, `aSystemPatchChangesTheText`, `closeWritesTheFinalTextToTheSystemPrompt`, the `.systemPrompt` override kind of `RegistryResolutionTests`, and the `.system` items of `ThreadItemTests` (counts now 7 items and 6 record types), `ThreadExporterTests` and `ThreadFixturesTests`.
    - The golden file `thread-export.md` did not change, because the exporter already omitted `.system`. The golden test passes.
    - README: I removed the `.systemPromptView` row of the override table. The Components line stays for ^g95wwbs.
  timestamp: 2026-10-05T13:37:23.572337+00:00
- actor: claude-code
  id: 01m464h6fx3s5mgvq35ztnkwcw
  text: |-
    ### implement — changed
    - evidence: 23 paths — deleted Sources/AgentViewKit/Model/SystemPrompt.swift, Sources/AgentViewKit/Items/SystemPromptView.swift; changed README.md, Sources/AgentViewKit/{Activity/TurnSummary,Commands/AgentCommandTarget,Items/ThreadExporter,Model/AgentThread,Model/ItemPatch,Model/ThreadChange,Model/ThreadItem,Thread/ItemRow,Thread/ItemViewOverrides,Thread/ThreadMinimapView}.swift, Tests/AgentViewKitTests/{Items/MessageViewsHostedTests,Items/ThreadExporterTests,Model/AgentThreadApplyTests,Model/AgentThreadStreamingTests,Model/ThreadItemTests,TestSupport/ThreadFixturesTests,Thread/RegistryResolutionTests}.swift, Tests/PackageStructureTests/RemovedVocabularyTests.swift. Commands: `swift test --filter RemovedVocabularyTests` (RED 1 failure, then GREEN 3/3); `Scripts/check-readme.sh` (passed); `swift test` (1 + 65 + 1204 + 128 tests passed, 0 warnings); `Scripts/test-examples.sh AgentViewKitDemo` (2 UI tests passed, TEST SUCCEEDED).
    - next: /review
  timestamp: 2026-10-05T13:37:27.037163+00:00
- actor: claude-code
  id: 01m464w1nmkd6wqsy8dv4smdab
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — removed SystemPrompt, SystemPromptView and the .system cases; TurnSummary, README, tests; 23 paths
    - test: green — swift test, 1398 passed; README and demo UI gates passed
    - commit: 9aa8f6b
    - review: clean — 0 findings
  timestamp: 2026-10-05T13:43:22.548927+00:00
- actor: claude-code
  id: 01m464w3ewgywk7va9yf76jy8b
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 9aa8f6b). 0 findings, 0 confirmed, 0 refuted. 20 files reviewed. Not reviewed: 4 .kanban files (from .reviewignore) and README.md (no validator matches this file).
    - next: none. The task is in done.
  timestamp: 2026-10-05T13:43:24.380088+00:00
depends_on:
- 01M443K9H9357ZZAZQE6SD6TV0
position_column: done
position_ordinal: dc80
title: 'Remove the system prompt item: .system, SystemPrompt and SystemPromptView'
---
## What
Only `TranscriptMapping` (FoundationModels) made a system prompt item. ACP has no system prompt update (update.md §6).

- [x] Delete `Sources/AgentViewKit/Model/SystemPrompt.swift` and `Sources/AgentViewKit/Items/SystemPromptView.swift`.
- [x] Remove `.system` from `ThreadItem`, `ItemPatch` and `AgentThread`, and its cases from `ItemRow.swift`, `ItemViewOverrides.swift`, `ThreadMinimapView.swift`, `ThreadExporter.swift`, `MessageActions.swift` and `AgentCommandTarget.swift`.
- [x] Change the tests that use `.system`: `MessageViewsHostedTests`, `ThreadItemTests`, `ThreadExporterTests` (and its golden file in `Tests/AgentViewKitTests/Items/Fixtures`), `ThreadFixturesTests`, `AgentThreadApplyTests`.
- [x] Add `SystemPromptView` to `Tests/PackageStructureTests/RemovedVocabularyTests.swift`.

## Acceptance Criteria
- [x] No source uses `SystemPrompt` or the `.system` item case.
- [x] `swift test` passes.

## Tests
- [x] `RemovedVocabularyTests` fails before the removal and passes after it.
- [x] `ThreadExporterTests` passes with the changed golden file.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.