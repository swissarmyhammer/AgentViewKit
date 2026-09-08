---
depends_on:
- 01M21ABCXCQMMYMRK3QBM7CCJV
- 01M21ABXR3PMT1VCWPJK80Z9E8
- 01M21AEPX6A1KRH0TQ0D4QV9CP
position_column: todo
position_ordinal: 8c80
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
- [ ] A transcript with instructions, a prompt with an image attachment, a reasoning entry, a tool call with output, and a response maps to five items in order with the expected kinds.
- [ ] An unpaired tool call maps to `inProgress`.
- [ ] A `.structure` segment with a catalog `schemaName` decodes to the typed payload; an unknown name becomes `StructuredRecord`.

## Tests
- [ ] `Tests/AgentViewKitFoundationModelsTests/TranscriptMappingTests.swift`: build transcripts with the public `Transcript.Entry` initializers and assert the items.
- [ ] `Tests/AgentViewKitFoundationModelsTests/AgentTranscriptViewHostedTests.swift`: mount and count rows through accessibility.
- [ ] `swift test --filter AgentViewKitFoundationModelsTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.