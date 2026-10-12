---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4s4aq05ma32d9fdfaak17y0
  text: |-
    Research:
    - `run_with_limit` uses `timeout`, `gtimeout` or a `perl` alarm. The perl alarm stops only the process that it execs. No path stops the processes that XCUITest starts.
    - XCUITest starts the app and `AgentViewKitDemoUITests-Runner` through launchd. They are not in the process group of xcodebuild. Their executables are in `.build/examples/<AppName>/DerivedData/Build/Products/...`. Thus the script can find them by the start of their command line (the DerivedData path of this example), and it stops no other process.
    - No test of PackageStructureTests reads test-examples.sh for behavior. A text test cannot prove that a process stops. Thus the new test runs the script in a new `--self-test` mode. The self-test starts only `sleep` processes. It does not start xcodebuild.
    - A copy of `/bin/sleep` at another path is killed by code signing (status 137). `exec -a <path> sleep` gives a process whose command line starts with that path. The self-test uses that for the fake app and the fake runner.
    - The new run_with_limit puts the command in its own process group. Then Control-C from the terminal does not get to it, so the script must forward INT, TERM and HUP to the group.
  timestamp: 2026-10-12T22:39:28.773257+00:00
- actor: claude-code
  id: 01m4s4t9vq9pcbfnmg25zx5we0
  text: |-
    Implementation:
    - `run_with_limit` now starts the command in its own process group (`perl setpgrp`, then `exec`). A background `watch_limit` waits for the limit. Then it sends SIGTERM to the group, and SIGKILL to each process that is alive after STOP_GRACE_SECONDS (10). The function returns LIMIT_STATUS (124). It no longer uses `timeout`, `gtimeout` or the perl alarm. It sends SIGINT, SIGTERM and SIGHUP of the script on to the group, because a group that is not in the foreground does not get the SIGINT of the terminal.
    - New `run_example_step`: when the limit occurs, it also stops each process of this user whose command line starts with the DerivedData directory of the example. That is the app under test and `AgentViewKitDemoUITests-Runner`. No other process is stopped.
    - `run_xcodebuild` takes the DerivedData directory as its second argument and gives `-derivedDataPath` itself.
    - New `--self-test` mode. It starts only `sleep` processes and runs no xcodebuild.
    - The time limits (EXAMPLE_BUILD_TIMEOUT 1800, EXAMPLE_TEST_TIMEOUT 900) did not change.
    - The test `ExampleGateTimeLimitTests` runs `bash Scripts/test-examples.sh --self-test`. RED: it failed (the script took `--self-test` as an example name). GREEN: it passes in about 4 seconds. A direct run of the self-test left no process alive.
    - `shellcheck Scripts/test-examples.sh` gives no finding.
  timestamp: 2026-10-12T22:47:59.607029+00:00
- actor: claude-code
  id: 01m4s4tcc7mtdpgb99ey4cmppz
  text: |-
    ### implement — changed
    - evidence: Scripts/test-examples.sh, Tests/PackageStructureTests/ExampleGateTimeLimitTests.swift (new). Full `swift test`: 1152 tests in 129 suites passed, 2 known issues (not from this change), exit 0. Load average before 26.58 28.20 33.29, after 36.91 31.57 33.52. The build gives one warning that is not from this change: "missing creator for mutated node" for mlx-swift_Cmlx.bundle. No UI test and no xcodebuild ran.
    - next: /review
  timestamp: 2026-10-12T22:48:02.183617+00:00
position_column: doing
position_ordinal: '8180'
title: Stop the app under test and the test runner when test-examples.sh reaches its time limit
---
## What
In CI run 38296969149, attempt 1 reached the time limit of `Scripts/test-examples.sh`. The `perl` alarm stopped only `xcodebuild`. The demo app (pid 17443) stayed alive for about 20 minutes. In attempt 2, XCUITest found it and terminated it before its own launch. A process that stays alive can change the next run on the self-hosted box.

Also, after the failure in `setUp`, the test runner waits in "indefinite wait loop for expectations: `failable invocation block completion`" in Tear Down until the alarm (about 14 minutes).

Found during ^svaqj8t.

## Work
- [x] Write a test in PackageStructureTests (the script tests read the script as text) that requires the script to stop the app under test and the test runner after the time limit.
- [x] Make `run_with_limit` (or `run_example`) stop the process group of the command, and the `AgentViewKitDemo` app and the `AgentViewKitDemoUITests-Runner` that the run started, when the limit occurs.
- [x] Run the full `swift test`.