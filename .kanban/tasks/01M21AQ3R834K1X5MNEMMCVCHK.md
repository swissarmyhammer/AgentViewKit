---
comments:
- actor: claude-code
  id: 01m2q5hnyw1eqfkk3atyjk7bze
  text: |-
    ### finish iteration 1 — findings
    - implement: added SourcesView, InlineCitation, CitationSelection, citationScope(), the citation prose parser, and StructuredItemRegistry.standard. ResponseView and MessageItemView show the pills and the footer.
    - test: `timeout 1500 swift test` passed. AgentViewKitTests 1211, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44. `Scripts/check-benchmarks.sh` passed.
    - commit: 623cd33 feat(citations): add SourcesView and InlineCitation (^mmcvchk)
    - review: `review sha HEAD~1..HEAD` gave 9 findings (swift/immutability x5, reuse/reuse x1, duplication/duplication x1, code-hygiene/magic-numbers-swift x2). The task goes back to implement.
  timestamp: 2026-09-17T07:50:53.148911+00:00
- actor: claude-code
  id: 01m2q60qdb7kpkpzfc1hfpqphk
  text: |-
    ### finish iteration 2 — clean
    - implement: fixed all 9 findings. Added `TextMarker` (Sources/AgentViewKit/Content/TextMarker.swift) as the shared marker split and run rewrite of MathMarkdownParser and CitationMarkdownParser. Removed the mutable accumulators in CitationProse.swift. Named the padding side count in InlineCitationMetrics.
    - test: `timeout 1500 swift test` passed. AgentViewKitTests 1212, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44. `Scripts/check-benchmarks.sh` passed.
    - commit: c81f260 refactor(citations): share the marker split with the math parser (^mmcvchk)
    - review: `review sha HEAD~1..HEAD` gave 0 findings. All prior items are checked. The task goes to done.
  timestamp: 2026-09-17T07:59:06.155215+00:00
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21ABXR3PMT1VCWPJK80Z9E8
- 01M21AH4QCEFEBPTZ8GR061H51
position_column: done
position_ordinal: c580
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
- `TextMarker` (Sources/AgentViewKit/Content/TextMarker.swift) is the shared marker split and run rewrite of `MathMarkdownParser` and `CitationMarkdownParser`.

## Acceptance Criteria
- [x] A message with two sources renders a footer with two rows.
- [x] A tap on pill 2 highlights row 2.
- [x] An unregistered citation-like payload still falls back to `StructuredItemView`.

## Tests
- [x] `Tests/AgentViewKitTests/Citations/SourcesViewHostedTests.swift`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-17 02:42)

> Scope: `review sha HEAD~1..HEAD` (commit 623cd33). 11 files reviewed. 2 `.kanban/` files not reviewed (ignore rule).

- [x] `Sources/AgentViewKit/Citations/CitationProse.swift:48` `swift/immutability` — Building a collection with a `var` accumulator pattern. Dictionary is assigned to in a loop—use functional collection methods instead of mutating a variable. Refactor to use `reduce(into:)` or collect into a dictionary without a mutable variable.
- [x] `Sources/AgentViewKit/Citations/CitationProse.swift:52` `swift/immutability` — Building a collection with a `var` accumulator pattern. Use `reduce` or collect values functionally instead of mutating a variable in a loop. Refactor to use `Dictionary(grouping:by:)` or `reduce(into:)` to build the result without a mutable variable.
- [x] `Sources/AgentViewKit/Citations/CitationProse.swift:114` `swift/immutability` — Building a collection with a `var` accumulator pattern. Accumulating a string by repeated `+=` in a loop requires the reader to trace the entire loop body to understand the final value. Refactor to build the output string using `reduce` with tuple state tracking position and consumed bytes, or use a String builder approach.
- [x] `Sources/AgentViewKit/Citations/CitationProse.swift:133` `reuse/reuse` — CitationMarkers.parts() reimplements the marker-splitting algorithm that already exists in MathMarkdownParser.markerParts(). Both iterate through text, find paired start/end marker characters, extract indices, and split text at those boundaries. This should reuse or generalize the existing capability rather than duplicate the algorithm. Generalize marker-splitting into a shared utility function parameterized by marker characters, or have CitationMarkers.parts() delegate to a generalized version of the MathMarkdownParser logic that accepts custom start/end characters.
- [x] `Sources/AgentViewKit/Citations/CitationProse.swift:134` `swift/immutability` — Building a collection with a `var` accumulator pattern. Accumulating an array by `append` in a loop should use functional collection methods instead. Refactor to use `reduce(into:)` or a functional approach to collect parts without a mutable variable.
- [x] `Sources/AgentViewKit/Citations/CitationProse.swift:136` `swift/immutability` — Building a collection with a `var` accumulator pattern. Accumulating a string by repeated `+=` in a loop should use functional collection methods. Refactor to accumulate plain text parts without a mutable string variable; consider collecting substrings and joining them once.
- [x] `Sources/AgentViewKit/Citations/CitationProse.swift:186` `duplication/duplication` — Attributed-string run processing duplicates MathMarkdownParser.attributedString (0.95 similarity). Both iterate parsed runs, check for markers, skip code blocks, split into parts, and rebuild with attachments. Differences are only marker characters and attachment factories — this is one function with arguments. Extract a shared parameterized processor accepting marker-checking and attachment-building closures, so the run-iteration loop and code-block logic are maintained in one place and cannot diverge.
- [x] `Sources/AgentViewKit/Citations/InlineCitation.swift:217` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Citations/InlineCitation.swift:218` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.

## Review Findings (2026-09-17 02:56)

> Scope: `review sha HEAD~1..HEAD` (commit c81f260). 5 files reviewed. 2 `.kanban/` files not reviewed (ignore rule).

No findings. All prior items are checked.