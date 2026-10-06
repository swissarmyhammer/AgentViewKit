---
assignees:
- claude-code
position_column: todo
position_ordinal: b280
title: Make PendingRequestsSessionModelHostedTests.thePermissionResponseFrameComesBeforeTheNextPromptFrame stable
---
## What
The full `swift test` run on 2026-10-06 (during ^s8sq0bf) failed one time in this test: "Run 39: the prompt frame came before the response frame" (answer index 81, prompt index 80). The other 1,323 tests passed.

`SessionModel.selectPermission(_:option:)` (FoundationModelsACPClient `be7e615`, `SessionModel+Pending.swift`) only resumes the continuation of the pending request (`permissions.resolve`). The response frame goes out later, from the task of the request handler. A `SessionModel.prompt(_:meta:)` call right after the select can write its frame first. The test asserts the opposite order, so it fails when the prompt wins the race.

This is not caused by a kit view. Find out if the order is a contract of the client model:
- If the client model must send the response first, report it upstream (FoundationModelsACPClient) and keep the test.
- If the order is not a contract, record that decision and change the test to assert what the model does promise.

## Acceptance Criteria
- [ ] The cause is recorded on this card, with the client model code that sends the response.
- [ ] The test passes in 10 full `swift test` runs, or an upstream issue is open and linked here.
- [ ] Do not raise the test time limit and do not add retries.

## Workflow
- Use `/tdd`.