---
assignees:
- claude-code
position_column: todo
position_ordinal: '8880'
title: 'Scroll: no EditorKit hover responders in the rows of a live flick, if the trace still shows the hover update'
---
From ^9ync5h3 (2026-11-28). The rows of a thread now have no hover responder of AVK: one `.onContinuousHover` on the stack (`TranscriptRowsHover`) gives the row under the mouse to `TranscriptRowHoverTarget`, and the stack takes no hit test in a live motion. The rows still hold the hover responders of EditorKit controls: `EditorToolbarButton` has `.onHover`, and each `EditorButtonParts` button has `.help` (also with an empty tooltip). The still view of each `StaticEditorSlot` has a press gesture. No unit test can count the responders that SwiftUI walks in its hover update (`EventBindingManager.enqueueHoverUpdateIfNeeded`).

## What
- [ ] Take a flick trace of the release harness after ^9ync5h3 (572f0fab, fcc9de30). If the hover update (`enqueueHoverUpdateIfNeeded`, `ViewGraph.responderNode`, `MultiViewResponder.features`) still costs more than 100 ms in a 15 s flick, continue with the items below. Else close this card.
- [ ] In a live motion, the rows have no hover or gesture responder of EditorKit controls and no press gesture of a static slot, with no change to the identity of a row (for example a background or an environment value that EditorKit reads, in an EditorKit change).
- [ ] At rest, the hover look of each control and each row action work as before.

## Tests
- [ ] A counting unit test (RED first) and the hosted hover and menu suites.

#perf