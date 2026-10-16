---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m522ymdgqra1spmaqawgryez
  text: |-
    Research (card 35).
    - AgentThreadView mounts PendingRequestsHost(session:) in its content VStack. PendingRequestsHost (card 34 form, not committed) is a thin wrapper of RequestDeck plus a public focusTarget(old:new:) that forwards to the internal RequestDeck.focusTarget(old:new:). The internal one stays until card 37.
    - Other users of PendingRequestsHost: ElicitationURLConsentViewHostedTests (thePendingHostShowsTheConsentCardForAURLRequest), PermissionViewHostedTests.theThreadViewShowsThePendingCards (it asserts the behavior that this card removes; it becomes the new test "the thread view shows no pending-card-*").
    - Doc mentions: AgentThreadView doc, RequestDeck doc ("until the thread view stops that"), ElicitationCard doc, ThreadAccessibility doc of the accessibility summary, PromptInputView focus comment, README Components, plan.md §9 inventory and two plan.md prose lines (§12 auth/login, §13), Docs/decisions/accessibility.md. comparison.md is an analysis snapshot with file:line references; it stays as a record.
    - Tests that reach a card through the thread view: ThreadAccessibilityHostedTests theFocusMovesToTheCardThenBackToThePromptEditor and theThreadViewMovesTheFocusOfTheMoverOfTheHost; AgentCommandScopeHostedTests.mount (approve test). The action-required announcement tests read SessionAnnouncementObserver of the thread, not a card, so they need no deck until card 37.
    - StateBannerPendingRequestsHostedTests mounts only StateBanner(session:). It does not mount the thread view and reads no card. Removing the host from the thread does not change it, so it needs no port.
    - The demo feature sources are not in the SwiftPM package; they build only with xcodebuild (Examples/AgentViewKitDemo/AgentViewKitDemo.xcodeproj). The demo UI tests read no pending-card identifier.
  timestamp: 2026-10-16T10:08:34.224725+00:00
- actor: claude-code
  id: 01m523z14jt8tsgqxqa89egtts
  text: |-
    Implementation notes (card 35).

    What landed:
    - AgentThreadView: the PendingRequestsHost(session:) line is gone. The doc says that the view shows no request card, and shows the mounting VStack { AgentThreadView; RequestDeck(session:); PromptInputView }.accessibilityFocusScope(). The thread view keeps its own accessibilityFocusScope(): the linked elicitation forms in tool call rows (until card 38) still read a mover, and the scope does nothing when the app gives one.
    - PendingRequestsHost.swift is deleted, with its public focusTarget(old:new:). The internal RequestDeck.focusTarget(old:new:) stays for the deck until card 37.
    - Doc references to PendingRequestsHost now name RequestDeck: RequestDeck doc (the "until the thread view stops that" paragraph is replaced), ElicitationCard doc, ThreadAccessibility.pendingRequests doc, AccessibilityFocusMover and accessibilityFocusScope() docs, the PromptInputView focus comment and its mounting example, Docs/decisions/accessibility.md focus section, plan.md (§9 AgentThreadView line, §9 inventory line removed, §12 auth/login line, §13 line), README (intro, AgentThreadView component line, PendingRequestsHost component line removed). comparison.md stays as it is: it is an analysis record with file:line references.
    - README ACPThread snippet: VStack { AgentThreadView; RequestDeck(session:); PromptInputView(text: $draft) {} } with accessibilityFocusScope() and the two environment models; a @State draft. Scripts/extract-readme-snippets.sh was run (ACPQuickStart.swift changed; HostApp.swift has only the card 34 change).
    - Demo: SessionThreadColumn has RequestDeck(session:) between ContextUsageView and the composer, and accessibilityFocusScope() on its VStack. ACPTabView detail is a VStack with RequestDeck(connection:) (while an agent exists, so also during the sign-in card) over the old content (now detailContent). GalleryTabView .opened detail is a VStack with RequestDeck(connection:) over SessionThreadColumn.
    - Tests: PermissionViewHostedTests.theThreadViewShowsThePendingCards asserted the behavior that this card removes; it is now theThreadViewWithAPendingPermissionShowsNoPendingCard (RED seen first: one pending-card-<id> and permission-card were found; GREEN after the removal). ThreadAccessibilityHostedTests: new helper threadAndDeck(of:); theFocusMovesToTheCardThenBackToThePromptEditor and the host-mover test (renamed theThreadAndTheDeckMoveTheFocusOfTheMoverOfTheHost) mount thread + deck in one scope. AgentCommandScopeHostedTests.mount adds RequestDeck(session:) and one scope. StateBannerPendingRequestsHostedTests.mount now shows thread + deck in one scope (the thread view holds the StateBanner), window height 640. ElicitationURLConsentViewHostedTests: thePendingHostShowsTheConsentCardForAURLRequest is now theDeckShowsTheConsentCardForAURLRequest on RequestDeck(session:).

    Discoveries:
    - The action-required announcement tests of ThreadAccessibilityHostedTests read SessionAnnouncementObserver of the thread view, not a card, so they pass with the thread alone until card 37 moves that boundary.
    - The demo feature sources are not in the SwiftPM package. I built them with the generator and xcodebuild build (DerivedData under .build/examples/AgentViewKitDemo), not with Scripts/test-examples.sh, so no UI test ran.
  timestamp: 2026-10-16T10:26:15.826603+00:00
- actor: claude-code
  id: 01m523zdbkdjqgk5t0ca4yr6xj
  text: |-
    ### implement — changed
    - note: the research comment said that StateBannerPendingRequestsHostedTests needs no port. That is replaced: its mount now shows thread + deck in one scope, as the card says.
    - card 35 files only: Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift, Sources/AgentViewKit/Elicitation/ElicitationCard.swift, Sources/AgentViewKit/Input/PromptInputView.swift, Docs/decisions/accessibility.md, Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/{SessionThreadColumn,ACPTabView,GalleryTabView}.swift, Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift, Tests/AgentViewKitTests/Status/StateBannerPendingRequestsHostedTests.swift.
    - shared with card 34 (card 35 hunks): Sources/AgentViewKit/HumanInTheLoop/PendingRequestsHost.swift (deleted), RequestDeck.swift (the AgentThreadView paragraph of the type doc), README.md (intro, ACPThread snippet, AgentThreadView line, PendingRequestsHost line removed), plan.md (§9 AgentThreadView line, PendingRequestsHost line removed, §12 auth/login, §13), ThreadAccessibilityHostedTests.swift (threadAndDeck helper, two focus tests), AgentCommandScopeHostedTests.swift (mount and its doc), PermissionViewHostedTests.swift (thread test becomes the no-pending-card test). Card 34 only: HostApp.swift snippet, PendingRequestsSessionModelHostedTests.swift.
    - evidence: RED one run of PermissionViewHostedTests/theThreadViewWithAPendingPermissionShowsNoPendingCard: 2 issues (pending-card-<id> and permission-card found). swift build --build-tests: 0 errors, 0 warnings. One filtered run (PermissionViewHostedTests, ThreadAccessibilityHostedTests, AgentCommandScopeHostedTests, ElicitationURLConsentViewHostedTests, StateBannerPendingRequestsHostedTests, DemoGalleryTests, SessionTranscriptViewHostedTests, ToolCallEntryViewHostedTests, ReadmeCoverageTests): 96 tests in 8 suites passed, and 12 tests in ReadmeCoverageTests passed. After the StateBanner port, one run of StateBannerPendingRequestsHostedTests: 7 tests passed. Scripts/check-readme.sh: passed. Demo: generate_xcodeproj.rb + xcodebuild -scheme AgentViewKitDemo build: BUILD SUCCEEDED, no warning in the changed files. No full suite run, no commit.
    - next: /review.
  timestamp: 2026-10-16T10:26:28.339553+00:00
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BC7WBQ93BAV1Q42Z2XGTQ
position_column: doing
position_ordinal: '8280'
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
- [x] AgentThreadView with a pending permission shows no pending-card-*.
- [x] Update ThreadAccessibilityHostedTests, AgentCommandScopeHostedTests and StateBannerPendingRequestsHostedTests to mount the thread and the deck in one scope.
- [x] DemoGalleryTests stays green.
- Waits: render() after a main-actor change; render(when: !pendingRequests.isEmpty) after the agent sends a request.

#elicitation-phase-6