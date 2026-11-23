---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: The directory module removes middle names to fit the width of the line, not a character count
---
## What
The `directory` module of the status line removes whole names from the middle of a long path when the path has more than `StatusLineDirectory.lengthLimit` characters (^6jt64qs work). The limit is a character count. In a narrow top bar (the 480 pt thread header of the glass gallery, and the crumbs line), SwiftUI cuts the text at the end: `~ › code › AgentViewKit › So…` and `Macintosh HD › tmp › scripted-…`. Then a name shows in part.

## Work
- [ ] Measure the width that the line gives to the module, and remove whole names from the middle until the path fits (for example with `ViewThatFits` over the elided forms, or a layout that measures the text).
- [ ] Keep the first part and the last folders whole. Show one `…`.

## Acceptance Criteria
- [ ] In the 480 pt thread header gallery image, the directory module shows whole names and one `…`, with no cut name.

## Tests
- [ ] A unit test for the choice of the elided form for a given width.
- [ ] The screenshot gallery with a temp HOME passes. Give the PNG paths.