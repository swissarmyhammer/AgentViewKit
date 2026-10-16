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
- Waits: render(when: !pendingRequests.isEmpty) for the linked request; render() after the press; ObservationWait.until { pendingRequests.isEmpty } after the answer, then render().

#elicitation-phase-6