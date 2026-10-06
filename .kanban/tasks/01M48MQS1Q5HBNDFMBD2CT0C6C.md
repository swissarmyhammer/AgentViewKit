---
assignees:
- claude-code
depends_on:
- 01M48MQDWDPN98ZSWQ4N7S44FW
- 01M443P9HZRX2SYRH92DVA3ERH
position_column: todo
position_ordinal: aa80
title: Show message, thought and compaction entries from the ACP content blocks, with no kit Message, Reasoning or ContentBlock copy
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. The kit keeps no copy of model data. At present the entry views copy the model content into the old kit model on each body evaluation:

- `TranscriptMessageView` (`Sources/AgentViewKit/Items/TranscriptMessageView.swift`) makes a kit `Message` record and converts each `FoundationModelsACP.ContentBlock` to a kit `ContentBlock` with `SessionUpdateMapping.contentBlock`.
- `ThoughtEntryBlock` in `Sources/AgentViewKit/Items/ReasoningView.swift` makes a kit `Reasoning` record and a kit `Message`.
- `CompactionEntryView` (`Sources/AgentViewKit/Items/CompactionEntryView.swift`) converts the summary with `TranscriptMessageView.messageBlocks(of:)`.

These are new code on the bridge. The removal of the ACP adapter deletes `SessionUpdateMapping`, so this task must be done first.

- [ ] Give the content views an entry point that takes `FoundationModelsACP.ContentBlock` directly (for example in `Sources/AgentViewKit/Content/ContentBlockView.swift`). The join of adjacent text chunks is a pure function over the ACP blocks of the entry.
- [ ] `TranscriptMessageView` shows `AgentMessageEntry.content` and `UserMessageEntry.content` with that entry point. It makes no `Message` record and calls no `SessionUpdateMapping` function.
- [ ] `ThoughtEntryBlock` shows `ThoughtEntry.content` directly. It makes no `Reasoning` and no `Message` record.
- [ ] `CompactionEntryView` shows `CompactionEntry.summary` with the same entry point.

## Acceptance Criteria
- [ ] A chunk that the model applies to an `AgentMessageEntry` shows in its row with no kit record between the entry and the view.
- [ ] A text, an image and a resource link block of an entry show with the same look as before.
- [ ] `TranscriptMessageView.swift`, `ReasoningView.swift` (entry path) and `CompactionEntryView.swift` do not use `SessionUpdateMapping`, `Message(`, `Reasoning(` or `AgentViewKit.ContentBlock`.

## Tests
- [ ] `Tests/AgentViewKitTests/Items/MessageViewsHostedTests.swift`: an agent message entry with text, image and resource link blocks from the scripted agent shows each block; a second chunk changes the shown text.
- [ ] `Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift`: a thought entry and a compaction summary show the ACP content of the model.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.