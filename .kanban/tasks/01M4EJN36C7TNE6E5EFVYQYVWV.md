---
assignees:
- claude-code
position_column: todo
position_ordinal: bd80
title: Make ConversationViewHostedTests.theShowErrorButtonMovesToTheErrorEntry stable in the full suite run
---
## What
During the test step of ^ahfhekw, `theShowErrorButtonMovesToTheErrorEntry` in `Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift` failed one time in a full `swift test` run. After the test pushed Show Error, `anchors.visibleIDs.contains(errorKey)` stayed false for all of the 5-second wait. The list showed `conversation-m0` to `conversation-m4`, and did not show the error row. The test passed alone, and the full suite passed alone.

The tester increased `waitTimeout` in this file from 5 seconds to 30 seconds. This does not correct the cause. The failed state was a scroll that did not go to the error row. It was not a scroll that was only slow.

- [ ] Find why the scroll does not go to the error row when the full suite runs.
- [ ] Correct the cause. Then decide if the 30-second wait is necessary, and set it back to 5 seconds if it is not.

## Acceptance Criteria
- [ ] The test passes in 5 full `swift test` runs one after the other.

## Tests
- [ ] `swift test` passes.