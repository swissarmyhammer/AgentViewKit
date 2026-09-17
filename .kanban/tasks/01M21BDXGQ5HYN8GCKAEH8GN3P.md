---
comments:
- actor: claude-code
  id: 01m2nxtxeh8gxk8hghp0rtzha3
  text: 'Note from ^r061h51: `ResponseView(message:streaming:)` shows all text blocks of the message that are for the user (`ResponseView.markdown(of:)` joins them with a blank line). The `.text` case of `ContentBlockView` must not show each text block in its own `ResponseView` with the same message id: the code block cache keys (`CodeBlockID`) and the counter keys use the message id and the paragraph index, and two views with the same id collide. Show one `ResponseView` for the message, or give each block view a message id of its own, for example `<message id>-<block index>`.'
  timestamp: 2026-09-16T20:16:52.689863+00:00
depends_on:
- 01M21AH4QCEFEBPTZ8GR061H51
- 01M21AM66JDT2YAVFPWSQFHEXD
position_column: doing
position_ordinal: '8180'
title: 'ContentBlockView family: image, audio, resource link, resource, attachment, structured, unknown (plan §9 A2)'
---
## What
Create `Sources/AgentViewKit/Content/ContentBlockView.swift` and one file per block kind in `Sources/AgentViewKit/Content/Blocks/`, per plan.md §9 A2.

- `ContentBlockView(block:)`: switches over the kind and reads `ContentBlockRegistry` first. Defaults: `text` through `ResponseView`; `image` with `Image` and a tap that sets the inspector selection; `audio` through `AudioPlayerView` (AVKit); `resourceLink` through `LinkView` (`LPLinkView` card that opens the URL in the browser through `openURL`, icon from `icons` when present); `resource` as text through Textual or as `AttachmentChip` for a blob; `attachment` through `AttachmentView`; `structured` through `StructuredItemRegistry` or the `StructuredItemView` fallback; `unknown` through `UnknownItemView`.
- A block whose `annotations.audience` excludes `.user` returns `EmptyView` and is absent from the accessibility tree.
- Each default view carries an accessibility identifier `content-block-<kind>`.
- No `WKWebView` anywhere.

## Acceptance Criteria
- [ ] One mount per kind produces an element with identifier `content-block-<kind>`.
- [ ] A registered `.contentBlockView(for: .resourceLink)` replaces the default.
- [ ] A tap on the link card calls `openURL` with the link.
- [ ] An assistant-only block produces no element.

## Tests
- [ ] `Tests/AgentViewKitTests/Content/ContentBlockViewHostedTests.swift`: the four cases with the harness.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.