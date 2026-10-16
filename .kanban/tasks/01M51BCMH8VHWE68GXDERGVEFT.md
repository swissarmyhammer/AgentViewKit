---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m51bdracz0he6gmjr5prx2gj
  text: |-
    ### Prerequisite done (from the step owner)
    Elicitation task 8 is done in ACPAgent 3a3d67e: after a URL accept, the agent sends elicitation/complete only when the flow ends, or when the question ends with no answer. Thus the "waiting" state in the client can last, and this task can show it.
  timestamp: 2026-10-16T03:17:23.916001+00:00
- actor: claude-code
  id: 01m531t196smp5b5pxzacq2g3s
  text: |-
    ### Research done
    - Prerequisites are present: the ACPClient checkout e44c617 has awaitingURLCompletions and stopWaiting(_:) on SessionModel and ConnectionModel; ACPAgent 3a3d67e is in FoundationModelsACPAgent.
    - acceptElicitation of a URL elicitation with an elicitationId moves it to awaitingURLCompletions with the same id, and removes its tool-call link. completeElicitation, cancel(meta:), cancelAllPending() and close remove it.
    - RequestDeck reads only pendingRequests. Thus the accept removes the card from the ForEach, and onDisappear of ElicitationURLConsentView cancels the browser task (bug card ^rkwj84j).
    - Plan: DeckSource also reads awaitingURLCompletions. The same ForEach shows these cards after the pending cards, with a new DeckCardRole.waiting that DeckStackLayout puts below the front card. They are not in "k of N"; the header shows "N waiting".
    - The URL card reads its waiting step from the model (awaitingURLCompletions of its owner), so a card that mounts again still shows the waiting step. The waiting step shows Retry and Stop waiting. Stop waiting stops the browser and calls stopWaiting. Esc in the waiting step does the same as Stop waiting. onDisappear reports the stop of the browser task to elicitationBrowserReport, so a hosted test can require the stop in the same step.
    - PendingElicitationOwner gets awaitingURLCompletions and stopWaiting(_:); both models already have them.
    - ToolCallWaitingStatus shows "Waiting for <host>" when an elicitation of awaitingURLCompletions names the tool call (toolCallId), because the accept removes the link.
    - FakeWebAuthSession has no cancelCount; the tests wait on calls.contains(.cancel).
  timestamp: 2026-10-16T19:07:49.414217+00:00
- actor: claude-code
  id: 01m532far53mypfgegdzcgepys
  text: |-
    ### Implementation landed (not committed)
    - PendingElicitationOwner gets awaitingURLCompletions and stopWaiting(_:) (SessionModel and ConnectionModel have both).
    - RequestDeck: DeckSource.awaiting reads awaitingURLCompletions. The pending cards and the waiting cards are in ONE ForEach (same id), so the accepted URL card keeps its identity and its browser task. New DeckCardRole.waiting: the card shows whole below the front card, is in the accessibility tree, takes clicks, and is not in "k of N". The header shows "N waiting" (identifier request-deck-waiting). Announcements and focus moves read only the pending requests, so a waiting card gives no announcement.
    - ElicitationURLConsentView: the waiting step comes from the model (owner.awaitingURLCompletions), not from a @State flag, so a card that mounts again for an accepted request shows the waiting step. The browser task is still @State. Text "Waiting for <targetHost> to finish". The waiting step shows Stop waiting (identifier elicitation-stop-waiting, symbol stop.fill) and Retry; Cancel and Decline show only before the press. Stop waiting and Esc in the waiting step stop the browser and call stopWaiting. onDisappear now reports ElicitationBrowserStep.stop, so a hosted test requires the stop in the same render pass and never waits without end.
    - ToolCallView: while an item of awaitingURLCompletions names the tool call (toolCallId), the status is the text "Waiting for <host>" (same identifier tool-call-<id>-waiting, symbol hourglass).
    - AgentCommandTarget class doc: send with a text payload calls SessionModel.startPrompt(text:reporting:) with requestStartReport.
    - Docs: plan.md section 13.3 and Docs/decisions/accessibility.md match the code.
    - Bug card ^rkwj84j: fixed by this card (the accept keeps the card mounted). Test: openInTheDeckKeepsTheBrowserSessionAndBringsTheNextCardToTheFront.

    ### What did not change
    - DeckLayout and layout(requests:front:) are unchanged; the waiting role is set in DeckCards from the awaiting ids.
  timestamp: 2026-10-16T19:19:27.237585+00:00
- actor: claude-code
  id: 01m532fvsckns44kkxkdyxcw43
  text: |-
    ### implement — changed
    - evidence: 11 files. Sources: Elicitation/ElicitationURLConsentView.swift, HumanInTheLoop/RequestDeck.swift, HumanInTheLoop/RequestDeckLayout.swift, HumanInTheLoop/PendingRequestReplies.swift, Items/ToolCallView.swift, Commands/AgentCommandTarget.swift. Tests: Elicitation/ElicitationURLConsentViewHostedTests.swift, Items/ToolCallEntryViewHostedTests.swift, Items/SymbolConceptTests.swift. Docs: plan.md, Docs/decisions/accessibility.md. swift build --build-tests: no error, no warning. RED: swift test --skip-build --filter 'ElicitationURLConsentViewHostedTests|ToolCallEntryViewHostedTests/aCallWhoseURLElicitationWaits|SymbolConceptTests' gave 13 issues in 8 new or changed tests, each at once with no wait. GREEN: the same suites (full ToolCallEntryViewHostedTests) 43 tests in 3 suites passed. Affected suites (RequestDeck*, ThreadAccessibility*, AgentCommands*, AgentCommandScopeHostedTests, PendingRequestsSessionModelHostedTests, PermissionViewHostedTests, ElicitationViewHostedTests, StateBannerPendingRequestsHostedTests, ToolCallViewHostedTests, SessionTranscriptViewHostedTests, DemoGallery, ReadmeCoverageTests and others): 209 tests in 19 suites passed, and 14 tests in 2 suites passed. README.md and Examples are not changed.
    - next: review. Bug card ^rkwj84j is fixed by this card and stays in todo for the step owner.
  timestamp: 2026-10-16T19:19:44.684709+00:00
- actor: claude-code
  id: 01m532j11d5brnkyd05az3n16h
  text: |-
    ### Decisions of the step owner (after implement)
    - Change of the design text: the design said that the card "keeps its @State phase". Accepted change: the waiting state comes from the model (`awaitingURLCompletions`), because the model is the source of the truth. Only the browser task is `@State`. Thus a card that shows again for an accepted request also shows the waiting state.
    - Accepted: when the card goes away, it reports the stop of the browser task (`elicitationBrowserReport`), so a hosted test can require the stop in the same render.
    - Button text: "Stop Waiting" (title case), the same as the other buttons of the card. Changed in ElicitationURLConsentView.swift, the two test files, plan.md and Docs/decisions/accessibility.md.
    - Bug card ^rkwj84j is fixed by this card; it goes to done with this card.
  timestamp: 2026-10-16T19:20:55.597642+00:00
- actor: claude-code
  id: 01m532rbmwj3s56mxgjbhf0z83
  text: |-
    ### test — green
    - evidence: swift build --build-tests finished with exit 0. The build printed one warning, from SwiftPM and not from Sources or Tests of this package: "missing creator for mutated node: .build/out/Products/Debug/mlx-swift_Cmlx.bundle/Contents/MacOS". There is no warning in Sources/ or Tests/.
    - evidence: swift test --skip-build finished with exit 0. The main run had 1264 tests in 147 suites, all passed, with 2 known issues (existing withKnownIssue marks, not failures). Two smaller runs also passed: 127 tests in 16 suites, and 1 test in 1 suite. XCTest runs: 0 tests, 0 failures.
    - evidence: Before the build, no other swift-build --build-tests or swift test of this package was running. Only IDE index builds and processes of other packages were running.
    - evidence: Scripts/check-readme.sh was not run. README.md and Examples/ReadmeSnippets did not change.
    - next: review or commit by the caller. No commit and no push was made.
  timestamp: 2026-10-16T19:24:23.068248+00:00
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCJD70S015GWDGB94APM2
position_column: doing
position_ordinal: '80'
title: 'Elicitation task 41: show the URL elicitation waiting state'
---
elicitation-plan.md task 41: show the waiting state of a URL elicitation after the user gave consent and until the flow ends. Needs ACPAgent task 8 (send URL elicitation complete only when the flow ends); check its state before the work. Do it as the accepted deck design says. Tests with the step 7 rules. Write all text in STE.

## Prerequisites
Needs ACPClient elicitation-plan task 51 and 52 (awaitingURLCompletions/stopWaiting) pushed first. Task 51 is ConnectionModel.frontRequest/bringToFront. Both are done in the ACPClient package by another session, not on this board. ACPAgent task 8 is done (ACPAgent 3a3d67e, see the comment).

Repairs bug card ^rkwj84j (01M51WCGABKMC64K4RPRKWJ84J: the browser session stops when the user accepts a URL request).

## Accepted design
Source: deck design section 7, facts A and B, test plan row 41 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

Fact A: the URL "waiting" state has no data source today. acceptElicitation removes the request from the model, so ModelClient.elicitationComplete (ModelClient.swift:126) finds no match later.

ACPClient prerequisite (task 52):
- After acceptElicitation of a URL elicitation, the model keeps it in public var awaitingURLCompletions: [PendingElicitation] on SessionModel and ConnectionModel.
- It is removed on elicitation/complete (completeElicitation), cancel(meta:), cancelAllPending(), close, and public func stopWaiting(_ id:). ACPAgent 3a3d67e already sends complete only when the flow ends.

The deck:
- Shows the awaiting elicitations as cards in the same ForEach with the same id, after the pending cards, so ElicitationURLConsentView keeps its @State phase and browser task. This repairs fact B.
- They are not in "k of N". The header adds "1 waiting". After the accept, the next pending card comes to the front.
- The waiting card shows "Waiting for <targetHost> to finish" with a progress indicator, and two buttons: Retry (opens the browser again) and Stop waiting (stopWaiting, stops the browser).
- The tool call status shows "Waiting for <host>" while its elicitation is in awaitingURLCompletions.
- No announcement for a URL waiting state (task 37).

Answers:
- Q7 yes for v1: Stop waiting does not tell the agent. Card ^6hnfscd (01M51WCMFZP7V301NFF6HNFSCD) records the need for a later ACP message.

Test plan (row 41). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [x] ACPClient tests for awaitingURLCompletions (in that package, task 52).
- [x] Press Open: elicitation-waiting shows, the next card comes to the front, and the fake presenter is not cancelled.
- [x] The agent sends complete: the card goes away and the fake presenter records a cancel.
- [x] Stop waiting removes the card.
- Waits on awaitingURLCompletions.count and fake.cancelCount (ObservationWait.until on each, then render()).

#elicitation-phase-6