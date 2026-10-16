---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m52pbs7p8zvpc6sqhb5xd216
  text: |-
    Research (implement step):
    - The answer paths. An elicitation answer (accept, decline, cancel, Esc) removes the request on the main actor in the same step (SessionModel/ConnectionModel acceptElicitation, declineElicitation, cancelElicitation). A permission answer starts a Task (startSelectPermission, startCancelPermission, answerPermission), so the model removes the request only after the test awaits. Composer submit clears the text and the attachments, and calls the host onSubmit, in the same step; cancel (Stop, Esc) starts a Task. A config option press, Retry of MessageActions, Reload of the stream banner, Retry of the URL consent card and the image select of ImageView start a Task and change no synchronous state.
    - Synchronous proofs that exist: pendingElicitations / pendingRequests counts; PermissionView permissionAnswerReport (the card calls it in the same step as the answer, after its isPending guard); submitCount of the test host and the cleared attachments; the Bool result of CommandSystem/registry perform; the highlighted value of a source row; the "Recording" value of SpeechInputButton; the selection of InspectorSelection (AttachmentView selects in the same step).
    - No synchronous model state proves that Esc reached a permission card. The proof before Esc is the keyboard focus: the first responder of the window is a view of the hosting view and does not edit text (the pattern of aURLConsentCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt).
    - Swift rule: never guard in a test, so each check is try #require, not #expect plus return.
  timestamp: 2026-10-16T15:47:48.086291+00:00
- actor: claude-code
  id: 01m52qbw3mgzxrt2a040aanz8t
  text: |-
    Implementation and proof (implement step):
    - Card test: nextMovesTheFocusAndTheKeyboardFocusIntoTheNewFrontCard now requires `model.frontRequestID == permission.id` after Next, and `harness.requireKeyboardFocusOutsideText()` before Esc. The permission card cancels in a task, so no model state changes in the same step as Esc; the keyboard focus is the synchronous proof. Mutation `keyboardFocus = id` -> `_ = id`: the test failed at once (0.330 s) at the new require (the first responder was the window). Source put back; `git diff -- Sources` is empty.
    - New helper file Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift: `requireKeyboardFocusOutsideText()` (replaces `editsText` and three lines of aURLConsentCardAlone...) and `requireTextViewShows(_:)`.
    - Other tests changed (sync proof before each wait): elicitation answers (pendingElicitations / pendingRequests, also in the `result()` helpers of ElicitationViewHostedTests and ElicitationURLConsentViewHostedTests and in `open(_:)`), permission option presses (`permissionAnswerReport`), permission Esc (keyboard focus), composer submits (`submitCount`, cleared attachments, cleared text, submit report), EditorKit typing (text view string), Speech button ("Recording" value, helper `pressToRecord`), source pill (highlighted row), attachment chip (selection), AgentAuthView buttons (disabled while the call runs, helper `ConnectionModelViewsHostedTests.pressAuthAction`), command `perform` Bool (#expect -> try #require).
    - One combined mutation build (15 mutations in PermissionView, ElicitationView, ElicitationURLConsentView, PromptInputView, StockPromptEditor, SpeechInputButton, InlineCitation, AttachmentView, AgentAuthView) with a filter of 54 tests: whole run 4.975 s, 52 tests failed at the new require (58 issues, one for each test or test case), no hang. aCancelOfTheLinkedCardRemovesTheWaitingStatus(.cancelAll) passed, as expected (a model call, not a press). Sources put back with `git checkout -- Sources`; `git diff -- Sources` is empty.
    - Not proven by mutation: the 10 command tests (AgentCommandsTests, AgentCommandScopeHostedTests; the proof is the Bool of perform), EditorKit shiftReturnInsertsANewlineAndDoesNotSend and the typing checks, SlashCommandSessionModelTests/afterAnEmptyCommandsUpdateASlashShowsTheNoCommandsNote.
    - Normal run of the 19 changed suites: 235 tests in 19 suites passed, 0 issues, 0 warnings.
  timestamp: 2026-10-16T16:05:19.604856+00:00
- actor: claude-code
  id: 01m52qc0yxr93xkz2jcn5f1bq6
  text: 'Blocker: the second to-do item is not complete. These hosted tests do a press or a key and then wait, but the handler only starts a Task and changes no synchronous state that a test can read: PermissionViewHostedTests/switchToAutoAllowsThenSetsTheMode, ComposerSessionModelHostedTests/theStopButtonSendsSessionCancel, EditorKitPromptEditorHostedTests/escapeStopsTheRunningTurn, the ConfigOptionsSessionModelHostedTests presses, SessionEntryRowsHostedTests/aConnectionThatClosesBeforeTheAnswerShowsTheClientTextInTheErrorRow, WireContentBlockViewHostedTests/aPressOnAWireImageSelectsItsBytesInTheInspector, MessageActionsHostedTests/retryOnAnAgentEntrySendsTheContentOfTheEarlierUserEntry, the SessionStateBannersHostedTests Reload tests, SessionPickerConnectionModelHostedTests.pressAndRenderTheCall, ElicitationURLConsentViewHostedTests/retryOpensTheBrowserAgainWithNoSecondAnswer and cancelWhileWaitingStopsTheBrowserAndSendsNoSecondAnswer. A synchronous proof for them needs a production change (for example a new ObservationReport in each view), and this card changes tests only. They are in ^74gyjm5. A person must decide: accept ^74gyjm5 for them, or let this card change production code. The Examples XCUITests use waitForExistence with a timeout, so they cannot wait without end.'
  timestamp: 2026-10-16T16:05:24.573204+00:00
- actor: claude-code
  id: 01m52qc8ewwkcjcs3n287efwsv
  text: |-
    ### implement — stuck
    - evidence: 21 test files changed and 1 test helper file added (Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift); no Sources change. Card test mutation: failed at once (0.330 s). Combined mutation run: 52 of 54 filtered tests failed at once in 4.975 s, no hang (the 2 that passed are the model-call case and none of the press paths). Normal run: `swift test --skip-build --filter` of the 19 changed suites, 235 tests passed, 0 issues. `swift build --build-tests`: no compiler warning (only the build-system note "missing creator for mutated node" for the mlx bundle, which the first build before any change also gave).
    - gap: to-do item 2 is not complete for 13 press paths with no synchronous state (list in the blocker comment, now in ^74gyjm5).
    - next: a person decides on the blocker; then /review.
  timestamp: 2026-10-16T16:05:32.252966+00:00
- actor: claude-code
  id: 01m52qmbbm9836jq2zysx0yqk0
  text: |-
    ### test — green
    - evidence: No other build of this package ran. The swift-build process 37708 had its cwd in FoundationModelsMultitool. The other processes were in other packages or were IDE index builds.
    - evidence: `git diff --stat -- Sources` shows no diff. Sources has no change.
    - evidence: `swift build --build-tests` finished with "Build complete". It gave one warning, from the build system and not from Sources or Tests: "missing creator for mutated node: .build/out/Products/Debug/mlx-swift_Cmlx.bundle/Contents/MacOS". Sources and Tests have zero warnings.
    - evidence: `swift test --skip-build` ran 1252 tests in 145 suites. All passed, with 0 failures and 2 known issues. The 2 known issues come from 2 existing withKnownIssue marks: HostedLayoutExpectationsTests.swift and ThemeHeightExpectationsTests.swift. They are not failures.
    - evidence: README.md and Examples/ReadmeSnippets have no change, so Scripts/check-readme.sh did not run.
    - next: review.
  timestamp: 2026-10-16T16:09:57.364181+00:00
position_column: doing
position_ordinal: '80'
title: Hosted test nextMovesTheFocusAndTheKeyboardFocusIntoTheNewFrontCard waits without end when the focus move breaks
---
Found during the review of card 38 (^stwa42z, commit 768dfd0). Write all text in STE.

## Fact
- The review did one mutation check in `DeckCards.deckDidChange` (Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift): `keyboardFocus = id` became `_ = id`.
- The new test `nextMovesTheKeyboardFocusIntoAnElicitationCardSoEscapeCancelsOnlyIt` failed at once (0.331 s) at its `#require(model.pendingElicitations.isEmpty)`.
- The older test `nextMovesTheFocusAndTheKeyboardFocusIntoTheNewFrontCard` (Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift, from card 37 ^wzmkdf5) has no `#require` before `await session.result(ofRequest:)`. With the mutation, the run did not stop in 30 minutes, and the reviewer killed it.
- Thus, when the keyboard focus move breaks, this test waits without end and does not fail. This is against the test rules: a wait must be on an event that is certain to happen.

## Scope (decision of the step owner)
This card is test-only. It covers the card 37 test and each press path that has a synchronous state. The 13 press paths that answer only in a task, with no synchronous state, need a production change. They are in ^74gyjm5, which comes right after card 40.

## To do
- [x] Before the `await session.result(ofRequest:)`, add a `#require` that the request was answered or cancelled after the key and one render(), as the new test does. (A permission card cancels in a task, so the test requires the keyboard focus before Esc: `HostedViewHarness.requireKeyboardFocusOutsideText()`.)
- [x] Look for the same pattern in the other hosted tests that wait for `session.result(ofRequest:)` after a key press or an AX press, and correct each one. (Done for each press path with a synchronous state. The press paths that answer only in a task, with no synchronous state, are in ^74gyjm5, by decision of the step owner.)
- [x] Prove the fix with one mutation run of each corrected test (put the source back after it), and one normal run.

#elicitation-phase-6 #bug