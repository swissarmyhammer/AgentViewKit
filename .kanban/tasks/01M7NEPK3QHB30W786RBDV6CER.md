---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7nvfte195zbszsqxz7vfkm8
  text: |-
    Implementation notes (AVK-9.7, with 9.3 and 9.4 in the same change):
    - ResponseView now shows RenderedMarkdownView (one read-only EditorModel, rendered, display role). A new text goes in with syncReadOnly -> EditorKit syncStreaming(to:), so a chunk is one insert at the end.
    - One model per ResponseView id: `.id(id)` on the view, model in OwnModelSlot. DEVIATION to note: when the environment has a CodeBlockModelCache, the model is in the cache (key CodeBlockID(messageID: id, paragraphID: "response-text")). Reason: the screenshot thread snapshot must wait for the syntax parse of the message model (certain wait, no clock), and it can reach the model only through the cache. With no cache (the default of AgentThreadView) the model is in view state.
    - RenderedMarkdownView syncs with `.onChange(of:initial: true)`, so a cached model with an older text gets the text of the view at the mount.
    - Deleted: ParagraphSplitter, ParagraphView, ParagraphViewCache, StreamingMarkdownBalancer, EditorModel+Append (appendStreaming), MarkdownProse, MathMarkdownParser, MathSpanScanner, MathView, TextMarker, CitationMarkers, CitationPlacement, CitationMarkdownParser, InlineCitationAttachment, InlineCitationAccessibility.
    - MarkdownFence stays (moved to Content/): the new MarkdownParagraphs locator uses it to count the paragraphs of a CitationMarker.
    - Public API removed: ResponseView.paragraphIdentifierPrefix, ResponseView.paragraphIdentifier(index:), ParagraphSplitter, ParagraphView, MathView, EditorModel.appendStreaming. Added: ResponseView.textIdentifier ("response-text").
    - Not done here: one selection across blocks inside one view waits for EditorKit 01M7GFS3EG4XGC955BT5RFTRPX.
  timestamp: 2026-11-17T22:54:21.121173+00:00
- actor: claude-code
  id: 01m7nvtwqgyd8ctdxc0fjy8fap
  text: |-
    ### implement — changed
    - evidence: commit a92da599 on branch worktree-agent-a9658adbff122d25c. `swift test`: 1248 tests in 147 suites passed, and 50 tests in 10 suites passed. IntegrationTests and ScreenshotTests compile (`swift build --build-tests`). The hosted tests were not run.
    - The same commit does AVK-9.3 (math) and AVK-9.4 (citations).
    - next: review. Open items: the selection across blocks waits for EditorKit 01M7GFS3EG4XGC955BT5RFTRPX. The marker format was not sent to editorkit-7a (this agent has no channel to it).
  timestamp: 2026-11-17T23:00:23.920164+00:00
position_column: done
position_ordinal: ffffffe480
title: 'AVK-9.7: ResponseView streams through one EditorModel per text block (blocked on EditorKit syncStreaming)'
---
D185. BLOCKED: EditorKit task 01M7GFR8NGXTKTJBGJJAF86QMK (`EditorModel.syncStreaming(to:)`, incremental restyle). editorkit-7a will send the commit after its review.

- Replace `ParagraphSplitter`, `ParagraphView` and `ParagraphViewCache` with one `EditorModel` per text block, kept by block id and updated with `syncStreaming(to:)`.
- Delete the AVK copy of `syncStreaming`/`appendStreaming` in Code/EditorModel+Append.swift. The names collide with the EditorKit method.
- Delete `StreamingMarkdownBalancer`.
- Rewrite ParagraphReuseTests, ParagraphViewCacheTests and SessionModelRedrawScopeTests for restyle per model.
- Also needs EditorKit 01M7GFS3EG4XGC955BT5RFTRPX (one selection across blocks in one view).

#avk-9 #blocked