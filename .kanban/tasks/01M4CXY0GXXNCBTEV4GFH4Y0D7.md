---
assignees:
- claude-code
depends_on:
- 01M4BTQV4WZHK4CE5F6VEWXKF3
position_column: todo
position_ordinal: bd80
title: Show AuthFailure.Reason.message for each sign-in failure reason, with no kit text table
---
## What
FoundationModelsACPClient e1cac1d adds `AuthFailure.Reason.message`: a text that a UI can show for each reason (request, terminal, unsupported). `AgentAuthView.text(of:)` uses this text only for `unsupported`. For `terminal`, the kit still has its own texts in `terminalText(exitStatus:message:)` ("The sign-in process ended with no exit status." and "... ended with exit status N."). The client gives other texts for the same reason ("The sign-in process did not stop normally." and "The sign-in process stopped with exit status N.").

Decision (2026-10-08, from the owner binding rule): the kit views bind directly to the client model and keep no logic and no text table of their own. Thus `AgentAuthView` shows `failure.reason.message` for each reason. Localization of these texts belongs to the client: client task ^wg6efj4 "Localize the text of AuthFailure.Reason.message".

Found in ^vewxkf3.

- [ ] `AgentAuthView` shows `failure.reason.message` for each reason. Remove `text(of:)` and `terminalText(exitStatus:message:)`, and any kit string that copies a client text.
- [ ] Change the expected texts of `aRunnerWithNoExitStatusShowsTheTerminalFailureText`, `aNonZeroExitStatusShowsTheTerminalFailureTextWithTheStatus` and the runner-error test in `Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift` to the client texts. Read each expected text from `AuthFailure.Reason.message` of the same reason, so that the test does not copy the client text.
- [ ] Check the other kit views for text tables that copy a client text for a model value, and record each one on this card.

## Acceptance Criteria
- [ ] `AgentAuthView` has no text table for `AuthFailure.Reason`.
- [ ] The sign-in card shows the client text for each failure reason.

## Tests
- [ ] The hosted tests in `AgentAuthViewHostedTests.swift` fail before the change and pass after it.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.