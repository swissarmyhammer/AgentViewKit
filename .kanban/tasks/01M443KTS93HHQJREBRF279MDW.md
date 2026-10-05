---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m469hgrr1qfy1dwczxd15tvf
  text: |-
    Research results:
    - A message gets its citations only from a `.structured` content block. `ResponseView` reads the block for the pills in the text (`CitationPayload.first(in:)`). `MessageItemView` reads it for the Sources footer and the block order (`isCitation`). After the removal, a message has no citation data.
    - Decision (the owner said "make the best decision"): add an optional `citations: CitationPayload?` parameter to `ResponseView` (default `nil`). The pills in the text stay. `MessageItemView` shows no citations, because ACP has no citation source. A host puts `SourcesView(payload:)` in its own layout. `isCitation` and `first(in:)` go.
    - `ArtifactPayload` is not "only used by the catalog": `ArtifactView` (a README Components item) uses it. Thus keep it, remove the `StructuredPayload` conformance, and move it to `Sources/AgentViewKit/Attachments/`.
    - `AuthorizationPayload`: task ^gaj4j75b (depends on this task) is not done. Keep the file in `Catalog/`, and remove only the `StructuredPayload` conformance.
    - `StructuredItemContent`, `StructuredItemRegistry`, `structuredItemRegistry`, `.structuredItem(_:_:)`, `RegisteredStructuredView`, `structuredItemView`/`structuredItemViewOverride` and the citation registry in `SourcesView` are the structured registry. They go.
    - The README modifier table and `Examples/ReadmeSnippets/Snippets/HostApp.swift` use `.structuredItem` and `.structuredItemView`. They change too.
  timestamp: 2026-10-05T15:05:00.440921+00:00
- actor: claude-code
  id: 01m46a1xx4hmpeeavtkmnhkryw
  text: |-
    Implementation done.
    - Correction to the first comment: the short id of the authorization task is ^aj4j75b, not ^gaj4j75b.
    - RED: `RemovedVocabularyTests.sourcesUseNoRemovedSymbol` failed with the new names (StructuredRecord, StructuredCatalog, StructuredPayload, StructuredItemView, StructuredItemContent, StructuredItemRegistry, RegisteredStructuredView, structuredItem, structuredItemRegistry, structuredItemView, structuredItemViewOverride, ApprovalPayload, PlanPayload, UsagePayload). The `SourcesViewHostedTests` change that uses `ResponseView(message:streaming:citations:)` did not compile before the change. GREEN after the removal.
    - `ResponseView` has a new optional `citations: CitationPayload?` parameter (default `nil`). `MessageItemView` has no citation path and no `citationScope()` now.
    - `ArtifactPayload` moved to `Attachments/` (ArtifactView uses it). `AuthorizationPayload` stays in `Catalog/` without the `StructuredPayload` conformance, for ^aj4j75b.
    - Also changed, because the removed cases broke them: `ThreadExporter` (no structured sections), `ThreadExporterTests` and its golden file, `ThreadItemTests`, `AgentThreadApplyTests`, `ThreadFixturesTests`, `MessageActions`, `AgentCommandTarget`, `JSONValue` doc, the README override tables and the `HostApp` snippet.
    - `StructuredAndUnknownItemViewHostedTests` is now `UnknownItemViewHostedTests` (unknown part kept, plus a collapsed test and the store test on `UnknownItemView`).
    - `RegistryResolutionTests`: the last-writer-wins test now uses the content block registry.
    - The README Components list still has `StructuredItemView` and the "structured" block kind, because plan.md §9 must match it (ReadmeCoverageTests). Task ^g95wwbs removes these lines. plan.md and update.md still name the catalog; that is also for ^g95wwbs.

    ### implement — changed
    - evidence: `swift test` (1168 tests; 2 count failures in ThreadItemTests fixed, then `swift test --filter ThreadItemTests` passed), `swift test --filter 'RemovedVocabularyTests|SourcesViewHostedTests|CitationProseTests'` passed, `Scripts/check-readme.sh` passed, `Scripts/test-examples.sh AgentViewKitDemo` passed (TEST SUCCEEDED). No warnings.
    - next: /review
  timestamp: 2026-10-05T15:13:58.180747+00:00
- actor: claude-code
  id: 01m46ag3zqd24pqdpe8bjxege2
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit fff2032). 48 files reviewed, 0 findings, 0 confirmed, 0 refuted, 21 validator runs, 0 failed. Some code-hygiene Swift rules did not examine 12 files, because the commit deleted those files.
    - next: the task is in done.
  timestamp: 2026-10-05T15:21:43.159024+00:00
- actor: claude-code
  id: 01m46ag5efxpqjpcek5nydcnxq
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — removed the structured item, StructuredItemView, the structured registry and the schemaName catalog; moved CitationPayload and ArtifactPayload; ResponseView citations parameter; 53 files
    - test: green — swift test, 1362 passed; README and demo UI gates passed
    - commit: fff2032
    - review: clean — 0 findings
  timestamp: 2026-10-05T15:21:44.655160+00:00
depends_on:
- 01M443KJWH20B6MFWXZWFXQJ6G
position_column: done
position_ordinal: dd80
title: Remove the structured item and the schemaName catalog
---
## What
Only the Router and FoundationModels sources made `.structured` items. The catalog was the schema name agreement with the Router (update.md §6).

- [x] Delete `Sources/AgentViewKit/Model/StructuredRecord.swift`, `Sources/AgentViewKit/Items/StructuredItemView.swift`, `Catalog/StructuredCatalog.swift`, `Catalog/StructuredPayload.swift`, `Catalog/catalog.md`, and the payloads that only the catalog uses (`ApprovalPayload`, `ArtifactPayload`, `PlanPayload`, `UsagePayload`, `AuthorizationPayload`). The authorization payload has its own task; do not delete it here if that task is not done.
- [x] `CitationPayload` is the input of `SourcesView`, `InlineCitation` and `CitationProse`. Keep it: move it to `Sources/AgentViewKit/Citations/`.
- [x] Remove `.structured` from `ThreadItem`, `ItemPatch`, `AgentThread` and the `.structured` content block from `ContentBlock`. Remove the structured registry from `Thread/Registries.swift` and its cases from `ItemRow`, `ItemViewOverrides`, `ThreadMinimapView` and `ContentBlockView`. Remove `exclude: ["Catalog/catalog.md"]` from `Package.swift`.
- [x] Delete `Tests/AgentViewKitTests/Catalog/`. Change `StructuredAndUnknownItemViewHostedTests` (keep the unknown part), `RegistryResolutionTests`, `ContentBlockViewHostedTests`, `ContentBlockTests`, `SourcesViewHostedTests` and `CitationProseTests`.
- [x] Add `StructuredRecord`, `StructuredCatalog` and `StructuredItemView` to `RemovedVocabularyTests`.

## Acceptance Criteria
- [x] No source uses `StructuredRecord`, `StructuredCatalog` or the `.structured` cases.
- [x] The citation views still compile and their tests pass.
- [x] `swift test` passes.

## Tests
- [x] `RemovedVocabularyTests` fails before the removal and passes after it.
- [x] `SourcesViewHostedTests` and `CitationProseTests` pass.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.