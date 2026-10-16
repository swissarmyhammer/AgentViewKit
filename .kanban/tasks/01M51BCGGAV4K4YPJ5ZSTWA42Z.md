---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m52g1q10m8vp8jfrhzvbsnpp
  text: |-
    Research and implementation notes:
    - SessionModel.bringToFront(toolCall:) is in FoundationModelsACPClient (SessionModel+Front.swift). It sets frontRequestID to the oldest linked pending elicitation. It is @discardableResult.
    - AgentThreadView sets the sessionModel environment through ConversationView, so the status shows in the thread rows. ToolCallView alone with no sessionModel shows no status (test aCallWithNoSessionModelInTheEnvironmentShowsNoWaitingStatus).
    - LinkedElicitations became ToolCallWaitingStatus: one borderless button, Label "Waiting for your answer" with SharedSymbol.question, hint "Shows the question", identifier tool-call-<id>-waiting (ToolCallView.waitingIdentifier(for:)). The link check with assertionFailure plus log stays. elicitationsIdentifier(for:) and elicitationsSuffix are removed. No other caller used them.
    - The row keys are already "tool-call-<id>", so the identifier is "tool-call-tool-call-<id>-waiting". This is the existing convention of all ToolCallView identifiers.
    - Docs updated: ToolCallView doc, ElicitationCard doc, plan.md (pending requests of elicitations), Docs/decisions/accessibility.md (label line and the defaultFocus result).

    Coordinator item (defaultFocus of card 37): hosted tests CAN observe it. Two tests in RequestDeckAccessibilityHostedTests:
    1. aNewCardDoesNotTakeTheKeyboardFocusFromThePromptEditor: deck plus PromptInputHost in one focus scope; the NSTextView of the prompt editor is the first responder; a form elicitation card arrives; the first responder is still that text view. Passed.
    2. aCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt: the elicitation is pending before the window mounts; Escape goes to the card (onExitCommand), the model cancels on the main actor (try #require before the wait for the answer), and the agent gets {"action": "cancel"}. Passed.
    Test 2 shows that defaultFocus runs in a hosted window: no other code gives the card the keyboard focus in that test. Thus test 1 is not vacuous. No manual check item is necessary.
  timestamp: 2026-10-16T13:57:26.688052+00:00
- actor: claude-code
  id: 01m52g1vahk9j8fjeez9hejwtc
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Items/ToolCallView.swift, Sources/AgentViewKit/Elicitation/ElicitationCard.swift, Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift, plan.md, Docs/decisions/accessibility.md. RED: swift test --skip-build --filter 'ToolCallEntryViewHostedTests|RequestDeckAccessibilityHostedTests' gave 4 failed tests (6 issues) for the missing status. GREEN: swift build --build-tests (0 errors, 0 warnings); swift test --skip-build --filter 'ToolCallEntryViewHostedTests|ToolCallViewHostedTests|RequestDeck|ThreadAccessibilityHostedTests|Elicitation\w*HostedTests|PendingRequestsSessionModelHostedTests' gave 122 tests in 11 suites passed; swift test --skip-build --filter 'PackageStructureTests' gave 127 tests in 16 suites passed. README.md and Examples/ReadmeSnippets did not change, so check-readme.sh did not run.
    - next: review
  timestamp: 2026-10-16T13:57:31.090001+00:00
- actor: claude-code
  id: 01m52gaz8m5j0vn9ktc1wa8q5f
  text: |-
    ### test — green
    - evidence: `swift build --build-tests` finished with Build complete. It gave one warning, and it is not in Sources/ or Tests/. The warning is from the build system: "missing creator for mutated node: .build/out/Products/Debug/mlx-swift_Cmlx.bundle/Contents/MacOS". The warnings in Sources/ and Tests/ of this package: 0.
    - evidence: `swift test --skip-build` exited 0. The Swift Testing runs were: 1 test in 1 suite passed; 127 tests in 16 suites passed; 1250 tests in 145 suites passed with 2 known issues. XCTest: 0 tests, 0 failures. Failures: 0. Skipped tests: 0.
    - evidence: The 2 known issues are the existing withKnownIssue marks. They are aWrappedTextWithAFixedVerticalSizeFails() in HostedLayoutExpectationsTests and aViewThatIgnoresTheThemeFails() in ThemeHeightExpectationsTests. Both tests passed.
    - evidence: git status shows no change to README.md or Examples/ReadmeSnippets. Scripts/check-readme.sh was not run.
    - next: review.
  timestamp: 2026-10-16T14:02:30.036962+00:00
- actor: claude-code
  id: 01m52gpwark082ghjcr435sjej
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD — engine counts: 2 findings, 2 confirmed, 3 refuted. Driver check of the two new focus tests: 1 more finding. Open: Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift:406, Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift:457, Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift:147. The test aNewCardDoesNotTakeTheKeyboardFocusFromThePromptEditor proves its claim: it makes the editor the first responder before the card arrives, waits with ObservationWait.until on the request count and then render(), and asserts that the form is present.
    - next: implement the 3 open findings, then review again.
  timestamp: 2026-10-16T14:09:00.248759+00:00
- actor: claude-code
  id: 01m52gqms95zyxzwsb1gz13y7e
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 6 files (ToolCallView.swift, ElicitationCard.swift, ToolCallEntryViewHostedTests.swift, RequestDeckAccessibilityHostedTests.swift, plan.md, accessibility.md)
    - test: green — swift test --skip-build, 1250 tests in 145 suites passed, 2 known issues
    - commit: c7047d3
    - review: findings — Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift:406, Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift:457, Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift:147
  timestamp: 2026-10-16T14:09:25.289021+00:00
- actor: claude-code
  id: 01m52hjykc6nec4n6gfdweb56t
  text: |-
    Fix of the 3 review findings (2026-10-16):
    - Finding 1 (reuse): ScriptedSessionRequests now has ScriptedSession.AgentRequest (method, id, params; factories formElicitation(id:) and permission(id:)) and sendInOrder(_:). sendInOrder sends each request only after the model holds one more pending request. These use it: ToolCallEntryViewHostedTests.sendCall, RequestDeckHostedTests.sendRequests, the focus test of RequestDeckAccessibilityHostedTests, and the existing helpers sendPermissionRequest(id:rendering:), receivePermissionRequest(id:params:) and receiveElicitation(id:params:) in the same file. The linkedElicitation and linkedPermission factories are now an extension of ScriptedSession.AgentRequest in ToolCallEntryViewHostedTests. In that file, receiveCall(_:id:in:) is the one copy of "send the update, wait for the entry"; showExpandedCall and sendCall use it. ActivityTimelineHostedTests.sendCall sends no request, so it has no request loop to share.
    - Finding 2 (cancel path): new test aCancelOfTheLinkedCardRemovesTheWaitingStatus(exit:) with two arguments: the Cancel button of the card, and SessionModel.cancelAllPending(). Each waits for the agent result {"action": "cancel"}, then ObservationWait.until { pendingRequests.isEmpty }, render(), and asserts that tool-call-<id>-waiting is gone. A helper showWaitingCall(_:in:harness:) is shared with the answer test. I did not use Esc in the thread and deck window, because the keyboard focus there is not certain (see below).
    - Finding 3 (defaultFocus proof): a hosted test CANNOT prove that defaultFocus gives the focus. Evidence, one run each:
      1. PermissionView with .defaultFocus removed: the card-alone test (permission card, first responder in the hosting view and not a text view) PASSED. A card alone is the only focusable view, so the window gives it the focus with no defaultFocus.
      2. A focusable Color.clear view before the deck, URL consent card, .defaultFocus removed: Esc did not cancel (FAILED as expected).
      3. The same test with .defaultFocus present: also FAILED. The view before the deck keeps the focus. Thus defaultFocus on the card does not change the first focus of a hosted window.
      Both temporary source edits are reverted (git diff of Sources/ is empty). The test aCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt now uses the URL consent card (no editable field; Esc cancels on the main actor, so a lost focus fails the try #require and cannot hang), and asserts before Esc that the first responder is a view in the hosting view and not an NSText or NSTextField. Its comment and Docs/decisions/accessibility.md no longer claim that it proves defaultFocus. The card has a new "- [ ] Manual:" check item for the default focus.
    - Discovery: result 3 suggests that `.defaultFocus($isFocused, true)` on a card has no effect when another focusable view comes first in the window. The manual check must find out if this is also true in the app.
  timestamp: 2026-10-16T14:24:20.076748+00:00
- actor: claude-code
  id: 01m52hk8bajf76nve4daa56qfx
  text: |-
    ### implement — changed
    - evidence: 5 files — Tests/AgentViewKitTests/Helpers/ScriptedSessionRequests.swift, Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift, Docs/decisions/accessibility.md. No change in Sources/. `swift build --build-tests`: Build complete, 0 errors; the one warning is the build-system mlx bundle warning, not in Sources/ or Tests/. `swift test --skip-build --filter 'ToolCallEntryViewHostedTests|RequestDeckHostedTests|RequestDeckAccessibilityHostedTests|AgentCommandScopeHostedTests|PermissionViewHostedTests|ThreadAccessibilityHostedTests|ElicitationURLConsentViewHostedTests|PendingRequestsSessionModelHostedTests|AgentCommandsTests|ElicitationViewHostedTests|ThreadAccessibilityTests'`: 162 tests in 11 suites, 161 passed, 1 failed (the decoy defaultFocus test, which showed that a hosted test cannot prove defaultFocus; removed). After the change: `swift test --skip-build --filter 'RequestDeckAccessibilityHostedTests'`: 7 tests in 1 suite passed. All 3 findings are checked; a new "- [ ] Manual:" item is open for the default focus.
    - next: review
  timestamp: 2026-10-16T14:24:30.058868+00:00
- actor: claude-code
  id: 01m52j0pq4ch3a8tvxqsa6q0gp
  text: |-
    Step owner decision (2026-10-16): remove the `.defaultFocus($isFocused, true)` of card 37 from the elicitation cards.
    - `git show d9ad793` shows that card 37 added `.defaultFocus($isFocused, true)` to ElicitationView and ElicitationURLConsentView. Before card 37, `onAppear { isFocused = true }` used the focus state. Card 37 removed that onAppear. PermissionView already had `.defaultFocus` before card 37, and it did not change in this step.
    - After the removal, `@FocusState isFocused` and `.focused($isFocused)` had no other read or write in the two views. The focus move of card 37 for a card brought to the front uses `keyboardFocus` of DeckCards, with `.focused(keyboardFocus, equals: request.id)` on the DeckCard. It does not use `isFocused`. Thus `isFocused` and `.focused($isFocused)` were dead code, and I removed them. `.focusable()`, `.focusEffectDisabled()` and `.onExitCommand` stay.
    - No test failed without the modifier: the six suites passed (89 tests). Thus I found no case where the modifier is necessary.
    - Text: ElicitationURLConsentView doc comment, Docs/decisions/accessibility.md (Focus section), and the comment before the focus tests in RequestDeckAccessibilityHostedTests no longer say that a card takes the focus as the default focus. accessibility.md says that PermissionView keeps its `defaultFocus`. The ElicitationView, ElicitationCard and RequestDeck doc comments did not mention defaultFocus, so they did not change.
    - The "- [ ] Manual:" item stays open. Its old text told the tester to remove `.defaultFocus` from the card, and that modifier is now gone. The new text asks the tester to record the first keyboard focus in the app window and to make sure that a card brought to the front gets the keyboard focus and that Esc cancels the request.
    - Not done: I did not read the full validator dump (754,249 characters, 12,098 lines). The change removes code and changes text only.
  timestamp: 2026-10-16T14:31:50.756722+00:00
- actor: claude-code
  id: 01m52j0t5sfvn6z5dqxw3wqe5v
  text: |-
    ### implement — changed
    - evidence: 4 files in this step — Sources/AgentViewKit/Elicitation/ElicitationView.swift, Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift, Docs/decisions/accessibility.md, Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift (comment only), plus the task description. The iteration 1 fixes in the working tree are kept. `swift build --build-tests`: Build complete; the one warning is the build-system mlx bundle warning, not in Sources/ or Tests/. One `swift test --skip-build --filter` run each: RequestDeckAccessibilityHostedTests 7 passed, ElicitationViewHostedTests 25 passed, ElicitationURLConsentViewHostedTests 16 passed, RequestDeckHostedTests 6 passed, ThreadAccessibilityHostedTests 14 passed, PermissionViewHostedTests 21 passed (89 tests, 0 failures).
    - next: review
  timestamp: 2026-10-16T14:31:54.297951+00:00
- actor: claude-code
  id: 01m52j9dr3e0ynbqd0mhv0hgth
  text: |-
    ### test — green
    - evidence: `swift build --build-tests` completed with no warning in Sources/ or Tests/. One build-system line: "warning: missing creator for mutated node ... mlx-swift_Cmlx.bundle/Contents/MacOS". It is not in the code of this package.
    - evidence: `swift test --skip-build` ran one time. Swift Testing: 1251 tests in 145 suites passed, 0 failures. XCTest: 0 tests, 0 failures. 0 skipped.
    - evidence: 2 known issues. They are the existing withKnownIssue marks: aWrappedTextWithAFixedVerticalSizeFails and aViewThatIgnoresTheThemeFails. They are not failures.
    - evidence: README.md and Examples/ReadmeSnippets did not change, so Scripts/check-readme.sh did not run.
    - note: Before the build, pgrep found swift-build processes for other packages. One process (pid 86126) built a dependency checkout under AgentViewKit/.build/index-build with its own scratch path (IDE index build). It was not a build of this package, so the build and the test ran.
    - next: review
  timestamp: 2026-10-16T14:36:36.483223+00:00
- actor: claude-code
  id: 01m52jw14fhb53y0150t3yj6yx
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (35f74ca). Engine: 0 findings, 7 attempted, 1 refuted. The 3 prior items are fixed in the code: ScriptedSession.sendInOrder(_:) is shared by sendCall, sendRequests, and the receive helpers; aCancelOfTheLinkedCardRemovesTheWaitingStatus covers the Cancel button and cancel-all; the lone-card test uses the URL consent card and asserts the first responder before Esc. 3 driver-check findings (asked for by the caller): Docs/decisions/accessibility.md:115, Docs/decisions/accessibility.md:118, Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift:41.
    - focus check: by the code, an elicitation card still gets the keyboard focus when the deck brings it to the front (DeckCard `.focused(keyboardFocus, equals: request.id)` on ElicitationCard, `.focusable()` stays on both views). No hosted test proves this for an elicitation card.
    - next: fix the 3 open items in the 2026-10-16 09:37 section. The Manual item is a check for a person and is not a review finding.
  timestamp: 2026-10-16T14:46:46.159085+00:00
- actor: claude-code
  id: 01m52jwv4qwk816a34qewnrkzz
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — fixed the 3 iteration 1 findings; removed .defaultFocus and the dead @FocusState from ElicitationView and ElicitationURLConsentView (decision of the step owner)
    - test: green — swift test --skip-build, 1251 tests in 145 suites passed, 2 known issues
    - commit: 35f74ca
    - review: findings — Docs/decisions/accessibility.md:115, Docs/decisions/accessibility.md:118 (and Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift:145), Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift:41
  timestamp: 2026-10-16T14:47:12.791570+00:00
- actor: claude-code
  id: 01m52k6qd5mvdbnd8pxne6b2ja
  text: |-
    Fix of the 3 review findings of 2026-10-16 09:37:
    - Finding 1 and 2 (Docs/decisions/accessibility.md, Focus section): the text no longer says "A window gives the keyboard focus to its first focusable view" or "a card alone in a window gets the keyboard focus" as a rule for all cards. It now says: the kit gives a new card no keyboard focus; AppKit decides the first keyboard focus of a window; hosted tests show that in a window with only a URL consent card (no text field) a view of the card gets the keyboard focus and Esc cancels; a new card does not take the keyboard focus from a prompt editor that has it; no test shows the first keyboard focus for a card with a text field or for a window with other focusable views; the manual check records it. The same cause was in the comment before the focus tests in RequestDeckAccessibilityHostedTests ("not a text field in it", "a focusable view before the deck keeps it"). That comment now says the same as the doc. The test name aCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt also made a claim for all cards, so it is now aURLConsentCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt. No other file had the claim (rg outside .kanban and .build).
    - Finding 3: new hosted test nextMovesTheKeyboardFocusIntoAnElicitationCardSoEscapeCancelsOnlyIt. It sends a permission request and then a URL consent elicitation with ScriptedSession.sendInOrder(_:), renders, presses Next, requires frontRequestID == the elicitation id, expects the VoiceOver move to the elicitation card, sends Esc, requires (after the one render of sendKey) that pendingElicitations is empty, then waits for the agent result (certain after the cancel), expects {"action": "cancel"}, and expects that the permission stays pending. If Esc reached no card, the try #require fails and the test does not wait. The test PASSED on its first run: the deck gives the URL consent card the keyboard focus after Next. No source code changed for it. It is a proof test of behavior that exists, so it did not fail first.
    - New helper urlConsent(id:) in the suite: the two URL consent tests use it, so the request is not built two times.
    - The accessibility.md bring-to-front bullet and the ElicitationURLConsentView doc comment now name what the tests show (Next, then Esc cancels the request of the card).
    - The "- [ ] Manual:" item did not change.
  timestamp: 2026-10-16T14:52:36.645115+00:00
- actor: claude-code
  id: 01m52k6tgfwb4vy9znrzgft3be
  text: |-
    ### implement — changed
    - evidence: 3 files — Docs/decisions/accessibility.md, Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift (doc comment only), Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift. `swift build --build-tests`: Build complete; the one warning is the build-system mlx bundle warning, not in Sources/ or Tests/. One run each: `swift test --skip-build --filter RequestDeckAccessibilityHostedTests` 8 tests in 1 suite passed; `swift test --skip-build --filter ElicitationURLConsentViewHostedTests` 16 tests in 1 suite passed. The 3 findings of 09:37 are checked; the Manual item stays open.
    - next: review
  timestamp: 2026-10-16T14:52:39.823914+00:00
- actor: claude-code
  id: 01m52kgsxw98c58fghr36402r3
  text: |-
    ### test — green
    - evidence: No other build of this package was active. The swift-build processes found were IDE index builds and other packages.
    - `swift build --build-tests`: Build complete. Zero warnings in Sources/ or Tests/. One build-system message: "warning: missing creator for mutated node: .build/out/Products/Debug/mlx-swift_Cmlx.bundle/Contents/MacOS". It comes from the Cmlx dependency bundle, not from this package.
    - `swift test --skip-build`: 1252 tests in 145 suites passed, 0 failed, 0 skipped. 2 known issues (existing withKnownIssue marks, not failures). The suite RequestDeckAccessibilityHostedTests passed, with the new hosted test.
    - `Scripts/check-readme.sh`: not run. README.md and Examples/ReadmeSnippets did not change.
    - Nothing was committed or pushed. No code was changed.
    - next: review
  timestamp: 2026-10-16T14:58:06.908899+00:00
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCEHVNTKRD8YY4WZMKDF5
position_column: doing
position_ordinal: '80'
title: 'Elicitation task 38: replace the inline elicitation form with a status that brings its card to the front'
---
elicitation-plan.md task 38, section 4: a tool call shows only "Waiting for your answer"; a click brings its card to the front (ACPClient bringToFront(toolCall:)); there is no second inline form in ToolCallView. Do it as the accepted deck design says. Tests with the step 7 rules. Write all text in STE.

## Accepted design
Source: deck design section 5, part of section 8, test plan row 38 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

What to build:
- LinkedElicitations (ToolCallView.swift:317, :584) becomes ToolCallWaitingStatus: one button "Waiting for your answer" with a question symbol. It shows when entry.linkedElicitationIDs links a pending elicitation. No form in the row. Label "Waiting for your answer", hint "Shows the question".
- The press calls session.bringToFront(toolCall: entry). The deck then moves the focus (task 37).
- With no sessionModel in the environment, no status. If the app shows no deck, the press has no visible effect. The docs say so.
- Identifier tool-call-<id>-waiting replaces elicitationsIdentifier(for:).
- Task 39 (who asks) will go into the card headers (ElicitationHeader, the PermissionView header). It changes nothing in the deck.

What goes away:
- LinkedElicitations and ToolCallView.elicitationsIdentifier(for:) (ToolCallView.swift:246).

Inline forms in a tool call row today (read-only check of Sources/AgentViewKit/Items/ToolCallView.swift and Sources/AgentViewKit/Items/ToolCallPart.swift):
- Inline ELICITATION form: YES. ToolCallView.swift:317 mounts LinkedElicitations(entry:). LinkedElicitations (ToolCallView.swift:584-631) shows an ElicitationCard(request:owner:) for each linked pending elicitation (:600), in a container with elicitationsIdentifier(for:) (:603). The doc comment at ToolCallView.swift:76-79 says this. Remove it as above.
- Inline PERMISSION form: NO. Neither file has a PermissionView, an approve or reject control, or a read of pendingPermissions. Thus there is nothing more to remove for permissions.

Answers:
- Q8 yes: no tool call status for a pending permission now (bringToFront(toolCall:) links only elicitations). Rule: remove any inline permission form in a tool call row, if one exists today, so that the deck is the only place to answer. The check above found none. If one comes into these files before this task starts, remove it in this task.

Test plan (row 38). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [x] A linked tool call shows tool-call-<id>-waiting and no form.
- [x] Press: frontRequestID is the linked id, the header shows its position, and the last focus move is to its card.
- [x] Answer: the status goes away.
- [x] No tool call row shows an inline form for a permission or an elicitation.
- [x] Step owner decision: remove the `.defaultFocus($isFocused, true)` that card 37 (d9ad793) added to ElicitationView and ElicitationURLConsentView. Nothing proves that it helps. Keep PermissionView as it was before card 37. Remove `@FocusState isFocused` and `.focused($isFocused)` if they have no other use. Update Docs/decisions/accessibility.md and the doc comments so that they say only what the code does.
- [ ] Manual: in the demo app, show the thread, the deck, and the prompt editor in one window. Let a pending elicitation card appear, and do not click a view. Record which view has the keyboard focus. The elicitation cards have no `defaultFocus`, so the window gives the keyboard focus to its first focusable view. Then bring the card to the front with the "Waiting for your answer" status or with Next, and make sure that the card gets the keyboard focus and that Esc cancels the request. A hosted test cannot prove the first keyboard focus of the app window (see the comments of 2026-10-16 on this card).
- Waits: render(when: !pendingRequests.isEmpty) for the linked request; render() after the press; ObservationWait.until { pendingRequests.isEmpty } after the answer, then render().

#elicitation-phase-6

## Review Findings (2026-10-16 09:03)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 6 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `Docs/decisions/accessibility.md` — no validator matches this file
> - `plan.md` — no validator matches this file

- [x] `Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift:406` `reuse/reuse` — The sendCall helper repeats the send-then-wait pattern of other hosted test helpers in the same suite family. Its loop of sending a request and waiting for the pending count is a copy of the sendRequests and ActivityTimelineHostedTests.sendCall pattern, and it is not shared. Move the shared send-and-wait steps into one helper in ScriptedSessionRequests, and call it from sendCall and the other helpers. Keep the call-specific update in each caller.
- [x] `Tests/AgentViewKitTests/Items/ToolCallEntryViewHostedTests.swift:457` `completeness/inverse-operation-coverage` — The test proves that answering a linked elicitation in the deck removes the 'Waiting for your answer' status. It does not prove the other exit of the same link: a linked elicitation that the user cancels (for example with Escape, or through cancel-all) must also remove the status. If the cancel path leaves the link or the status behind, the row keeps a dead button that points to a card that no longer exists. Add one hosted test in this suite. Send a call with a linked elicitation, press Escape on the deck card (or cancel all), wait until `model.pendingRequests.isEmpty`, render, and assert `harness.element(identifier: ToolCallView.waitingIdentifier(for: key)) == nil`.
- [x] `Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift:147` `tests/proves-its-claim` (driver check of the focus tests, asked for by the caller) — The test `aCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt` does not prove that `defaultFocus` gives the card the keyboard focus. It uses `formElicitationParams`, and that form has an editable `name` text field. `HostedViewHarness` calls `window.makeKeyAndOrderFront(nil)` with no `initialFirstResponder`, so AppKit can make the `name` field the first responder. Escape from that field goes up the responder chain to the `onExitCommand` of `ElicitationView`, and the request cancels. Thus the test can pass when `.defaultFocus($isFocused, true)` is removed. The test also does not assert where the first responder is before Escape. Use a card with no editable field (a permission request with `ScriptedSession.permissionParams`, whose `PermissionView` also uses `defaultFocus` and `onExitCommand`), or assert before Escape that `harness.window.firstResponder` is not an editable text view or field editor. Then the test fails when `defaultFocus` does not give the focus.

## Review Findings (2026-10-16 09:37)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 6 file(s) reviewed, 5 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `Docs/decisions/accessibility.md` — no validator matches this file

> Engine: 0 findings (7 attempted, 1 refuted). The 3 items below are driver checks that the caller asked for (focus after the removal, and docs that say only what the code does). No validator rule produced them.

- [x] `Docs/decisions/accessibility.md:115` `driver-check/docs-match-code` — The Focus section says "A window gives the keyboard focus to its first focusable view. Thus a card alone in a window gets the keyboard focus, and a focusable view before the deck keeps the keyboard focus." No code in the kit does this, and no test proves it: the open Manual item of this task says that a hosted test cannot prove the first keyboard focus of the app window. Also, the test `aNewCardDoesNotTakeTheKeyboardFocusFromThePromptEditor` puts the prompt editor after the deck, not before it, and it sets the first responder with `makeFirstResponder`; it does not show that a view "before the deck keeps" the focus. Write only what the code and the tests show: the elicitation cards set no initial focus, the window (AppKit) decides the first keyboard focus, and a new card does not take the keyboard focus from a view that has it. Remove "Thus a card alone in a window gets the keyboard focus" as a general rule for all cards.
- [x] `Docs/decisions/accessibility.md:118` `driver-check/tests-prove-claim` — The doc says "Hosted tests show that a card alone in a window gets the keyboard focus itself, and not a text field in it". The same claim is in the test comment at `Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift:145`. The only test for this, `aCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt`, uses `ElicitationURLConsentView`, which has no text field (its own comment says so). Thus the test cannot show "not a text field in it". No test shows where the first responder goes for `ElicitationView`, whose form has a text field. Change the doc and the test comment so that they name the URL consent card as the card that the test shows, and do not claim a result for a card with a text field.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift:41` `driver-check/tests-prove-claim` — The doc comment says "The deck gives the card the keyboard focus when the user brings it to the front", and `Docs/decisions/accessibility.md:127` says the same for each card. By the code, this stays true after the removal: `DeckCard` applies `.focused(keyboardFocus, equals: request.id)` to `ElicitationCard`, and `ElicitationView` and `ElicitationURLConsentView` keep `.focusable()`. But since this change removed `.focused($isFocused)` from the two elicitation views, no hosted test proves it for an elicitation card. The only keyboard-focus test for bring-to-front, `nextMovesTheFocusAndTheKeyboardFocusIntoTheNewFrontCard`, brings a `PermissionView` to the front, and `PermissionView` still has its own `.focused($isFocused)` and `.defaultFocus`. `aPressOnTheWaitingStatusBringsTheLinkedCardToTheFrontWithTheFocus` asserts only the VoiceOver focus move (`reporter.moves`). Add one hosted test: put a permission request first and an elicitation second (a URL consent elicitation, so that no text field can take Esc), bring the elicitation to the front with Next or with the waiting status, send Esc, and assert that the elicitation cancels and the permission stays pending.