---
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21ABXR3PMT1VCWPJK80Z9E8
- 01M21AH4QCEFEBPTZ8GR061H51
position_column: todo
position_ordinal: a780
title: SourcesView and InlineCitation from the citation payload (plan §9 C)
---
## What
Create `Sources/AgentViewKit/Citations/SourcesView.swift` and `InlineCitation.swift`, per plan.md §9 C.

- `CitationPayload` (from the catalog) carries `sources: [Source { id, title, url, snippet }]` and `references: [Reference { sourceID, range }]`.
- `SourcesView(payload:)`: a collapsible "Sources" footer under an assistant message, one `LinkView` row per source that opens in the browser.
- `InlineCitation(index:)`: a small numbered pill inside prose that scrolls to and highlights the matching source row on tap. The `ResponseView` inserts pills at the reference ranges when a message carries a citation payload.
- Register `AgentViewKit.Citation` in the `StructuredItemRegistry` default so a structured citation block renders through `SourcesView`.

## Acceptance Criteria
- [ ] A message with two sources renders a footer with two rows.
- [ ] A tap on pill 2 highlights row 2.
- [ ] An unregistered citation-like payload still falls back to `StructuredItemView`.

## Tests
- [ ] `Tests/AgentViewKitTests/Citations/SourcesViewHostedTests.swift`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.