---
assignees:
- claude-code
depends_on:
- 01M443KJWH20B6MFWXZWFXQJ6G
position_column: todo
position_ordinal: '8e80'
title: Remove the structured item and the schemaName catalog
---
## What
Only the Router and FoundationModels sources made `.structured` items. The catalog was the schema name agreement with the Router (update.md §6).

- [ ] Delete `Sources/AgentViewKit/Model/StructuredRecord.swift`, `Sources/AgentViewKit/Items/StructuredItemView.swift`, `Catalog/StructuredCatalog.swift`, `Catalog/StructuredPayload.swift`, `Catalog/catalog.md`, and the payloads that only the catalog uses (`ApprovalPayload`, `ArtifactPayload`, `PlanPayload`, `UsagePayload`, `AuthorizationPayload`). The authorization payload has its own task; do not delete it here if that task is not done.
- [ ] `CitationPayload` is the input of `SourcesView`, `InlineCitation` and `CitationProse`. Keep it: move it to `Sources/AgentViewKit/Citations/`.
- [ ] Remove `.structured` from `ThreadItem`, `ItemPatch`, `AgentThread` and the `.structured` content block from `ContentBlock`. Remove the structured registry from `Thread/Registries.swift` and its cases from `ItemRow`, `ItemViewOverrides`, `ThreadMinimapView` and `ContentBlockView`. Remove `exclude: ["Catalog/catalog.md"]` from `Package.swift`.
- [ ] Delete `Tests/AgentViewKitTests/Catalog/`. Change `StructuredAndUnknownItemViewHostedTests` (keep the unknown part), `RegistryResolutionTests`, `ContentBlockViewHostedTests`, `ContentBlockTests`, `SourcesViewHostedTests` and `CitationProseTests`.
- [ ] Add `StructuredRecord`, `StructuredCatalog` and `StructuredItemView` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [ ] No source uses `StructuredRecord`, `StructuredCatalog` or the `.structured` cases.
- [ ] The citation views still compile and their tests pass.
- [ ] `swift test` passes.

## Tests
- [ ] `RemovedVocabularyTests` fails before the removal and passes after it.
- [ ] `SourcesViewHostedTests` and `CitationProseTests` pass.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.