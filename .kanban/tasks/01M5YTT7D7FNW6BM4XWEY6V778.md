---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5ytxemyjcq50dpk0t2en7fj
  text: |-
    ### Waits on EditorKit ^bcsmt4w
    EditorKit filed the tile tokens as ^bcsmt4w: an EditorStyle tile group with padding, gap and margin, defaults from the spacing scale, overridable by a theme, and used by EditorKit's own tiles. It is queued after EditorKit ^1gab15j. Don't start this card until editorkit-a9 sends the main SHA and the final names.
  timestamp: 2026-10-27T14:06:05.470645+00:00
position_column: todo
position_ordinal: a480
title: 'AVK-8 tiles: one theme-driven padding, gap and margin for every content tile, bordered or not (cards, banners, request cards, tool calls, terminal output, code blocks, diffs, artifacts), from the user''s gallery review'
---
## Why

From the user's review of the review gallery (2026-10-27), verbatim:
1. "the shell command outputs do not have enough padding and look cramped. be consistent with the padding in the header area"
2. "spacing and padding needs to be consistent on all 'bordered' tiles -- cards, and not bordered tiles displaying content. make sure this padding and margin comes from the theme"

Screens: `~/Library/Caches/AgentViewKit/screenshot-check/*.png`. Regenerate them with `swift test --filter ReviewGallery`.

Today each tile picks its own `editorStyle.spacing.{xs,s,m,l}` or a bare `.padding()`. EditorStyle has raw sizes but no semantic tile tokens, so tiles drift: terminal output is cramped compared with its header.

## Depends on EditorKit

The padding and margin must come from the theme, which is EditorStyle. EditorKit is asked (by editorkit-a9) to add semantic tile tokens to `EditorStyle` that a theme can set, for example `EditorStyle.tile`, with:
- `padding`: the inset of the tile content from the tile edge, the same for the header row and the body;
- `gap`: the space between the header and the body, and between stacked parts inside a tile;
- `margin`: the space between neighbouring tiles in a list or transcript.

Before you start, check the EditorKit main SHA with the final names, and use those names. Pin AVK to that SHA.

## What to do

- [ ] List every content tile in AVK, bordered (`EditorSurface.inlineEdge`, stroke) or not, and record the list in a comment with file:line. Start from: ToolCallView (header and body, including terminal output via `Terminal/TerminalView.swift` and `Content/OutputChrome.swift`), `Code/EditorBlockChrome.swift` (code blocks, diffs), ResourceBlockView, TextBlockView, ErrorView, CompactionEntryView, ArtifactView, SessionNoticeBanner, StateBanner, StatusBar, RequestDeck, PermissionView, ElicitationLayout, AgentAuthView and AgentLoginPrompt.
- [ ] Add one AVK modifier, `.contentTile()` or a similar name (one modifier per feature), that applies the theme's tile padding to a tile's content, and one layout for header plus body that uses the tile gap. Bordered and unbordered tiles use the same modifier. The border stays a separate opt-in, and so does any fill (transparent by default).
- [ ] Replace every tile's own padding with the modifier. No literal numbers, and no bare `.padding()`, on a tile.
- [ ] The space between tiles in the transcript and in lists comes from the tile margin.
- [ ] Terminal output: the output text starts on the header text's leading edge, with the tile padding above and below. The terminal background stays clear.
- [ ] Add a structure test, like the existing PackageStructureTests guards, that fails when a tile file uses `.padding(` with a literal or without the tile tokens, and an allow list for the files that aren't tiles.
- [ ] Add a hosted test for a bordered tile and an unbordered tile (for example a request card and terminal output): the content inset from the tile edge equals `editorStyle.tile.padding`, and the header-to-body gap equals `tile.gap`, within layout rounding. Add one more test where a theme with a different tile padding changes the inset.
- [ ] Re-record the `__Snapshots__` images that change, and list them.
- [ ] Regenerate the review gallery and update `ReviewGalleryNotes.swift`.

## Acceptance

- Every content tile, bordered or not, takes its padding, gap and margin from the EditorStyle tile tokens, through the one AVK modifier.
- The structure guard and the hosted inset tests pass, and changing the theme's tile padding changes the tiles.
- The full `swift test` is green, and the gallery shows consistent tiles. #avk-8