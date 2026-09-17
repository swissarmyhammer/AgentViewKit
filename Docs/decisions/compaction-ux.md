# Compaction UX

Status: decided. Source: plan.md §9 A2, §14 research R17.
Task ^5vec7bq. Date: 2026-09-17.

This file records how the kit shows a compaction: the point where a source
rewrote the thread to make it shorter.

## Inputs

### Router `CompactionSegment`

File: `../FoundationModelsRouter/Sources/FoundationModelsRouter/Compaction/CompactionSegment.swift`.

- The segment is `package`. It travels as a `Transcript.StructuredSegment`
  with the schema name `FoundationModelsRouter.CompactionSegment`.
- Its content has these fields: `liveWindowEntryIds`, `foldedEntryIds`,
  `tokensBefore`, `tokensAfter`, `stagesApplied`, `promptName`, and
  `pendingRuns` (optional).
- A fold appends one boundary entry: a `.response` with a text segment for
  the summary (`<entryId>-text`), an optional pending-runs text segment
  (`<entryId>-pending-runs`), and the `.structure` manifest.
- A deterministic fold has an empty summary and an empty `promptName`.
- The folded entries stay in the recorded transcript. They leave only the
  live window.
- The public event is `SessionEvent.compaction(CompactionResult)`. The result
  has `id`, `summary`, `summaryEntryId`, `summarizerModel`, `tokensBefore`,
  `tokensAfter`, `stagesApplied`, and `summaryCut`. It does not have the
  folded entry ids. `SessionEventMapping.compactionChange(_:)` puts the token
  counts, the stages, and `summaryCut` in the `meta` value of the marker.

### ACP `compaction_update` and `compaction_summary_chunk`

Source: the upstream draft RFD "Session Compaction"
(<https://agentclientprotocol.com/rfds/session-compaction.md>, dated
2026-07-22). The pinned schema in `../FoundationModelsACP/Schema` does not
have these messages yet.

- `compaction_update`: `compactionId` (agent-owned), `status`
  (`in_progress`, then one of `completed`, `failed`, `cancelled`), `summary`
  (`ContentBlock[]`, optional), `error` (string, optional), and `_meta`.
- `compaction_summary_chunk`: `compactionId`, `content` (one
  `ContentBlock`), and `_meta`. The chunks add to the summary in order. A
  terminal `compaction_update` can replace the summary.
- The client declares support with `session.compaction` in its session
  capabilities.
- The RFD says that the client can show an in-progress indicator, and
  replace it with the terminal state. The RFD does not remove items from the
  display. The compaction is a boundary in the history.

### Claude Code `/compact`

- Claude Code writes one divider line, "Conversation compacted", at the
  boundary. It gives a key to open the full earlier transcript.
- The summary is not shown by default. The user can open it.
- The earlier messages leave the model context. The user can still read
  them in the transcript view.

## Decision

- The marker is one row of the thread, `.compaction(CompactionMarker)`, at
  the position of the first removed item.
- `ThreadChange.compact(marker:removing:)` removes the items and puts the
  marker in their place in one write to `AgentThread.items`. Thus a list
  view sees one change and not one change for each removed item.
- The change writes `CompactionMarker.removedItemIDs` (thread order) and
  `CompactionMarker.removedKinds` (count for each `ThreadItem.kindName`) from
  the items that it removed. A source does not have to know the kinds.
- Unknown ids change nothing. With no known id, the marker goes at the end.
  An item with the id of the marker is replaced, and the marker gets that
  revision plus one. Thus a source can first patch a marker (for example on
  an ACP `in_progress` update) and then compact with the same id.
- `CompactionMarkerView(record:)` shows:
  - the title "Conversation compacted" between two rules, with an icon and
    the text "N items summarized";
  - the summary text, when the marker has one;
  - a "Show removed" button that opens a list of the removed kinds with
    their counts, when the marker has removed items;
  - a tinted, rounded background, so that the row looks different from a
    message.
- Accessibility: the row is a container with the identifier
  `compaction-marker` and the label "Conversation compacted, N items
  summarized". The button is `compaction-marker-toggle`. The list is
  `compaction-marker-removed`. Each kind line is
  `compaction-marker-kind-<kind>`. The summary is
  `compaction-marker-summary`.
- The list is closed by default. The state is in the `ExpandedBlocksStore`
  of the environment, keyed by the marker id.
- The kit does not keep the removed records. A host that must show the
  removed items keeps them itself, keyed by `removedItemIDs`. This agrees
  with the ACP RFD and with Claude Code, where the full transcript stays
  with the agent.

## Source mapping

- Router: `SessionEventMapping` makes a marker with a patch. The public
  `CompactionResult` has no folded ids, so the Router source does not send
  `compact` yet. When the Router makes the folded ids public, the source
  sends `compact(marker:removing:)` with them.
- ACP: when the schema has the RFD messages, `ACPThreadSource` maps
  `compaction_update` to a marker patch (summary and `meta`), and each
  `compaction_summary_chunk` to a marker patch with the summary text so far.
  The streaming table does not apply, because
  `ThreadChange.closeStreaming(id:)` writes no text to a marker. The RFD
  does not give removed ids, so the ACP source does not remove items. A
  `session/resume` replay gives the rewritten history.
- A host with its own source can send `compact(marker:removing:)` directly.
