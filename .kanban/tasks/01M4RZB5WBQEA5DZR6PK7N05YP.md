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
- actor: claude-code
  id: 01m4s5ca2v1sb12vrksk88eape
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (e89186b): 1 finding (1 confirmed, 2 refuted) — Scripts/test-examples.sh:253 reuse/reuse
    - next: Move the setpgrp-and-exec perl wrapper into one shared helper that `run_with_limit` and `start_detached_sleep` both call. Then run the tests, commit, and review again.
  timestamp: 2026-10-12T22:57:49.659748+00:00
- actor: claude-code
  id: 01m4s5ck5ynjqys79dvjec1nam
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — process group per step, stop of the app under test and the test runner by DerivedData path, --self-test; ExampleGateTimeLimitTests
    - test: green — swift test, 1152 + 123 + 1 tests passed, 2 expected known issues, load average 29 to 49; no leftover sleep process
    - commit: e89186b
    - review: findings — Scripts/test-examples.sh:253
  timestamp: 2026-10-12T22:57:58.974945+00:00
- actor: claude-code
  id: 01m4s5qke1sfkfehsr2t2gq19b
  text: |-
    Fix of the reuse finding:
    - New helper `start_in_new_group`. It is the only `perl setpgrp` wrapper in the script. Its arguments are the argv[0], the program, then the arguments of the program. It uses `exec { $program } $name, @arguments`. It starts perl in the background, and the caller reads the process id from `$!`. The helper must not write the id with `echo`: a command substitution runs in a subshell, and then the process is not a child of the script, and `wait` in `run_with_limit` fails.
    - `run_with_limit` calls `start_in_new_group "$1" "$@"` (the argv[0] is the command). `start_detached_sleep` calls `start_in_new_group "$path" sleep ...`. Thus the name `sleep` is only in the path that needs a fake argv[0].
    - A change of behavior: the old `exec @ARGV` gave a command with one argument to the shell. The block form never uses the shell.
    - I examined the rest of the script for the same repeated shape. No other copy of the process-group launch is in the script.
  timestamp: 2026-10-12T23:03:59.681820+00:00
- actor: claude-code
  id: 01m4s5qqzpatvr36jtjkr6aybe
  text: |-
    ### implement — changed
    - evidence: Scripts/test-examples.sh. `shellcheck Scripts/test-examples.sh`: exit 0, no finding. `/bin/bash` 3.2.57 `Scripts/test-examples.sh --self-test`: PASS (5 of 5 ok), exit 0. After the self-test and after `swift test`, no sleep process of the self-test stayed alive. Full `swift test`: 1152 tests in 129 suites passed, 2 known issues (not from this change), exit 0; ExampleGateTimeLimitTests passed in 3.7 seconds. Load average before 28.31 34.12 35.39, after 19.84 28.26 32.64. One build warning that is not from this change: "missing creator for mutated node" for mlx-swift_Cmlx.bundle. No UI test and no xcodebuild ran. The finding Scripts/test-examples.sh:253 is checked.
    - next: /review
  timestamp: 2026-10-12T23:04:04.342484+00:00
- actor: claude-code
  id: 01m4s66jmxj5d7eny6eh6vftwm
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (d757b94). 0 findings, 0 confirmed, 0 refuted. 6 validator runs, 0 failed. 1 file reviewed: Scripts/test-examples.sh. All prior findings have a check mark.
    - next: none. The task moved to done.
  timestamp: 2026-10-12T23:12:10.397313+00:00
- actor: claude-code
  id: 01m4s66tysj1vx3k9g380xj4ch
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — one start_in_new_group helper; finding checked
    - test: green — swift test, 1152 tests passed, 2 expected known issues, load average 16 to 32; no leftover sleep process
    - commit: d757b94
    - review: clean — 0 findings (1 file); task in done
  timestamp: 2026-10-12T23:12:18.905855+00:00
position_column: done
position_ordinal: ffb780
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

## Review Findings (2026-10-12 17:53)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Scripts/test-examples.sh:253` `reuse/reuse` — `start_detached_sleep` writes its own `perl -e 'setpgrp(0, 0) ...; exec ...'` wrapper, which nearly repeats the wrapper in `run_with_limit` (line 157). Two copies of the process-group launch can drift apart. The only real difference is the `exec { "sleep" } @ARGV` form, which sets argv[0] to the fake path. That difference could be a parameter of one shared launcher. Move the setpgrp-and-exec perl wrapper into one helper, for example `start_in_new_group`, that takes the argv[0] as an argument. Have `run_with_limit` and `start_detached_sleep` both call it. Keep `exec { "sleep" }` only in the path that needs a fake argv[0].
