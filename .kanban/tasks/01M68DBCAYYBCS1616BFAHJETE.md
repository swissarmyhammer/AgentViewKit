---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m68f8e4wx7nfvq7w0z26e9ac
  text: 'Picked up in worktree AgentViewKit-wt/shared-style (branch wt/shared-style, off main bb6995c). Research: read the sibling sources named on the card (SVK TimelineStreamBanner*, CheckpointRowSlot, CheckpointFileRow/Content, ChangesInspectorActions; KVK BoardStreamBanner, BoardNoticeBanner, StatusBarAction+BoardDismiss, BoardTagFlowLayout, BoardFieldCompletion, BoardSurfaces), AVK adopters (AttachmentActions, SessionStreamBanner, NoticeRow, PromptCompletionRow, DiffFileChip), style.md. Findings: makeDismiss has a settable button identifier but icon-only comes from .labelStyle(.iconOnly) on NoticeRow, not from the action, and the bar has no identifier of its own: both need work in the shared piece. No AVK source paints a change highlight, so piece 7 has no AVK adopter. A `reload(identifier:isEnabled:perform:)` with only those three labels has nowhere to record a thrown error, so a defaulted `phase:` binding carries the failure to the host''s ReloadPhase.'
  timestamp: 2026-10-31T07:54:46.812461+00:00
- actor: claude-code
  id: 01m68hc1c731n3sx4rwtd8zw89
  text: |-
    ### implement — changed
    - evidence: 9 commits on wt/shared-style: 35dc2a1 InspectorActionRow, 0b88105 stream banner shape + ReloadPhase + Action.reload + bar identifier, 5203c5a dismiss icon-only, 172a3ea ChipFlowLayout re-measure, 6a0da88 DiffFileLabel + .binary, a7250fd CompletionRow, a83f3a0 changeHighlightEdge, ea5c159 docs, b91ff10 composer test. Root swift test 833 + 62 passed, no own warnings; integration build clean; hosted suites passed (1 list-frame expectation updated for the moved margin).
    - discoveries: the list accessibility frame is the union of its rows, so moving the inset to scrollContentMargins moves that frame spacing.xs past the caret; the rows themselves did not move. The margin also adds spacing.xs above and below the rows.
    - slip: AttachmentInspectorFormHostedTests contains one capture test (theBackdropOfTheHostShowsInTheMarginOfTheForm) and was run against the no-capture instruction; it passed. Rerun nothing.
    - not done: the optional inspector form shell of piece 1; SVK candidates (diff configuration, note label, SharedSymbol.closed, chevron). No AVK adopter exists for changeHighlightEdge. Main SHA not sent to the siblings: not merged yet.
    - next: /review
  timestamp: 2026-10-31T08:31:41.959887+00:00
position_column: done
position_ordinal: ffffff8980
title: 'Shared moves into AgentViewKitStyle for KanbanViewKit and SnapshotViewKit: action row, stream banner, dismiss, ChipFlowLayout, file label, completion row, highlight edge'
---
Agreed with KVK and SVK (EditorKit asked AVK, as owner of AgentViewKitStyle, to take these). Starts on top of the style-fixes branch, because that branch folds NoticeRow into StatusBar.

1. **InspectorActionRow { content }:** plain ViewBuilder container with no knowledge of commands. It supplies the ControlStack(.horizontal) theme gap, .labelStyle(.iconOnly), .buttonStyle(.borderless) and secondary symbols, and takes no host tint (add `.tint(nil)` and `.foregroundStyle(.secondary)`, per style.md "Tint"). AttachmentActions adopts it. Replaces the layout of KVK Board/BoardInspectorActions.swift and SVK Inspector/ChangesInspectorActions.swift. Optional for SVK: the inspector form shell, name row and previewHeight, written three times (SVK ChangesInspector.swift:41,94-112, AVK AttachmentInspector.swift:192,207-225, KVK BoardInspectorContent.swift:42-47).
2. **Stream banner shape:** pure inputs (stream current / ended clean / ended with error message) plus ReloadPhase (idle, reloading, failed(message)). Output: title, explanation, severity, symbol. Start from SVK TimelineStreamBannerContent. No model types. Strings are supplied by the kit or localised in the shared type. Add `StatusBar.Action.reload(identifier:isEnabled:perform:)` taking an async throwing closure, with one Reload title, hint and symbol, disabled while reloading or loading. StatusBar gets a bar-level accessibility identifier. Must keep working: several bars in a ControlStack, a neutral bar with no action, a failure bar with no action. Tell SVK whether Reload should be a control scope and jump target as in AgentStatusBarActionStyle.
3. **Dismissible StatusBar case:** settable identifier on the button and the bar, no outer padding, icon-only (AVK's look wins). Replaces KVK Board/StatusBarAction+BoardDismiss.swift and possibly BoardNoticeBanner.swift.
4. **ChipFlowLayout:** add KVK's re-measure of a chip wider than the row at the row width, so it gets its own line and the correct height (KVK `chipSize(of:in:)`). KVK then deletes Tags/BoardTagFlowLayout.swift. SVK doesn't use it.
5. **DiffFileLabel:** public, holds exactly the HStack at DiffFileChip.swift:166-180 (symbol at symbolWeight, secondary, middle-truncated name, +n/−n in diffAddedText/diffRemovedText, ui caption font, monospacedDigit). DiffFileChip wraps it. Add `.binary` to DiffSummary.Operation (SharedSymbol.binary, no counts). The public change-kind symbol map stays the only one. SVK deletes CheckpointFileContent.symbolName(of:) and adopts it in Files/CheckpointFileRow.swift.
6. **Completion row in AgentViewKitStyle:** label, optional detail, isSelected, identifier. From AVK PromptCompletionRow and KVK Editing/BoardFieldCompletion.swift. Note that AVK adds an outer spacing.xs row inset; that belongs to the list (rule 10).
7. **Change-highlight edge:** one modifier taking a radius and whether it's showing. From SVK CheckpointRowSlot.swift:202,226-231 and KVK Theme/BoardSurfaces.swift:69,117.

SVK also lists as candidates: the diff configuration and note label in EditorKitDiffRenderer, SharedSymbol.closed and the chevron.

Send the main SHA to kanbanviewkit and snapshotviewkit when this lands. #cross-repo