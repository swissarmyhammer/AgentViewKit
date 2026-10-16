---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m52d0awhwmgb7khs9vp8hp8e
  text: |-
    Research done. Facts:
    - The focus-on-appear code is in PermissionView (onAppear moveFocus), ElicitationView and ElicitationURLConsentView (onAppear isFocused = true and moveFocus). After the removal, the moveFocus property and, in the two elicitation views, the @FocusState isFocused have no use. PermissionView keeps isFocused for defaultFocus.
    - RequestDeck.focusTarget(old:new:) is the only focus code of the deck (DeckCards.onChange). Its table test is in PermissionViewHostedTests ("theFocusTargetFollowsTheChange").
    - SessionAnnouncementObserver announces the pending requests with ThreadAccessibility.pendingRequests(of:connection:) and actionRequiredAnnouncements(old:new:). The deck design keeps the public signature of pendingRequests(of:connection:).
    - Tests that this change breaks by design: ThreadAccessibilityHostedTests (the two action-required tests mount only AgentThreadView; the two focus tests expect PermissionView.identifier in the moves), PermissionViewHostedTests (theDeckReportsANewCardThenThePromptEditor), ElicitationViewHostedTests.theFormReportsTheFocusOnAppear, ElicitationURLConsentViewHostedTests.theCardReportsTheFocusOnAppear, RequestDeckHostedTests.sixRequests... (it reads the frames of the edge cards from the accessibility tree, and the "+N" label).
    - Keyboard focus: the cards are .focusable(). The plan is a deck @FocusState on the request id, applied to each card with .focused(_:equals:), set only when the user changes the front. A hosted test can prove it with Escape: onExitCommand of the front card cancels that request.
  timestamp: 2026-10-16T13:04:15.761113+00:00
- actor: claude-code
  id: 01m52ec76t242rvjbqagbv14ft
  text: |-
    Implementation landed (not committed).
    - New file Sources/AgentViewKit/HumanInTheLoop/RequestDeckFocus.swift: DeckFocusMove (.nextFront, .promptEditor, .broughtToFront) and the pure RequestDeck.focusTarget(oldIDs:newIDs:oldFront:newFront:). The old focusTarget(old:new:) and its test are removed.
    - RequestDeck: the deck announces "Action required: <title>" at .high for each new request of its model (ThreadAccessibility.PendingRequestSummary.init(request:) and actionRequiredAnnouncements). One onChange of the ids and the front gives the focus move. A deck @FocusState on the request id, applied to each card with .focused(_:equals:), takes the keyboard focus into the card only for .broughtToFront. Edge and hidden cards get accessibilityHidden(true). The "k of N" text has the label DeckLayout.positionLabel ("Request 1 of 6, 2 more"), and "+N" is hidden from VoiceOver.
    - SessionAnnouncementObserver no longer announces pending requests and has no connection parameter. ThreadAccessibility.pendingRequests(of:connection:) keeps its public signature.
    - PermissionView, ElicitationView, ElicitationURLConsentView: no focus move on appear.
    - Discovery: when ElicitationView and ElicitationURLConsentView lost the onAppear isFocused = true, a card alone in a window had no keyboard focus, so Escape did nothing (escapeSendsCancel tests). I gave the two views .defaultFocus($isFocused, true), the same as PermissionView already has. A default focus applies only when the window has no other focus, so a new card in an app window with a focused composer does not take the keyboard focus. The reviewer can check this choice.
    - Test changes by design: the edge cards are not in the accessibility tree now, so RequestDeckHostedTests.sixRequests... measures the space of the top edges (2 more edges give 2 more steps) and not the frames of the edge cards; the position labels are now "Request k of N[, M more]". Tests that read a card behind the front press Next first. ThreadAccessibilityHostedTests mounts a session deck and a connection deck next to the thread view for the action-required tests.
    - RED evidence: the four new hosted tests failed before the wiring (7 issues); the keyboard test hung before the wiring (Escape reached no card), the shell timeout stopped it.
  timestamp: 2026-10-16T13:28:13.786219+00:00
- actor: claude-code
  id: 01m52ecd9zrn1a7w3e6emr0a5s
  text: |-
    ### implement — changed
    - evidence: swift build --build-tests clean (0 warnings). swift test --skip-build --filter 'RequestDeckAccessibilityHostedTests': 5 tests passed. One run of 17 suites (AgentCommandScopeHostedTests, ElicitationAnswerContentTests, ElicitationURLConsentViewHostedTests, ElicitationViewHostedTests, PendingRequestsSessionModelHostedTests, PermissionViewHostedTests, ReadmeCoverageTests, RequestDeckHostedTests, RequestDeckFocusTests, RequestDeckLayoutTests, StateBannerPendingRequestsHostedTests, SymbolConceptTests, ThreadAccessibilityHostedTests, ThreadAccessibilityTests, ToolCallEntryViewHostedTests, FakesTests, DemoGalleryTests): 169 tests, 1 issue in PendingRequestsSessionModelHostedTests.cancelAllPending... (it read a card behind the front, hidden by design); fixed the test; PendingRequestsSessionModelHostedTests run again: 8 tests passed. PackageStructureTests: 127 tests passed.
    - files: Sources/AgentViewKit/HumanInTheLoop/RequestDeckFocus.swift (new), RequestDeck.swift, RequestDeckLayout.swift, PermissionView.swift, Elicitation/ElicitationView.swift, Elicitation/ElicitationURLConsentView.swift, Elicitation/ElicitationCard.swift, Accessibility/ThreadAccessibility.swift, Thread/AgentThreadView.swift, Docs/decisions/accessibility.md; tests RequestDeckFocusTests.swift (new), RequestDeckAccessibilityHostedTests.swift (new), RequestDeckLayoutTests, RequestDeckHostedTests, PermissionViewHostedTests, PendingRequestsSessionModelHostedTests, ThreadAccessibilityHostedTests, ElicitationViewHostedTests, ElicitationURLConsentViewHostedTests.
    - next: /review. Task stays in doing. Not committed.
  timestamp: 2026-10-16T13:28:20.031967+00:00
- actor: claude-code
  id: 01m52en4ta6hxfn8srnqxqzr6n
  text: |-
    ### test — green
    - evidence: `swift build --build-tests` finished with Build complete. No warning in Sources/ or Tests/ of this package. The build tool printed one line: "warning: missing creator for mutated node: .../mlx-swift_Cmlx.bundle/Contents/MacOS". It comes from the build system and the mlx-swift dependency bundle. It names no file in this package.
    - evidence: `swift test --skip-build` exit 0. Swift Testing: 1245 tests in 145 suites passed, 0 failed, 0 skipped, 2 known issues. Known issues: aWrappedTextWithAFixedVerticalSizeFails (HostedLayoutExpectationsTests) and aViewThatIgnoresTheThemeFails (ThemeHeightExpectationsTests). Both are withKnownIssue marks that existed before. XCTest: 0 tests, 0 failures.
    - evidence: README.md and Examples/ReadmeSnippets are not in `git status`. Scripts/check-readme.sh was not run.
    - next: none. No code was changed. No commit and no push.
  timestamp: 2026-10-16T13:33:06.250157+00:00
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCCSP0GHTT66H046ZHH46
position_column: doing
position_ordinal: '80'
title: 'Elicitation task 37: do not move focus to new cards; announce them'
---
elicitation-plan.md task 37, section 4: a new card does not take the focus; a screen reader announces it; only the front card is available to VoiceOver. Do it as the accepted deck design says. Tests with the step 7 rules (RecordingAnnouncer is @Observable). Write all text in STE.

## Accepted design
Source: deck design section 4, part of section 8, test plan row 37 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

Focus:
- A new card does not take the VoiceOver focus or the keyboard focus. Remove the focus-on-appear code at PermissionView.swift:179, ElicitationView.swift:154-156 and ElicitationURLConsentView.swift:154-156.
- The deck moves focus (AccessibilityFocusMove) only when:
  1. the old front left the deck: to pending-card-<new front>, or to prompt-editor when the deck is empty;
  2. the user changed the front (Previous, Next, a key, the tool call status): to the new front card, and the keyboard focus goes into it.
- A pure RequestDeck.focusTarget(oldIDs:newIDs:oldFront:newFront:) replaces PendingRequestsHost.focusTarget(old:new:).
- Only the front card is in the accessibility tree. Edge cards and hidden cards get accessibilityHidden(true). The header and "+N" are one element ("Request 1 of 6, 2 more").

Announcements:
- The deck announces each new request "Action required: <title>" at .high. This boundary moves from SessionAnnouncementObserver (ThreadAccessibility.swift:438-440) into the deck, so each deck announces its own model, and the connection deck announces the connection requests.
- Remove the pending-request part of SessionAnnouncementObserver.
- AgentThreadView keeps the end of a prompt's work and a tool result. ElicitationView keeps "answer not accepted" at .high. Still four boundaries.
- No announcement for Previous, Next, a withdrawn request or a URL waiting state.

Docs: Docs/decisions/accessibility.md focus and announcement sections; the doc comments of ElicitationCard and ElicitationURLConsentView.

Answers:
- Q2 yes: the deck announces each new request, so each request is announced one time.
- Q9 yes: keep .high for each new request.

Test plan (row 37). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [x] focusTarget table test.
- [x] A new request gives one "Action required: …" at .high, and RecordingFocusReporter records no move.
- [x] An answer to the front of two requests moves the focus to the second card. An answer to the last one moves the focus to prompt-editor.
- [x] Cards behind the front are not in the accessibility tree.
- [x] The thread and the deck with two requests give exactly two announcements.
- Waits: render(when: announcer.announcements.count == 1) (RecordingAnnouncer is @Observable); ObservationWait.until { count == 1 }, then render().

#elicitation-phase-6