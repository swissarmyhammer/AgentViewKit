---
assignees:
- claude-code
position_column: todo
position_ordinal: '8280'
title: Stop the app under test and the test runner when test-examples.sh reaches its time limit
---
## What
In CI run 38296969149, attempt 1 reached the time limit of `Scripts/test-examples.sh`. The `perl` alarm stopped only `xcodebuild`. The demo app (pid 17443) stayed alive for about 20 minutes. In attempt 2, XCUITest found it and terminated it before its own launch. A process that stays alive can change the next run on the self-hosted box.

Also, after the failure in `setUp`, the test runner waits in "indefinite wait loop for expectations: `failable invocation block completion`" in Tear Down until the alarm (about 14 minutes).

Found during ^svaqj8t.

## Work
- [ ] Write a test in PackageStructureTests (the script tests read the script as text) that requires the script to stop the app under test and the test runner after the time limit.
- [ ] Make `run_with_limit` (or `run_example`) stop the process group of the command, and the `AgentViewKitDemo` app and the `AgentViewKitDemoUITests-Runner` that the run started, when the limit occurs.
- [ ] Run the full `swift test`.