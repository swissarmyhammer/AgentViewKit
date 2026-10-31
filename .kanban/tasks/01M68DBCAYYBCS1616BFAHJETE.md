---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
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