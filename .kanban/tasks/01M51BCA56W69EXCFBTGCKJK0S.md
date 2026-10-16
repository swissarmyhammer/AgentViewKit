---
assignees:
- claude-code
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BC7WBQ93BAV1Q42Z2XGTQ
position_column: todo
position_ordinal: '9580'
title: 'Elicitation task 35: remove the pending requests host from AgentThreadView'
---
elicitation-plan.md task 35. AgentThreadView mounts PendingRequestsHost (a VStack of cards) today. Remove it; the app mounts the deck (task 34). Update the demo app and the docs so that the requests still show. Do it as the accepted deck design says. Tests with the step 7 rules. Write all text in STE.

## Accepted design
Source: deck design section 8, test plan row 35 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

What goes away:
- Remove PendingRequestsHost and its focusTarget. identifier(for:) and identifierPrefix move to RequestDeck (task 34).
- Remove the PendingRequestsHost(session:) line from AgentThreadView (AgentThreadView.swift:138) and update its doc.
- ThreadAccessibility.pendingRequests(of:connection:) keeps its signature (session requests, then connection requests).

Demo:
- RequestDeck(session:) in SessionThreadColumn, between ContextUsageView and the composer.
- RequestDeck(connection:) in the detail column of ACPTabView and GalleryTabView.

Docs:
- README Components list and plan.md §9 inventory (a test holds them equal).
- The ACPThread and HostApp snippets (run Scripts/extract-readme-snippets.sh).
- The doc comment at PromptInputView.swift:181.

App migration: replace PendingRequestsHost(...) with RequestDeck(...), and put the thread view, the deck and the composer in one accessibilityFocusScope(). Source break; no released v1.

Test plan (row 35). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [ ] AgentThreadView with a pending permission shows no pending-card-*.
- [ ] Update ThreadAccessibilityHostedTests, AgentCommandScopeHostedTests and StateBannerPendingRequestsHostedTests to mount the thread and the deck in one scope.
- [ ] DemoGalleryTests stays green.
- Waits: render() after a main-actor change; render(when: !pendingRequests.isEmpty) after the agent sends a request.

#elicitation-phase-6