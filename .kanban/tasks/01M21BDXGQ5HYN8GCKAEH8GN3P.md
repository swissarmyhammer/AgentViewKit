---
depends_on:
- 01M21AH4QCEFEBPTZ8GR061H51
- 01M21AM66JDT2YAVFPWSQFHEXD
position_column: todo
position_ordinal: b480
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