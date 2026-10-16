---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m521p5k20254ppv7s81q1egw
  text: |-
    Implementation notes (card 34, RequestDeck).

    What landed:
    - New Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift. public struct RequestDeck: View, PrefixedAccessibilityIdentifier. public init(session:) and init(connection:). Identifiers: RequestDeck.identifier = "request-deck" (the deck container) and identifierPrefix "pending-card-" with identifier(for:) from PrefixedAccessibilityIdentifier.
    - Internal enum DeckSource (session / connection) gives one code path: requests (pendingRequests filtered to the requests that have a card), front (frontRequest), bringToFront(_:), session (for PermissionView) and elicitationOwner. No view-local @State; the deck keeps no copy.
    - The body is DeckCards(source:).accessibilityFocusScope(). The scope is outside the cards, so that the AccessibilityFocusMove of the cards reads the mover of the scope. The scope does nothing when the environment already has a mover (AgentThreadView has one).
    - PendingRequestsHost is now a thin wrapper that shows a RequestDeck of the same model (no copied body). identifierPrefix and identifier(for:) moved to RequestDeck. PendingRequestsHost.focusTarget(old:new:) stays public and forwards to the internal RequestDeck.focusTarget(old:new:) until cards 35 and 37.
    - Docs: README Components list and plan.md §9 inventory have RequestDeck. HostApp snippet has RequestDeck(connection:) at the window level; Scripts/extract-readme-snippets.sh was run.

    Minimum of later parts, and what I left to later cards:
    - The deck keeps the focus rule of the host (focusTarget(old:new:)) so that the ported focus tests stay true. Card 37 replaces it.
    - The layout is a VStack of all cards in pendingRequests order (arrival order). Card 36 makes the depth layout. DeckSource.front and bringToFront(_:) have no caller yet; each has a `// periphery:ignore` marker with the reason line above it (card 36 reads them).
    - The identifiers request-deck-position, request-deck-previous, request-deck-next and request-deck-more are not declared: no element carries them before card 36, which lists them again.
    - The ACPThread snippet does not change in card 34. AgentThreadView still mounts PendingRequestsHost (now the deck) until card 35, so a RequestDeck(session:) next to it in the snippet would show each card two times. The RequestDeck doc says this. Card 35 changes the ACPThread snippet.

    Discoveries:
    - An unapplied reference RequestDeck.identifier(for:) (for example `.map(identifier(for:))`) does not compile: "main actor-isolated conformance of 'RequestDeck' to 'PrefixedAccessibilityIdentifier' cannot be used in nonisolated context". Call it directly.
    - The ScriptedWireAgent handles frames one at a time. While it holds the answer to auth/login, it does not read the response of a connection elicitation. A test that answers a login elicitation must release the held answer before it waits for that response. The first form of the new decline test hung for this reason; the test now releases first.
    - One filtered run hung in cancelAllPendingOnTheModelRemovesTheShownCards after 95 passes (main thread idle). It passed in two later single runs. Recorded as task ^mw15y7w with the sample and the log.
  timestamp: 2026-10-16T09:46:28.322135+00:00
- actor: claude-code
  id: 01m521qjyds94zvnqkyk9weef4
  text: |-
    ### implement — changed
    - evidence: files: Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift (new), Sources/AgentViewKit/HumanInTheLoop/PendingRequestsHost.swift, Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift, Tests/AgentViewKitTests/Commands/AgentCommandScopeHostedTests.swift, README.md, plan.md, Examples/ReadmeSnippets/Snippets/HostApp.swift.
    - build: swift build --build-tests, 0 errors, 0 warnings (the "missing creator" line of the mlx bundle is from the build system, not the code).
    - tests: one filtered run of PendingRequestsSessionModelHostedTests, PermissionViewHostedTests, ThreadAccessibilityHostedTests, AgentCommandScopeHostedTests, StateBannerPendingRequestsHostedTests, ElicitationURLConsentViewHostedTests, ToolCallEntryViewHostedTests and ReadmeCoverageTests: 95 tests passed, 0 failed, 7 suites passed; then cancelAllPendingOnTheModelRemovesTheShownCards hung (task ^mw15y7w). The tests of PendingRequestsSessionModelHostedTests that did not run in that run then ran one time each: cancelAllPending… passed, eachElicitationAnswer… (3 cases) passed, aLoginElicitation… passed, aDeclineInTheConnectionDeck… passed after the release-order fix of the test.
    - Scripts/check-readme.sh: passed (each snippet is in its file and compiles).
    - Left to later cards (see the note above): ACPThread snippet (card 35), the identifiers request-deck-position/previous/next/more (card 36; a constant that only a test reads is not allowed), the depth layout and the readers of DeckSource.front/bringToFront (card 36), the new focus rule (card 37).
    - next: /review. The test plan check boxes of the card are not ticked in the description yet.
  timestamp: 2026-10-16T09:47:14.765779+00:00
- actor: claude-code
  id: 01m522jqjfgdfxwk8s88a4q3qc
  text: 'Change from ^mw15y7w in RequestDeck.swift: the two `// periphery:ignore` markers are gone. DeckSource.front and DeckSource.bringToFront(_:) had no caller in source, so they are removed, and the DeckSource doc comment names only the requests, the session model for permissions, and the elicitation owner. Card 36 (^46zhh46) has a note to add them back when its layout calls them. Also: the hang that ^mw15y7w recorded was not in cancelAllPendingOnTheModelRemovesTheShownCards. It was the first form of aDeclineInTheConnectionDeckGoesToTheAgentAndTheCardGoesAway (same test binary as rest.log); the working tree already has the fixed form. One run of the whole PendingRequestsSessionModelHostedTests suite after the change: 8 tests (103 cases) passed, 0 failed, 0 warnings.'
  timestamp: 2026-10-16T10:02:04.239226+00:00
- actor: claude-code
  id: 01m524q6yjsys1y7s1wsqyskch
  text: |-
    ### review — clean
    - evidence: review sha 005dfa1~1..005dfa1. Counts: findings 0, confirmed 0, refuted 3, attempted 14, failed 0, skipped 0. 17 files reviewed. 11 files not reviewed: 8 .kanban files (excluded by .reviewignore); Docs/decisions/accessibility.md, README.md and plan.md (no validator matches these files). Five code-hygiene Swift tool rules did not read Sources/AgentViewKit/HumanInTheLoop/PendingRequestsHost.swift, because the commit deletes that file. No finding for card 34 [34]. No finding for card 35 [35].
    - scope: the commit holds card 34 and card 35. This pass records the result of the full range on card 34. Card 35 is not moved.
    - next: card 35 (^gckjk0s) gets its review on the same range.
  timestamp: 2026-10-16T10:39:28.210662+00:00
- actor: claude-code
  id: 01m5256c4yjmq6mgtz0c9y2zgs
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — RequestDeck.swift (new), PendingRequestsHost.swift, 4 test files, README.md, plan.md, HostApp snippet; the hang ^mw15y7w came from the first form of the new decline test (fixed)
    - test: green — script -q swift test, one run: 1223 passed in 140 suites (plus the package and snippet targets), 0 failed, 0 skipped, 2 known issues; check-readme passed
    - commit: 005dfa1 (one commit with card 35 ^gckjk0s, because the two cards share seven files)
    - review: clean — 0 findings; card moved to done; the three test-plan boxes ticked after a check of the tests
  timestamp: 2026-10-16T10:47:45.054080+00:00
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
position_column: done
position_ordinal: ffd280
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
- [x] Port the PendingRequestsHost tests (PendingRequestsSessionModelHostedTests, PermissionViewHostedTests) to RequestDeck(session:) and RequestDeck(connection:): a card shows and its answer reaches the agent.
- [x] identifier(for:) gives pending-card-<id>.
- [x] README snippets compile and the components test passes.
- Waits: render(when: !pendingRequests.isEmpty); ObservationWait.until { response != nil && pendingRequests.isEmpty }.

#elicitation-phase-6