---
assignees:
- claude-code
position_column: todo
position_ordinal: b380
title: Call the async selectPermission and cancelPermission of the client model
---
## What
Blocked upstream. FoundationModelsACPClient task 3p0m0c1 replaces the sync `selectPermission(_:option:)` and `cancelPermission(_:)` with async forms. The async forms return after the client writes the response frame.

The kit must call them with `await`. Then the comment prompt after a reject-with-comment goes out after the reply frame.

Start condition: the kit pins a FoundationModelsACPClient commit that has 3p0m0c1. Do not start this task before that pin.

Callers at this time (search `selectPermission` and `cancelPermission` in `Sources/` and `Tests/` again before you start):
- `Sources/AgentViewKit/HumanInTheLoop/PendingRequestReplies.swift` (lines 119 and 121).
- `Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift` (line 341).
- `Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift` (lines 199 and 225).

Subtasks:
- [ ] Bump the FoundationModelsACPClient pin to a commit that has 3p0m0c1.
- [ ] In `Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift`, restore the frame-order check that ^et6e0ps removed. The check must fail before the change.
- [ ] In `Sources/AgentViewKit/HumanInTheLoop/PendingRequestReplies.swift`, call `selectPermission(_:option:)` and `cancelPermission(_:)` with `await`. Send the comment prompt only after the call returns.
- [ ] Add `await` to all other callers in `Sources/` and `Tests/`.
- [ ] Update the doc comment of the test at line 171 of `PendingRequestsSessionModelHostedTests.swift`. Remove the text that says the client model does not promise the order.

## Acceptance Criteria
- [ ] All callers of `selectPermission(_:option:)` and `cancelPermission(_:)` compile with `await`.
- [ ] The wire test checks that the permission response frame comes before the comment prompt frame. The check passes in 100 runs.
- [ ] The test uses no sleeps.

## Tests
- [ ] `Tests/AgentViewKitTests/HumanInTheLoop/PendingRequestsSessionModelHostedTests.swift`: restore the frame-order check. Run it 100 times (for example with a parameterized test over `1...100`). Each run checks that the permission response frame comes before the comment prompt frame. Use no sleeps.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #blocked-upstream