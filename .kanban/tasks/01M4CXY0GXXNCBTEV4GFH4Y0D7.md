---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4dqf59rh69j5z02byq2gde8
  text: |-
    Picked up again. Earlier sessions left the source and test changes in the working tree. I read them and kept them as they are: `AgentAuthView.failureView(_:)` shows `failure.reason.message`, `text(of:)` and `terminalText(exitStatus:message:)` are gone, and the hosted tests read each expected text from `AuthFailure.Reason.message` (the `unsupportedFailureText` copy is also gone).

    RED check: I put back the HEAD version of `AgentAuthView.swift` and ran `swift test --filter AgentAuthViewHostedTests`. Two tests failed as expected: `aRunnerWithNoExitStatusShowsTheTerminalFailureText` and `aNonZeroExitStatusShowsTheTerminalFailureTextWithTheStatus` (`failure.text == reason.message`). The runner-error test and the unsupported tests passed before the change too, because the old kit code already gave the same text for those reasons. Then I put back the new source.

    Survey of the other kit views: no other view has a text table that copies a client text. The list of each item that I checked is in the description, under "Survey of the other kit views". The kit has no string catalog, so there is no catalog entry to remove.
  timestamp: 2026-10-08T12:23:04.248297+00:00
- actor: claude-code
  id: 01m4dqf846ad5f5z764shzd950
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Connections/AgentAuthView.swift, Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift. RED: `swift test --filter AgentAuthViewHostedTests` on the HEAD source, 17 tests, 2 failures (the two terminal text tests). GREEN: `swift test`, 1025 tests in 110 suites passed, 0 failures. One SwiftPM build warning comes from the dependency bundle `mlx-swift_Cmlx.bundle` ("missing creator for mutated node"), not from kit code.
    - next: /review
  timestamp: 2026-10-08T12:23:07.142748+00:00
- actor: claude-code
  id: 01m4dqs6fzcd07tjk2mrpwhhbs
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (8f49c7b); 1 finding, 1 confirmed, 0 refuted — Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift:357 (completeness/public-output-contract)
    - next: Make the test aNonZeroExitStatusShowsTheTerminalFailureTextWithTheStatus examine the exit status in the shown text, or change its name. Then do the review again.
  timestamp: 2026-10-08T12:28:33.151671+00:00
- actor: claude-code
  id: 01m4dqskw9em97reys4nrjy71d
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 2 files (AgentAuthView.swift, AgentAuthViewHostedTests.swift)
    - test: green — swift test, 1025 tests in 110 suites passed
    - commit: 8f49c7b
    - review: findings — Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift:357
  timestamp: 2026-10-08T12:28:46.857571+00:00
- actor: claude-code
  id: 01m4dr2ftvvcvn77q3sh749072
  text: |-
    Fixed the review finding. Moved the card back to doing.

    Client check: in FoundationModelsACPClient e1cac1d, `AuthFailure.Reason.message` for `.terminal(exitStatus:message:)` gives `message` when it is not nil. If `message` is nil, it gives "The sign-in process stopped with exit status N." (or "did not stop normally." when there is no status). Thus the text contains the status.

    Test change in `Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift`:
    - `aNonZeroExitStatusShowsTheTerminalFailureTextWithTheStatus` keeps `failure.text == reason.message` and also asserts `failure.text?.contains(String(Self.failureStatus)) == true`.
    - Same cause in the file: `aRunnerThatCannotStartTheProgramShowsTheMessageOfItsError` asserted only `failure.text == reason.message`, so it did not examine the message of the error. It now also asserts `failure.text?.contains(Self.launchErrorText) == true`.
    - I examined each other test name in the file. Each other test examines the value that its name gives.

    RED note: the new assertions test client behavior that is already correct, so no kit change can make them fail first. They fail if the client text drops the status or the error message.
  timestamp: 2026-10-08T12:33:37.627784+00:00
- actor: claude-code
  id: 01m4dr2hjc78e7gj2cx5c0kq4q
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift. `swift test`: 1025 tests in 110 suites passed, 0 failures. One SwiftPM build warning comes from the dependency bundle `mlx-swift_Cmlx.bundle` ("missing creator for mutated node"), not from kit code.
    - next: /review
  timestamp: 2026-10-08T12:33:39.404072+00:00
- actor: claude-code
  id: 01m4drcesdqbasqk7hnbd8tbg5
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (7b64037). 0 findings, 0 confirmed, 0 refuted. 7 validator runs, 0 failed. 1 file reviewed. The ignore rule excluded 2 .kanban files. All prior findings are checked.
    - next: none. The task moved to done.
  timestamp: 2026-10-08T12:39:04.237116+00:00
- actor: claude-code
  id: 01m4drd10pn08wj9b1txkga6ww
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — 1 file (AgentAuthViewHostedTests.swift)
    - test: green — swift test, 1025 tests in 110 suites passed
    - commit: 7b64037
    - review: clean — 0 findings, prior finding checked
  timestamp: 2026-10-08T12:39:22.902244+00:00
depends_on:
- 01M4BTQV4WZHK4CE5F6VEWXKF3
position_column: done
position_ordinal: ff9680
title: Show AuthFailure.Reason.message for each sign-in failure reason, with no kit text table
---
## What
FoundationModelsACPClient e1cac1d adds `AuthFailure.Reason.message`: a text that a UI can show for each reason (request, terminal, unsupported). `AgentAuthView.text(of:)` uses this text only for `unsupported`. For `terminal`, the kit still has its own texts in `terminalText(exitStatus:message:)` ("The sign-in process ended with no exit status." and "... ended with exit status N."). The client gives other texts for the same reason ("The sign-in process did not stop normally." and "The sign-in process stopped with exit status N.").

Decision (2026-10-08, from the owner binding rule): the kit views bind directly to the client model and keep no logic and no text table of their own. Thus `AgentAuthView` shows `failure.reason.message` for each reason. Localization of these texts belongs to the client: client task ^wg6efj4 "Localize the text of AuthFailure.Reason.message".

Found in ^vewxkf3.

- [x] `AgentAuthView` shows `failure.reason.message` for each reason. Remove `text(of:)` and `terminalText(exitStatus:message:)`, and any kit string that copies a client text.
- [x] Change the expected texts of `aRunnerWithNoExitStatusShowsTheTerminalFailureText`, `aNonZeroExitStatusShowsTheTerminalFailureTextWithTheStatus` and the runner-error test in `Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift` to the client texts. Read each expected text from `AuthFailure.Reason.message` of the same reason, so that the test does not copy the client text.
- [x] Check the other kit views for text tables that copy a client text for a model value, and record each one on this card.

## Survey of the other kit views
The client (FoundationModelsACPClient e1cac1d and FoundationModelsACP) gives a UI text for these values only: `AuthFailure.Reason.message`, `SessionNotice.title` and `SessionNotice.description`, `TerminalEntry.text`, `AgentProcessError.description` and `ProtocolVersionMismatchError.description`. No other client type gives a text (no `LocalizedError`, no `label`, no `title` for an enum).

Result: no other kit view has a text table that copies a client text.
- `SessionNoticeBanner` shows `notice.title` and `notice.description` of the client. Its `severityLabel(_:)` table names `Unstable.NoticeSeverity`. The client gives no text for a severity, so this table copies no client text.
- `TerminalView` shows `entry.text` of the client. It does not decode `entry.bytes` itself.
- `ActivityTimeline` and `ErrorView` show `RequestError.message` of the client in `ErrorView.content(code:message:)`. The kit adds only the code prefix.
- `UnsupportedProtocolVersionError.description` (not a view) gives a kit text from `SupportedProtocolVersions.refusalMessage(received:requested:)`. That text also names the list of versions that the kit accepts, and the kit also throws this error for a version that the wire package accepts. Thus it is a kit text, not a copy of `ProtocolVersionMismatchError.description`.
- The kit does not show `AgentProcessError.description`.
- The other kit text tables (`StateBanner` stop reasons and states, `WorkStatusLabel`, `TaskListView` priorities, `ToolKindSymbol`, `ConfigOptionsView` categories, `DiffSummary` change operations, the `AgentAuthView` operation titles) name values for which the client gives no text.

## Acceptance Criteria
- [x] `AgentAuthView` has no text table for `AuthFailure.Reason`.
- [x] The sign-in card shows the client text for each failure reason.

## Tests
- [x] The hosted tests in `AgentAuthViewHostedTests.swift` fail before the change and pass after it.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-10-08 07:27)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 6 not reviewed.

> 6 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 6 file(s)

- [x] `Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift:357` `completeness/public-output-contract` — The test named aNonZeroExitStatusShowsTheTerminalFailureTextWithTheStatus no longer checks the exit status. It asserts only that the shown text equals reason.message, where reason is built from the same exitStatus input. The old kit text showed the status. The new assertion would still pass if the client model's message dropped the status, so a dropped status is not caught. Assert that the shown text contains the exit status, for example by checking that failure.text contains String(Self.failureStatus), or rename the test to drop the status claim if the client model's message is the contract. Confirm that AuthFailure.Reason.message for .terminal(exitStatus:message:) includes the status.
