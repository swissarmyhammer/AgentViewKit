---
assignees:
- claude-code
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
position_column: todo
position_ordinal: '9480'
title: 'Elicitation task 34: make the request deck a separate public view (session and connection)'
---
elicitation-plan.md task 34, section 4. Do it as the accepted deck design (card 01M51BBZPSYD6PQ2CSQAQQTHFK) says. A public deck view for a SessionModel and for a ConnectionModel, on ACPClient pendingRequests / frontRequest / bringToFront. The prompt editor, the deck and the chat stream are three separate components; the app arranges them. Tests with the step 7 rules. Write all text in STE.

## Blocked upstream
Blocked until ACPClient reports elicitation-plan task 51 (ConnectionModel.frontRequest/bringToFront) pushed. The step owner says when. Task 51 is done in the ACPClient package by another session, not on this board.

## Accepted design
Source: deck design sections 1 and 8, test plan row 34 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

What to build:
- RequestDeck in Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift. public init(session: SessionModel) and public init(connection: ConnectionModel). An internal DeckSource gives one code path: requests, front, bringToFront(_:), the elicitation owner.
- The deck reads pendingRequests and frontRequest and keeps no copy. A permission card is PermissionView(request:session:). An elicitation card is ElicitationCard. Customization: the existing field overrides and the theme only.
- The deck is not in the lazy list, so it is always mounted. Recommended layout: VStack { AgentThreadView(...); RequestDeck(session:); PromptInputView(...) }.accessibilityFocusScope(). RequestDeck(connection:) goes at the window level (for example the top of the detail column), for request-scoped questions such as auth/login.
- The deck applies accessibilityFocusScope(). It does nothing when the environment already has a mover.
- It replaces PendingRequestsHost. identifier(for:) and identifierPrefix move to RequestDeck.
- Identifiers: request-deck; pending-card-<id> (no change); request-deck-position; request-deck-previous; request-deck-next; request-deck-more.
- ACPClient API (checkout 66dd9b6): PendingRequest (PendingRequest.swift:12); SessionModel.pendingRequests (Model/SessionModel+Pending.swift:46); frontRequest (Model/SessionModel+Front.swift:15); bringToFront(_:) (:26); ConnectionModel.pendingRequests (Model/ConnectionModel+Elicitation.swift:39). ConnectionModel.frontRequest and bringToFront(_:) come from task 51 (fact C).

What goes away (with task 35): PendingRequestsHost and its focusTarget. ThreadAccessibility.pendingRequests(of:connection:) keeps its signature.

Docs: README Components list and plan.md §9 inventory (a test holds them equal); the ACPThread and HostApp snippets (run Scripts/extract-readme-snippets.sh). App migration: replace PendingRequestsHost(...) with RequestDeck(...), and put the thread view, the deck and the composer in one accessibilityFocusScope(). Source break; no released v1.

Answers:
- Q1 yes: ACPClient adds ConnectionModel.frontRequest and bringToFront(_:) (task 51) before this task. No view-local @State.

Test plan (row 34). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [ ] Port the PendingRequestsHost tests (PendingRequestsSessionModelHostedTests, PermissionViewHostedTests) to RequestDeck(session:) and RequestDeck(connection:): a card shows and its answer reaches the agent.
- [ ] identifier(for:) gives pending-card-<id>.
- [ ] README snippets compile and the components test passes.
- Waits: render(when: !pendingRequests.isEmpty); ObservationWait.until { response != nil && pendingRequests.isEmpty }.

#elicitation-phase-6 #blocked-upstream