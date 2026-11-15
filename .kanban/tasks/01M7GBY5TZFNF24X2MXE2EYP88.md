---
assignees:
- claude-code
position_column: doing
position_ordinal: '80'
title: One text selection in the thread
---
Defect from the user (OpenTestudo): with two responses, an I-beam selection in one text area does not clear the selection in a different text area. Each Textual StructuredText (one for each paragraph) and each EditorKit EditorView keeps its own selection.

Fix:
- Add a thread text-selection coordinator (one owner, `claim` clears the old owner) in AgentThreadView state and in the environment. It conforms to the EditorKit `TextSelectionRegion` protocol (editorkit-7a).
- Each Textual text registers a region with a probe NSView. The probe observes `window.firstResponder` and claims when the Textual interaction view in its frame becomes first responder. The clear makes the StructuredText again (`.id(generation)`).
- Unit tests for the coordinator and for the probe decision.
- Update Docs/decisions/text-selection.md and ARCHITECTURE.md. #bug