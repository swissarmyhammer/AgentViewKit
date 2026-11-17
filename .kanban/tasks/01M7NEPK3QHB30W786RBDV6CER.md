---
assignees:
- claude-code
position_column: todo
position_ordinal: '8680'
title: 'AVK-9.7: ResponseView streams through one EditorModel per text block (blocked on EditorKit syncStreaming)'
---
D185. BLOCKED: EditorKit task 01M7GFR8NGXTKTJBGJJAF86QMK (`EditorModel.syncStreaming(to:)`, incremental restyle). editorkit-7a will send the commit after its review.

- Replace `ParagraphSplitter`, `ParagraphView` and `ParagraphViewCache` with one `EditorModel` per text block, kept by block id and updated with `syncStreaming(to:)`.
- Delete the AVK copy of `syncStreaming`/`appendStreaming` in Code/EditorModel+Append.swift. The names collide with the EditorKit method.
- Delete `StreamingMarkdownBalancer`.
- Rewrite ParagraphReuseTests, ParagraphViewCacheTests and SessionModelRedrawScopeTests for restyle per model.
- Also needs EditorKit 01M7GFS3EG4XGC955BT5RFTRPX (one selection across blocks in one view).

#avk-9 #blocked