---
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21ABCXCQMMYMRK3QBM7CCJV
position_column: todo
position_ordinal: c080
title: 'Research R17: compaction UX, encoded in CompactionMarkerView (plan §9 A2, §14)'
---
## What
Settle research R17 from plan.md §14 and create `Sources/AgentViewKit/Items/CompactionMarkerView.swift` on the decision. This view replaces the `ItemRow` placeholder for `.compaction`.

- Inputs: the Router `CompactionSegment` (`../FoundationModelsRouter/Sources/FoundationModelsRouter/Compaction/CompactionSegment.swift`), the ACP unstable `compaction_update` and `compaction_summary_chunk` (upstream RFD), and the Claude Code `/compact` presentation. Record what each carries and how the marker shows a rewrite in `Docs/decisions/compaction-ux.md`.
- `CompactionMarker` gains `removedItemIDs: [String]` and `removedKinds: [String: Int]`.
- `ThreadChange.compact(marker:, removing: [String])` removes the items and inserts the marker at the first removed index in one change.
- `CompactionMarkerView(record:)`: a divider row with the summary text, a count of removed items, a "show removed" disclosure that lists the removed kinds and counts, and a distinct row style. Accessibility identifier `compaction-marker`, label "Conversation compacted, N items summarized".

## Acceptance Criteria
- [ ] `Docs/decisions/compaction-ux.md` exists.
- [ ] `compact` removes the ids and inserts one marker at the first removed index.
- [ ] The view mounts `compaction-marker` with the count in its label; the disclosure lists the kinds.

## Tests
- [ ] `Tests/AgentViewKitTests/Model/CompactionChangeTests.swift`.
- [ ] `Tests/AgentViewKitTests/Items/CompactionMarkerViewHostedTests.swift`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.