---
assignees:
- claude-code
depends_on:
- 01M51BBM80Z31P06YPYQ6XE3HD
position_column: todo
position_ordinal: '9380'
title: 'Request deck: one design for the deck, sent to the step owner before any deck code (elicitation phase 6)'
---
elicitation-plan.md sections 4 and 9, phase 6. The ACPClient model is done: `PendingRequest`, `pendingRequests` on the session and the connection model (ACPClient 50ce00c), `frontRequest`, `bringToFront(_:)`, `bringToFront(toolCall:)` (ACPClient 7676d81).

Write ONE design (no code) and send it to the step owner. Start no deck code until the step owner accepts it. The design covers:
1. The public view: its name, its inputs (a SessionModel; a ConnectionModel for the connection-level requests), its customization points, and how an app mounts it (the prompt editor, the deck and the chat stream are three separate components; the app arranges them).
2. Depth and FIFO: one deck of permissions and elicitations in arrival order (ACPClient pendingRequests); the front card is full size; 2 or 3 cards behind show their top edges; then a count such as "+5"; the header "1 of 6".
3. Previous and Next controls and their keyboard shortcuts (how they map to bringToFront); answering the front card brings the next card to the front.
4. Each card stays mounted, keyed by its request id, so a partly completed form keeps its values.
5. Focus and announcements: a new card does not take the focus; a screen reader announces it; only the front card is available to VoiceOver.
6. The tool call status: a tool call shows only "Waiting for your answer"; a click brings its card to the front (bringToFront(toolCall:)); no second inline form (task 38).
7. Counts of open questions for sessions that are not on screen (task 40): where the count shows, and its data source.
8. The URL elicitation waiting state (task 41; needs ACPAgent task 8: elicitation complete only when the flow ends).
9. What goes away: PendingRequestsHost in AgentThreadView (task 35) and the inline elicitation form in ToolCallView (task 38).
10. The test plan for each part (same rules as mail step 7: no clock wait, poll, sleep or time limit; render() and event waits; a hosted wait for a certain event).
Task 39 (who asks) waits for phase 4. Write all text in STE. #elicitation-phase-6