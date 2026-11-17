---
assignees:
- claude-code
depends_on:
- 01M7NEPK3QHB30W786RBDV6CER
position_column: todo
position_ordinal: '8380'
title: 'AVK-9.4: Citations in chat Markdown use .editorCitations(_:onActivate:)'
---
D185. Map the AVK citation markers (U+E002/U+E003, a character offset in each paragraph) to `EditorCitation(offset:number:id:title:)`. The offset is a UTF-8 byte offset into the whole document. In `onActivate`, call `CitationSelection.select`.

Remove `CitationMarkdownParser`, `InlineCitationAttachment` and `InlineCitationAccessibility`. The link path of `citationScope()` stays for normal links.

First send the marker format to editorkit-7a, so that it can check that the format matches.

Acceptance: unit tests for the offset map (multibyte text, several paragraphs); CitationProseTests rewritten.

#avk-9