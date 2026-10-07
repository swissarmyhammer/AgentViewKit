---
assignees:
- claude-code
depends_on:
- 01M4BHMJNEVT7DQ6KHVZTXQXVH
position_column: todo
position_ordinal: b380
title: Call the async selectPermission and cancelPermission of the client model
---
## What
FoundationModelsACPClient task 3p0m0c1 replaces the sync `selectPermission(_:option:)` and `cancelPermission(_:)` with async forms. The async forms return after the client writes the response frame.

The pin task ^ztxqxvh moves the pins; this task starts after it. The pin task also adds `await` at all calls of `selectPermission(_:option:)` and `cancelPermission(_:)` in `Sources/` and `Tests/`. This task does not do that work again.

This task makes sure that the comment prompt after a reject-with-comment goes out after the permission response frame, and that a test examines this order.

Subtasks:
- [ ] In `Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift`, restore the frame-order check that ^et6e0ps removed. The check must fail before the change.
- [ ] In `Sources/AgentViewKit/HumanInTheLoop/PendingRequestReplies.swift`, send the comment prompt only after the awaited `selectPermission(_:option:)` call returns.
- [ ] Update the doc comment of the test at line 171 of `PendingRequestsSessionModelHostedTests.swift`. Remove the text that says the client model does not promise the order.

## Acceptance Criteria
- [ ] The wire test checks that the permission response frame comes before the comment prompt frame. The check passes in 100 runs.
- [ ] The test uses no sleeps.

## Tests
- [ ] `Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift`: restore the frame-order check. Run it 100 times (for example with a parameterized test over `1...100`). Each run checks that the permission response frame comes before the comment prompt frame. Use no sleeps.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.