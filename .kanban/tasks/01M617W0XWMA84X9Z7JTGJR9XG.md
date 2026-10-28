---
assignees:
- claude-code
position_column: todo
position_ordinal: ad80
title: 'Diff in a tool call: show each file once (diff chip only), with no nested tile, so the indentation lines up'
---
User: "the diff view -- you are showing the affected files twice -- name pill, and a diff pill -- just keep the diff pill, then you can avoid the extra indentation of the diff pill/diff view section and get more consistent indentation alignment".

## Cause
- ToolCallView.swift:569-585, the default body: a call with `locations` first shows `ToolCallLocationChips` (the name pill per file). Its `.diff` part (:620) then shows `DiffView`, whose `fileChips` (DiffView.swift:222) draw a `DiffFileChip` for the same files. So every file appears twice.
- DiffView's body is `ContentTileStack { chips } body: { detail }.contentTile()` (DiffView.swift:206-211). Inside the tool call's own tile, that adds a second tile's padding, so the diff chips and the diff text are indented further than the rest of the call body (the input/output blocks, the location chips).

## Fix
- [ ] A tool call whose parts include a diff doesn't show a location chip for a path the diff already shows as a `DiffFileChip`. A location the diff doesn't cover, such as a read-only location, still shows its chip. With no diff part, nothing changes.
- [ ] Inside a tool call, DiffView doesn't add its own `.contentTile()` padding or border. Its chips and its detail sit on the call body's leading edge, at the same inset as the other blocks, and the tile gap comes from `editorStyle.tile.gap`. A DiffView on its own, outside a tool call, keeps its tile. Do this with one clear mechanism (for example, the place the diff sits in), with no compatibility shim. One modifier per feature.
- [ ] A hosted test: in a tool call with a diff of 2 files, each path appears once (only the DiffFileChip), and the leading x of the diff chips, the diff text and the call's other blocks is the same
- [ ] Re-record the affected snapshots, and regenerate and check the review gallery (thread screen)
- [ ] `swift test` is green

Order: after the complete gallery card (^wprq982).