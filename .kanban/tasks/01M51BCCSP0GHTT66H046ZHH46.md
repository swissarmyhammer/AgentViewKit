---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m522jkxrzpymfq3nncq6szp1
  text: |-
    Note from ^mw15y7w (for card 34 ^2z2xgtq): DeckSource in Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift no longer has `front` and `bringToFront(_:)`. They had no caller, so card 34 must not ship them with `// periphery:ignore`. This card must add them to DeckSource when the depth layout and the Previous/Next controls call them:
    - `var front: PendingRequest?` — `session.frontRequest` for `.session`, `connection.frontRequest` for `.connection`.
    - `func bringToFront(_ id: PendingRequest.ID)` — `session.bringToFront(id)` for `.session`, `connection.bringToFront(id)` for `.connection`.
    Also add "the front request and the move of a request to the front" back to the DeckSource doc comment.
  timestamp: 2026-10-16T10:02:00.504931+00:00
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCA56W69EXCFBTGCKJK0S
position_column: todo
position_ordinal: '9680'
title: 'Elicitation task 36: show the deck as a ZStack with depth, FIFO, previous and next'
---
elicitation-plan.md task 36, section 4: one deck in FIFO order (oldest in front); the front card full size; 2 or 3 cards behind show their top edges, then "+N"; the header "1 of N"; Previous and Next controls and keyboard shortcuts; answering the front card brings the next card; each card stays mounted, keyed by its request id. Do it as the accepted deck design says. Tests with the step 7 rules. Write all text in STE.

## Accepted design
Source: deck design sections 2 and 3, test plan row 36 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

Depth and FIFO:
- One deck for permissions and elicitations, in pendingRequests order, oldest first.
- The front card is frontRequest, full size. Behind it, a maximum of 3 cards show their top edges, in FIFO order with the front skipped. Then "+N" for the cards that do not show.
- Header "k of N": k = position of the front in pendingRequests + 1; N = count.
- All cards stay mounted in one ForEach keyed by PendingRequest.id, so a partly completed form keeps its values. Hidden cards have opacity 0. Hidden cards and edge cards are not hit-testable and cannot take keyboard focus.
- A new request goes at the back. The front does not change.
- When the front is answered or cancelled, the model clears frontRequestID. The front becomes the oldest card that stays.
- When a card behind is cancelled, it goes away. The front does not change.
- An empty deck shows nothing and takes no space. The front change is animated only when Reduce Motion is off.
- A pure RequestDeck.layout(requests:front:) gives the order, the edges, "+N", "k of N" and the Previous/Next state.

Previous and next:
- Previous = bringToFront(requests[k-2]); Next = bringToFront(requests[k]). No wrap: Previous is disabled at 1, Next is disabled at N.
- New AgentCommandVerb cases previousRequest and nextRequest, default chords ⇧⌘[ and ⇧⌘], in AgentKeymap.defaultChords (AgentKeymap.swift:31) and its doc table. Option-Up/Down already jump between prompts.
- With one request: no header, no controls. The verbs are not available.
- Approve and reject (AgentCommandTarget.swift:332) answer the front request when it is a permission; else the first pending permission, as now.
- Identifiers: request-deck-position; request-deck-previous; request-deck-next; request-deck-more.

Answers:
- Q3 yes: "+N" counts only the cards that do not show (6 requests: "1 of 6", 3 edges, "+2").
- Q4 yes: after an answer to a card that was brought to the front, the next front is the oldest card that stays (model behavior now).
- Q5 yes: keys ⇧⌘[ and ⇧⌘].

Test plan (row 36). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [ ] Pure RequestDeck.layout(requests:front:) table test (0, 1, 2, 4, 6 requests; front in the middle; a front that goes away): order, edges, "+N", "k of N", Previous/Next state.
- [ ] Hosted: six requests show "1 of 6", 3 edges, "+2".
- [ ] Hosted: Next, then ⇧⌘], give "2 of 6", then "3 of 6".
- [ ] Hosted: a typed value survives Next and Previous.
- [ ] Hosted: an answer to the front gives "1 of 5".
- [ ] Hosted: one request has no header and no controls, and the verbs are not available.
- [ ] Hosted: a new request does not change the front.
- Waits: render(when: count == 6); render() after a press or a key; ObservationWait.until { count == 5 }.

#elicitation-phase-6