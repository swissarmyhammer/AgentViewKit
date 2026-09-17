---
comments:
- actor: claude-code
  id: 01m2q3r76xbpbxy2rp44nfpn5v
  text: |-
    ### finish iteration 1 — clean

    - implement: added `ThreadChange.compact(marker:removing:)`, `CompactionMarker.removedItemIDs` / `removedKinds` / `removedCount`, the shared `ThreadItem.kindName` (the minimap uses it now), `CompactionMarkerView`, and `Docs/decisions/compaction-ux.md`. `ItemRow` shows the view. The last placeholder is gone.
    - test: `timeout 1500 swift test` exit 0. AgentViewKitTests 1180, AgentViewKitACPTests 102, AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44. Only the accepted mlx warnings.
    - commit: 405f6df (also adds the task ^fq8s8jb files).
    - review: `review sha HEAD~1..HEAD`, 0 findings (2 refuted). Moved to done.

    Note for later work: the Router `CompactionResult` has no folded entry ids, so `RouterThreadSource` does not send `compact` yet. The pinned ACP schema has no compaction messages yet. See the "Source mapping" section of the decision file.
  timestamp: 2026-09-17T07:19:30.269681+00:00
depends_on:
- 01M21AHDHY0H7A92PP2KTRTZEZ
- 01M21ABCXCQMMYMRK3QBM7CCJV
position_column: done
position_ordinal: c380
title: 'Research R17: compaction UX, encoded in CompactionMarkerView (plan §9 A2, §14)'
---
## What
Settle research R17 from plan.md §14 and create `Sources/AgentViewKit/Items/CompactionMarkerView.swift` on the decision. This view replaces the `ItemRow` placeholder for `.compaction`.

- Inputs: the Router `CompactionSegment` (`../FoundationModelsRouter/Sources/FoundationModelsRouter/Compaction/CompactionSegment.swift`), the ACP unstable `compaction_update` and `compaction_summary_chunk` (upstream RFD), and the Claude Code `/compact` presentation. Record what each carries and how the marker shows a rewrite in `Docs/decisions/compaction-ux.md`.
- `CompactionMarker` gains `removedItemIDs: [String]` and `removedKinds: [String: Int]`.
- `ThreadChange.compact(marker:, removing: [String])` removes the items and inserts the marker at the first removed index in one change.
- `CompactionMarkerView(record:)`: a divider row with the summary text, a count of removed items, a "show removed" disclosure that lists the removed kinds and counts, and a distinct row style. Accessibility identifier `compaction-marker`, label "Conversation compacted, N items summarized".

## Acceptance Criteria
- [x] `Docs/decisions/compaction-ux.md` exists.
- [x] `compact` removes the ids and inserts one marker at the first removed index.
- [x] The view mounts `compaction-marker` with the count in its label; the disclosure lists the kinds.

## Tests
- [x] `Tests/AgentViewKitTests/Model/CompactionChangeTests.swift`.
- [x] `Tests/AgentViewKitTests/Items/CompactionMarkerViewHostedTests.swift`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-17 02:14)

Scope: `review sha HEAD~1..HEAD` (commit 405f6df). 9 files reviewed. Findings: 0 (2 candidates refuted). `Docs/decisions/compaction-ux.md` has no matching validator. `.kanban/` is excluded by `.reviewignore`.

No findings. The review is clean.