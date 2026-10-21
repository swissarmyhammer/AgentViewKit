---
assignees:
- claude-code
position_column: todo
position_ordinal: b280
title: Examine the white fill of the EditorKit text area in a code block (D113 answer 1)
---
Source: ^6dvspvv (AVK-8ac) implement step.

Problem: in the window cache, the EditorKit text area of a `CodeBlockView` shows opaque white. The color is not `editorBackground`. Only the gutter lets the backdrop through. This can be a real fill of the editor. D113 answer 1 forbids a custom fill behind a code block.

Do:
- Find where the white comes from (EditorKit text view background, `drawsBackground`, an NSScrollView background, or the window cache).
- If it is a real fill in AgentViewKit, remove it. If it is in EditorKit, write a card for the EditorKit session and record it here; do not change EditorKit from this repo.
- If it is only a result of the window cache, record the proof here and close this card.

Acceptance:
- The cause is recorded on this card with file:line.
- If the kit had the fill: a test shows that the backdrop shows inside the text area of a code block. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8