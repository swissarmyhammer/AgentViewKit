---
comments:
- actor: claude-code
  id: 01m2pgtye52414gpp432190p4f
  text: |-
    ### finish iteration 1 — findings
    - implement: added TranscriptMapping and AgentTranscriptView. Moved the hostedSerially trait to AgentViewKitTestSupport, so that the hosted tests of each test target use the same lock. The check test now also scans Tests/AgentViewKitFoundationModelsTests.
    - test: swift test passed. AgentViewKitTests 995, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 14.
    - commit: 365f057
    - review: 2 findings (swift/immutability in TranscriptMapping.messageItems, code-hygiene/magic-numbers-swift in TranscriptMappingTests).
  timestamp: 2026-09-17T01:48:56.645698+00:00
- actor: claude-code
  id: 01m2ph291sgd6wf25rjrrtpgmp
  text: |-
    ### finish iteration 2 — clean
    - implement: built the tool output map, the call id set, and the message blocks and records with map and compactMap, not with loop accumulators. Removed the magic numbers from TranscriptMappingTests: items are found by id, the image is checked by decode, and the test values have names.
    - test: swift test passed. AgentViewKitTests 995, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 15.
    - commit: 04c7514
    - review: 0 new findings. All prior items checked. Task moved to done.
  timestamp: 2026-09-17T01:52:56.889402+00:00
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21ABXR3PMT1VCWPJK80Z9E8
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: done
position_ordinal: b580
title: FoundationModels transcript mapping and AgentTranscriptView snapshot renderer (plan §3.3, §3.6)
---
## What
Create `Sources/AgentViewKitFoundationModels/TranscriptMapping.swift` and `AgentTranscriptView.swift`, per plan.md §3.3 and §3.6.

- `TranscriptMapping.items(for transcript: Transcript) -> [ThreadItem]`: a pure function. `.instructions` to `.system`; `.prompt` to `.userMessage` with `.text`, `.attachment` (image), and `.structure` segments to blocks; `.response` to `.assistantMessage`; `.reasoning` to `.reasoning`; `.toolCalls` plus the paired `.toolOutput` (matched by `ToolCall.id == ToolOutput.id`) to one `.toolCall` each, status `completed` when paired and `inProgress` when not; `@unknown default` to `.unknown`.
- Use `StructuredSegment.schemaName`, not the deprecated `source`. Convert `GeneratedContent` to the kit `JSONValue` through `jsonString` and back. Decode catalog names through `StructuredCatalog`; unknown names become `.structured(StructuredRecord)`.
- `GeneratedContent` has no `properties()`; walk `kind` where needed.
- `AgentTranscriptView(transcript:)`: builds an `AgentThread` once from the mapping and hosts `AgentThreadView`. It does not update.
- Record ids are the transcript entry ids, so a later live source keeps the same identities.

## Acceptance Criteria
- [x] A transcript with instructions, a prompt with an image attachment, a reasoning entry, a tool call with output, and a response maps to five items in order with the expected kinds.
- [x] An unpaired tool call maps to `inProgress`.
- [x] A `.structure` segment with a catalog `schemaName` decodes to the typed payload; an unknown name becomes `StructuredRecord`.

## Tests
- [x] `Tests/AgentViewKitFoundationModelsTests/TranscriptMappingTests.swift`: build transcripts with the public `Transcript.Entry` initializers and assert the items.
- [x] `Tests/AgentViewKitFoundationModelsTests/AgentTranscriptViewHostedTests.swift`: mount and count rows through accessibility.
- [x] `swift test --filter AgentViewKitFoundationModelsTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 20:43)

> Scope: `review sha HEAD~1..HEAD` (365f057).

- [x] `Sources/AgentViewKitFoundationModels/TranscriptMapping.swift:146` `swift/immutability` — Collections are built using mutable `var` accumulators in a loop; should use `map`/`compactMap` instead. A reader must walk every line of the loop body to understand what enters each collection. Refactor to build `blocks` and `records` using functional operations (`map`, `compactMap`, or similar) so the collection-building logic is declarative at the call site, not hidden inside a loop.
- [x] `Tests/AgentViewKitFoundationModelsTests/TranscriptMappingTests.swift:65` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.

## Review Findings (2026-09-16 20:50)

> Scope: `review sha HEAD~1..HEAD` (04c7514). No new findings.