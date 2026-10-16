---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m51wc3fwg3tn28n903fp8hm9
  text: |-
    ### Design accepted by the step owner
    The design file: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/43998bc3-6f4e-4bb7-909b-93c5172edb4f/scratchpad/deck-design.md (ACPClient checkout 66dd9b6). The phase 6 cards (34, 35, 36, 37, 38, 40, 41) now hold the parts of the design that apply to them.

    Answers:
    - Q1 yes. ACPClient adds ConnectionModel.frontRequest and bringToFront(_:) before task 34 (elicitation-plan task 51, in the ACPClient package, by another session). No view-local @State.
    - Q2 yes. The deck announces each new request, so each request is announced one time.
    - Q3 yes. "+N" counts only the cards that do not show (6 requests: "1 of 6", 3 edges, "+2").
    - Q4 yes. After an answer to a card that was brought to the front, the next front is the oldest card that stays (model behavior now).
    - Q5 yes. Keys ⇧⌘[ (previous) and ⇧⌘] (next).
    - Q6 yes. A currentSession parameter on SessionListView, and a public PendingRequestCountBadge(session:).
    - Q7 yes for v1. Stop waiting does not tell the agent. A separate card records the need for a later ACP message.
    - Q8 yes. No tool call status for a pending permission now. Also: if a tool call row shows an inline permission form today, remove it, so that the deck is the only place to answer.
    - Q9 yes. Keep .high for each new request.

    Path facts:
    - A. The URL "waiting" state has no data source. acceptElicitation removes the request from the model, so ModelClient.elicitationComplete (ModelClient.swift:126) finds no match later. Task 41 needs an ACPClient change first: awaitingURLCompletions and stopWaiting (elicitation-plan task 52, in the ACPClient package).
    - B. The browser session of a URL card stops when the user accepts. ElicitationURLConsentView.open() (:223-228) accepts the request; the accept removes the card; onDisappear (:158-160) cancels the browser task; AuthorizationPresenter.present stops the browser on a cancel (:83-87). This is a defect today. Task 41 repairs it. A bug card records it.
    - C. ConnectionModel has pendingRequests, but no frontRequest and no bringToFront. The connection deck needs them (Q1, task 51).
  timestamp: 2026-10-16T08:13:35.612770+00:00
depends_on:
- 01M51BBM80Z31P06YPYQ6XE3HD
position_column: done
position_ordinal: ffd080
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