---
assignees:
- claude-code
depends_on:
- 01M7SY6ERK3HTTBAVEPYXXNX1F
position_column: todo
position_ordinal: '8180'
title: Find Next Hit and Find Previous Hit over the transcript search hits (D207 f)
---
Brief: /Users/wballard/github/swissarmyhammer/.briefs/search/avk-brief.md, items 4 and 5. Do this after the task "Transcript search hits: reveal the best hit and mark the matched words".

Do:
- Kit verbs (D108): `findNextHit` ("Find Next Hit", ⌘G) and `findPreviousHit` ("Find Previous Hit", ⇧⌘G). ⌘G and ⇧⌘G are the Mac find keys, so they follow D137 (a), not the ⌃⌘ rule of kit commands. They are active only when the thread has hits and the focus is not in a text input. In a text input, ⌘G stays the find of the editor (D133).
- They go through the hits in the order of the transcript, from the current hit. At the end, they wrap and play the system beep.
- Esc in the thread (not in a text input), while the thread has hits, removes the hits: the kit sets the host binding to nil.
- Menu: the Edit menu, in a find group, with the verbs in the palette.
- Accessibility: the current hit posts an announcement with the author and the position ("Hit 2 of 7").

Tests (unit): Next and Previous, the wrap, no command in a text input, Esc removes the hits, the announcement text. A hosted test: compile only, do not run.

Push when `swift test` is green, and send the sha to testudoapp-9a.