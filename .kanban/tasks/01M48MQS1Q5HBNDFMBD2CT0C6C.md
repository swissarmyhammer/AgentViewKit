---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m49mq8farp9g8fj8cxkxvspj
  text: |-
    Research done. Plan:
    - New file `Sources/AgentViewKit/Content/EntryContentView.swift`: a view that shows a list of ACP `ContentBlock` values, and a pure function that joins adjacent ACP text blocks with equal annotations. Block ids stay `<id>-<index>`.
    - `ContentBlockView` gets `init(block: FoundationModelsACP.ContentBlock, id:)`. The leaf views (`TextBlockView`, `ImageView`, `AudioPlayerView`, `LinkView`, `ResourceBlockView`, `UnknownItemView`) get ACP inputs. Base64 decode and the read of the raw `EmbeddedResourceResource` JSON occur at render time. No conversion to the kit type.
    - `ResponseView` gets an internal init with an id and a Markdown text, so `TextBlockView` makes no kit `Message`.
    - `MessageBodyView` splits into a layout that the entry path uses with no `Message`.
    - `ReasoningBlock` takes the id, the duration and a body view, so the thought path makes no `Reasoning` and no `Message`.
    Known limits until other tasks: the `messageFooter` slot takes a kit `Message`, so an entry row shows no footer until ^gve03ax. The `ContentBlockRegistry` keys the kit `ContentBlock`, so the ACP path does not use it (a new task records this). The thought entry uses no `defaultExpanded` policy (same as `ToolCallSource` for entries) until ^gve03ax.
  timestamp: 2026-10-06T22:18:06.186821+00:00
- actor: claude-code
  id: 01m49ps0p5wwp39f1t3mb96yqx
  text: |-
    Implementation landed.
    - New `Sources/AgentViewKit/Content/EntryContentView.swift`: shows the ACP blocks of an entry; `joiningAdjacentText(in:)` is the pure join over ACP blocks.
    - `ContentBlockView` has `init(block: FoundationModelsACP.ContentBlock, id:)`. `ImageView`, `AudioPlayerView`, `LinkView` have public ACP inits; `ResourceBlockView` and `UnknownItemView` have internal ACP inits. Base64 decode and the raw resource JSON read happen at render time. New `Content/Blocks/EmbeddedResource+Members.swift` reads the raw JSON members; `SessionUpdateMapping.embeddedResource` now uses it (its private key copy is gone).
    - `ResponseView` has internal `init(id:markdown:)`, so `TextBlockView` makes no kit `Message` on either path.
    - `MessageLayout` (in `MessageItemView.swift`) is the shared header and container. `TranscriptMessageView` uses it with `EntryContentView`.
    - `ReasoningBlock` is generic over its content and takes a lazy content closure. The entry path moved to `Items/ThoughtEntryBlock.swift`, so the source scan test can read it alone.
    - Old thread path keeps the kit `Message`, `Reasoning`, `ContentBlock` types only where it needs them (`MessageBodyView`, `ReasoningView` record path, `ContentBlockView` record path). ^71k836q deletes them.
    Known gaps, owned by other tasks: an entry row shows no `messageFooter` (kit `Message` slot, ^gve03ax); a thought entry has no `defaultExpanded` policy (^gve03ax); the content block registry does not apply to ACP blocks (new task ^eae86bp).
    Discovery: `SessionEntryRowsHostedTests.anAppendedErrorShowsItsData` failed one time in a filtered run (label nil after the wait) and passed in the full run. The test and `ErrorView` are not in this change; it looks unstable.
    Invalid base64 in an ACP image or audio block shows the placeholder or the failure label. Before, the kit conversion made an unknown block.
  timestamp: 2026-10-06T22:54:00.901143+00:00
- actor: claude-code
  id: 01m49ps4hc8n7gkkt2eycgm8tm
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Content/{EntryContentView.swift (new), ContentBlockView.swift, ResponseView.swift}, Sources/AgentViewKit/Content/Blocks/{TextBlockView.swift, ImageView.swift, AudioPlayerView.swift, LinkView.swift, ResourceBlockView.swift, EmbeddedResource+Members.swift (new)}, Sources/AgentViewKit/Items/{TranscriptMessageView.swift, MessageItemView.swift, ReasoningView.swift, ThoughtEntryBlock.swift (new), CompactionEntryView.swift, UnknownItemView.swift}, Sources/AgentViewKit/ACP/SessionUpdateMapping.swift; Tests: Helpers/WireBlockJSON.swift (new), Content/WireContentBlockViewHostedTests.swift (new), Content/EntryContentViewTests.swift (new), Items/MessageViewsHostedTests.swift, Items/SessionEntryRowsHostedTests.swift, Thread/SessionTranscriptViewHostedTests.swift. RED: `swift build --build-tests` failed on missing `EntryContentView`. GREEN: filtered run of the 4 suites, then `swift test`: 1349 tests in 126 suites passed, no new warnings.
    - next: /review
  timestamp: 2026-10-06T22:54:04.844273+00:00
depends_on:
- 01M48MQDWDPN98ZSWQ4N7S44FW
- 01M443P9HZRX2SYRH92DVA3ERH
position_column: doing
position_ordinal: '80'
title: Show message, thought and compaction entries from the ACP content blocks, with no kit Message, Reasoning or ContentBlock copy
---
## What
Owner rule (2026-10-06): each kit view binds directly to the observable model of FoundationModelsACPClient. The kit keeps no copy of model data. At present the entry views copy the model content into the old kit model on each body evaluation:

- `TranscriptMessageView` (`Sources/AgentViewKit/Items/TranscriptMessageView.swift`) makes a kit `Message` record and converts each `FoundationModelsACP.ContentBlock` to a kit `ContentBlock` with `SessionUpdateMapping.contentBlock`.
- `ThoughtEntryBlock` in `Sources/AgentViewKit/Items/ReasoningView.swift` makes a kit `Reasoning` record and a kit `Message`.
- `CompactionEntryView` (`Sources/AgentViewKit/Items/CompactionEntryView.swift`) converts the summary with `TranscriptMessageView.messageBlocks(of:)`.

These are new code on the bridge. The removal of the ACP adapter deletes `SessionUpdateMapping`, so this task must be done first.

- [x] Give the content views an entry point that takes `FoundationModelsACP.ContentBlock` directly (for example in `Sources/AgentViewKit/Content/ContentBlockView.swift`). The join of adjacent text chunks is a pure function over the ACP blocks of the entry.
- [x] `TranscriptMessageView` shows `AgentMessageEntry.content` and `UserMessageEntry.content` with that entry point. It makes no `Message` record and calls no `SessionUpdateMapping` function.
- [x] `ThoughtEntryBlock` shows `ThoughtEntry.content` directly. It makes no `Reasoning` and no `Message` record.
- [x] `CompactionEntryView` shows `CompactionEntry.summary` with the same entry point.

## Acceptance Criteria
- [x] A chunk that the model applies to an `AgentMessageEntry` shows in its row with no kit record between the entry and the view.
- [x] A text, an image and a resource link block of an entry show with the same look as before.
- [x] `TranscriptMessageView.swift`, `ReasoningView.swift` (entry path) and `CompactionEntryView.swift` do not use `SessionUpdateMapping`, `Message(`, `Reasoning(` or `AgentViewKit.ContentBlock`.

## Tests
- [x] `Tests/AgentViewKitTests/Items/MessageViewsHostedTests.swift`: an agent message entry with text, image and resource link blocks from the scripted agent shows each block; a second chunk changes the shown text.
- [x] `Tests/AgentViewKitTests/Items/SessionEntryRowsHostedTests.swift`: a thought entry and a compaction summary show the ACP content of the model.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.