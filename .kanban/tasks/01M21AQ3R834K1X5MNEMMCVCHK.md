---
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21ABXR3PMT1VCWPJK80Z9E8
- 01M21AH4QCEFEBPTZ8GR061H51
position_column: doing
position_ordinal: '8180'
title: SourcesView and InlineCitation from the citation payload (plan §9 C)
---
## What
Create `Sources/AgentViewKit/Citations/SourcesView.swift` and `InlineCitation.swift`, per plan.md §9 C.

- `CitationPayload` (from the catalog) carries `sources: [Source { id, title, url, snippet }]` and `references: [Reference { sourceID, range }]`.
- `SourcesView(payload:)`: a collapsible "Sources" footer under an assistant message, one `LinkView` row per source that opens in the browser.
- `InlineCitation(index:)`: a small numbered pill inside prose that scrolls to and highlights the matching source row on tap. The `ResponseView` inserts pills at the reference ranges when a message carries a citation payload.
- Register `AgentViewKit.Citation` in the `StructuredItemRegistry` default so a structured citation block renders through `SourcesView`.

## Decisions
- The real catalog payload is `CitationPayload { sources, markers }`. A `CitationMarker` has `sourceID`, `paragraphIndex`, and `offset`. The pills use these fields. The paragraph index counts the paragraphs of `ResponseView.markdown(of:)`.
- The registered schema name is `CitationPayload.schemaName` (`AgentViewKit.CitationPayload`). `StructuredItemRegistry.standard` is the new environment default.
- `InlineCitation(index:)` takes the one-based source number. Textual draws the pill in the prose as an attachment with the link `agentviewkit-citation:<n>`. `.citationScope()` gets the link and sets a `CitationSelection`. `MessageItemView` applies the scope.
- `SourcesView` is open by default. A pill opens it, highlights the row, and scrolls the row into view through AppKit `scrollToVisible`.
- A message with a citation block shows its text in one `ResponseView`, and the citation block shows below the other blocks.

## Acceptance Criteria
- [x] A message with two sources renders a footer with two rows.
- [x] A tap on pill 2 highlights row 2.
- [x] An unregistered citation-like payload still falls back to `StructuredItemView`.

## Tests
- [x] `Tests/AgentViewKitTests/Citations/SourcesViewHostedTests.swift`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.