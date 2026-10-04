---
assignees:
- claude-code
depends_on:
- 01M443K9H9357ZZAZQE6SD6TV0
position_column: todo
position_ordinal: 8d80
title: 'Remove the system prompt item: .system, SystemPrompt and SystemPromptView'
---
## What
Only `TranscriptMapping` (FoundationModels) made a system prompt item. ACP has no system prompt update (update.md §6).

- [ ] Delete `Sources/AgentViewKit/Model/SystemPrompt.swift` and `Sources/AgentViewKit/Items/SystemPromptView.swift`.
- [ ] Remove `.system` from `ThreadItem`, `ItemPatch` and `AgentThread`, and its cases from `ItemRow.swift`, `ItemViewOverrides.swift`, `ThreadMinimapView.swift`, `ThreadExporter.swift`, `MessageActions.swift` and `AgentCommandTarget.swift`.
- [ ] Change the tests that use `.system`: `MessageViewsHostedTests`, `ThreadItemTests`, `ThreadExporterTests` (and its golden file in `Tests/AgentViewKitTests/Items/Fixtures`), `ThreadFixturesTests`, `AgentThreadApplyTests`.
- [ ] Add `SystemPromptView` to `Tests/PackageStructureTests/RemovedVocabularyTests.swift`.

## Acceptance Criteria
- [ ] No source uses `SystemPrompt` or the `.system` item case.
- [ ] `swift test` passes.

## Tests
- [ ] `RemovedVocabularyTests` fails before the removal and passes after it.
- [ ] `ThreadExporterTests` passes with the changed golden file.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.