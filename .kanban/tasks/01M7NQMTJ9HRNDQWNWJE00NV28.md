---
assignees:
- claude-code
depends_on:
- 01M7NQMD8YCFC8F7TC11Y5EC6G
position_column: todo
position_ordinal: '8980'
title: 'AVK-15.2: A host mention row makes a chip with its link'
---
D199. Brief item 2.

Now a host route inserts only text (EditorKit CompletionInsert has .text and .snippet). A file chip comes from `acceptedFile(before:root:)` (Input/EditorKitPromptEditor.swift:493-511), `@State references` (:110, :333-335), the FileReferenceDetector SmartTag (:147-149), and the `.link` runs of `attributedText` (:600-618), which `references(in:root:)` (:569-572) reads back.

Do:
- On `.completionAccept` of a mention row, record the inserted token and its link, the same as `references`.
- A second detector (for example `MentionDetector(tokens:)`) draws a `.token` chip.
- `attributedText` puts the `.link` of the row on the run, so the chip stays after a pull of the text. A reader gives the mentions back.
- A token that the user types with no popup is not a chip (AVK-15.4 can mark it).

Tests (TDD, unit): an accepted mention row records its token and link; `references(in:root:)` and the mention reader round-trip the `.link`. Hosted test (compile only): accept a mention row and see one chip.

#avk-15