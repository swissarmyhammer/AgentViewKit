---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7nvv270aghahspshqc5rtha
  text: |-
    ### implement — changed
    - evidence: commit a92da599 (with AVK-9.7). `CitationPayload.editorCitations(in:)` maps each marker (a paragraph index and a character offset) to an EditorCitation at a UTF-8 byte offset in the whole text. MarkdownParagraphs counts the paragraphs. A marker in a fence, of an unknown source, or of a paragraph that is not there makes no chip. onActivate calls CitationSelection.select. CitationMarkdownParser, InlineCitationAttachment and InlineCitationAccessibility are removed. CitationProseTests is rewritten (multibyte text, several paragraphs, clamping).
    - next: review. The marker format was NOT sent to editorkit-7a: this agent has no channel to it.
  timestamp: 2026-11-17T23:00:29.536972+00:00
depends_on:
- 01M7NEPK3QHB30W786RBDV6CER
position_column: done
position_ordinal: ffffffe680
title: 'AVK-9.4: Citations in chat Markdown use .editorCitations(_:onActivate:)'
---
D185. Map the AVK citation markers (U+E002/U+E003, a character offset in each paragraph) to `EditorCitation(offset:number:id:title:)`. The offset is a UTF-8 byte offset into the whole document. In `onActivate`, call `CitationSelection.select`.

Remove `CitationMarkdownParser`, `InlineCitationAttachment` and `InlineCitationAccessibility`. The link path of `citationScope()` stays for normal links.

First send the marker format to editorkit-7a, so that it can check that the format matches.

Acceptance: unit tests for the offset map (multibyte text, several paragraphs); CitationProseTests rewritten.

#avk-9