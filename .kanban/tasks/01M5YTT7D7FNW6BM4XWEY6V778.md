---
assignees:
- claude-code
position_column: todo
position_ordinal: a480
title: 'AVK-8 shell output: give terminal output the same padding as its header row, so it no longer looks cramped (user review of the gallery)'
---
## Why

The user's review of the review gallery (2026-10-27), verbatim: "the shell command outputs do not have enough padding and look cramped. be consistent with the padding in the header area".

Screens: `~/Library/Caches/AgentViewKit/screenshot-check/thread--light.png` and `thread--dark.png` (the terminal output in the thread). Regenerate them with `swift test --filter ReviewGallery`.

## What to do

- [ ] Find the view that draws shell command (terminal) output in the transcript. Start from `ToolCallPart.terminal(id:)` (`Sources/AgentViewKit/Items/ToolCallPart.swift:56`) and its view in `Sources/AgentViewKit/Items/ToolCallView.swift`, plus any EditorKit terminal view it hosts. Find the header row above it: its title or command row, and the padding that row uses (EditorStyle spacing tokens).
- [ ] Give the output body the same horizontal inset as the header, so the output text starts on the header text's leading edge, and the same vertical inset above and below the output. Use the same EditorStyle spacing tokens the header uses. No literal numbers.
- [ ] Use one shared definition, such as a single inset value or modifier for the block, so the header and the body can't drift apart again. If other output blocks (code blocks, diffs) use the same header-plus-body layout with the same gap, apply the same rule there and list them on the card.
- [ ] Keep the terminal background clear: the padding adds space, not a fill (transparent-by-default rule).
- [ ] Add a deterministic hosted test: the leading edge of the output's first text line equals the leading edge of the header's text, and the output's top and bottom insets equal the header's vertical inset, within layout rounding.
- [ ] Re-record any `__Snapshots__` image that changes because of this, and say which ones.
- [ ] Regenerate the review gallery and note the change in `ReviewGalleryNotes.swift` for the thread screen.

## Acceptance

- Terminal output has the header's horizontal and vertical padding, from shared EditorStyle tokens.
- The hosted alignment test passes, and the full `swift test` is green.
- The gallery's thread screen shows the padded output. #avk-8