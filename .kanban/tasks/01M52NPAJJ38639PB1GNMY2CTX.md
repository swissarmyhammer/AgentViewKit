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
- actor: claude-code
  id: 01m52ra305jy08dv30dfy47hat
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (4861b30): counts findings 1, confirmed 1, refuted 1, attempted 28, failed 0. Engine finding: Tests/AgentViewKitTests/Elicitation/ElicitationViewHostedTests.swift:114 (reuse/reuse).
    - evidence: reading check of the step owner, 3 items: Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift:11, :13, :30 (the doc comments tell about callers and claim more than the helpers check).
    - evidence: each new `#require` comes after a synchronous press, key or type (each one does one render() pass) and before the first await. The models are on the main actor, so the check gives the same result on each run. The production paths are synchronous: acceptElicitation, declineElicitation and cancelElicitation of SessionModel and ConnectionModel remove the request at once; PermissionView.answer calls permissionAnswerReport in the same step; AgentAuthView.perform inserts the operation in `running` before its Task; SpeechInputButton.toggle shows `.recording` before its Task; PromptInputView.submit clears the text and the attachments and calls onSubmit in the same step. Card test mutation (`keyboardFocus = id` -> `_ = id`) failed at once (0.330 s), from the implement record.
    - evidence: no added line uses a clock, sleep, poll, retry, timeout or timeLimit. `git diff --stat HEAD~1..HEAD -- Sources` is empty. No mutation run in this review.
    - next: implement the 4 open items; then /review.
  timestamp: 2026-10-16T16:21:49.701239+00:00
- actor: claude-code
  id: 01m52rb0xan816cara4zasg5pj
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 21 test files and new Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift; no Sources change; new card ^74gyjm5
    - test: green — swift test --skip-build, 1252 tests in 145 suites passed, 2 known issues
    - commit: 4861b30
    - review: findings — Tests/AgentViewKitTests/Elicitation/ElicitationViewHostedTests.swift:114, Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift:11, Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift:13, Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift:30
  timestamp: 2026-10-16T16:22:20.330140+00:00
- actor: claude-code
  id: 01m52rmgrkjv5h7mxzmms585sc
  text: |-
    Implementation of the 4 review findings (implement step):
    - New helper `ScriptedSession.resultOfAnsweredElicitation(ofRequest:sourceLocation:)` in Tests/AgentViewKitTests/Helpers/ScriptedSessionRequests.swift, beside `result(ofRequest:)`. It requires that the session model holds no pending elicitation, and then calls `result(ofRequest:)`.
    - `Mounted.result(sourceLocation:)` in ElicitationViewHostedTests and ElicitationURLConsentViewHostedTests now each call the helper with the request id of the suite. The other copies of the same two lines also call it now: RequestDeckHostedTests/aTypedValueSurvivesNextAndPrevious, RequestDeckAccessibilityHostedTests/nextMovesTheKeyboardFocusIntoAnElicitationCardSoEscapeCancelsOnlyIt and aURLConsentCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt (its `model` local had no other use, so it is removed). `ElicitationURLConsentViewHostedTests.open(_:)` keeps its own `#require`, because it waits for the responses and the browser session, not for `result(ofRequest:)`.
    - HostedViewHarness+KeyChecks.swift: each doc comment (summary, Parameters, Throws) now says only what the function checks and when it throws. No text about callers, keys, waits, or which card has the focus.
    - No Sources change.
  timestamp: 2026-10-16T16:27:31.475695+00:00
- actor: claude-code
  id: 01m52rmr4m1zrt27ad78jc2z4w
  text: |-
    ### implement — changed
    - evidence: 6 test files — Tests/AgentViewKitTests/Helpers/ScriptedSessionRequests.swift, Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift, Tests/AgentViewKitTests/Elicitation/ElicitationViewHostedTests.swift, Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/RequestDeckAccessibilityHostedTests.swift. `git diff --stat -- Sources` is empty.
    - evidence: `swift build --build-tests`: Build complete. No compiler warning; only the known build-system note "missing creator for mutated node" for the mlx bundle.
    - evidence: `swift test --skip-build --filter '\.(ElicitationViewHostedTests|ElicitationURLConsentViewHostedTests|RequestDeckHostedTests|RequestDeckAccessibilityHostedTests|PermissionViewHostedTests|EditorKitPromptEditorHostedTests|SlashCommandSessionModelTests)/'`, one run: 88 tests in 7 suites passed, 0 failures, 0 issues.
    - evidence: the 4 review findings are checked.
    - next: /review.
  timestamp: 2026-10-16T16:27:39.028136+00:00
- actor: claude-code
  id: 01m52ry8d7ajs7878z58f9md0a
  text: |-
    ### test — green
    - evidence: `git diff --stat -- Sources` is empty (Sources has no diff). No swift-build or swift test of this package was running (other processes belong to other packages). `swift build --build-tests`: Build complete, exit 0. One warning, from the build system and not from a file in Sources/ or Tests/ of this package: "missing creator for mutated node: .../mlx-swift_Cmlx.bundle/Contents/MacOS". `swift test --skip-build` (one run): 1252 tests in 145 suites passed, 0 failed, 0 skipped, 2 known issues (existing withKnownIssue marks: aWrappedTextWithAFixedVerticalSizeFails, aViewThatIgnoresTheThemeFails). README.md and Examples/ReadmeSnippets are not changed, so Scripts/check-readme.sh did not run.
    - next: review.
  timestamp: 2026-10-16T16:32:50.599804+00:00
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

## Review Findings (2026-10-16 11:10)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 20 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Tests/AgentViewKitTests/Elicitation/ElicitationViewHostedTests.swift:114` `reuse/reuse` — The new `Mounted.result(sourceLocation:)` repeats the same two-step body as `Mounted.result(sourceLocation:)` in ElicitationURLConsentViewHostedTests: a `#require` that the model has no pending elicitation, then `session.result(ofRequest:)`. Two copies of this check will drift apart, and the next form-style test has to copy it again. Move the shared check into one helper, for example an extension on `ScriptedSession` such as `resultAfterAnswer(ofRequest:sourceLocation:)`, that takes the request id and runs the pending-elicitation `#require` before awaiting the result. Both `Mounted.result` wrappers then call it, or the tests call it directly.

> Items from the reading check of the step owner (the doc comments of the new helpers must say only what the helpers do):

- [x] `Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift:11` `caller-check/doc-comments` — The doc comment of `requireKeyboardFocusOutsideText(sourceLocation:)` says which tests call it: "A test calls this function before it sends Esc to a card whose Esc action answers in a task, such as a permission card." This is about the callers, not about the function. Also it is not true for each caller: `aURLConsentCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt` calls it before Esc on a URL consent card, and that card cancels in the same step (`cancelElicitation`). Remove the text about the callers. Say only what the function checks.
- [x] `Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift:13` `caller-check/doc-comments` — The doc comment of `requireKeyboardFocusOutsideText(sourceLocation:)` says "this check is the proof that the key can get to the card". The function checks only that the first responder is a view of the hosting view and does not edit text. It does not check which card holds the first responder. Remove this claim, and remove the related text on lines 10 and 14-15 ("Esc then goes to the SwiftUI focus of the window", "the test stops here and does not wait for an answer that cannot come"). Say only what the function checks and when it throws.
- [x] `Tests/AgentViewKitTests/Helpers/HostedViewHarness+KeyChecks.swift:30` `caller-check/doc-comments` — The doc comment of `requireTextViewShows(_:sourceLocation:)` says what the callers do: "The binding of a composer can take the change later, so a test waits for the binding after this check. When the key went to no text view, the test stops here and does not wait for a change that cannot come." The function does not wait and does not read a key. It requires that the first editable `NSTextView` of the hosting view shows `text`. Remove the text about the callers and about keys. Say only what the function checks.