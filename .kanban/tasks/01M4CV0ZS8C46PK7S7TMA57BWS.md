---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4cwekdpzeb9bk2m5rwyn5th
  text: 'Upstream task made on the FoundationModelsACPClient board: ^xz6sdn0 "AgentProcess: environment and working directory parameters, and the exit status". The client session had ended, so the task was written with the kanban CLI in the client repository. This task stays blocked-upstream until ^xz6sdn0 is pushed.'
  timestamp: 2026-10-08T04:30:54.390953+00:00
- actor: claude-code
  id: 01m4dtzy64pdycnpe4d7gqbesj
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — the upstream request exists: FoundationModelsACPClient task 01M4CWECXYZTPR4H1FYXZ6SDN0 "AgentProcess: environment and working directory parameters, and the exit status", column todo. FoundationModelsACPClient HEAD e1cac1d does not have these parameters.
    - next: when the client change is pushed, move the pin and change the kit. A person must start this task again.
  timestamp: 2026-10-08T13:24:39.748984+00:00
- actor: claude-code
  id: 01m4ek1psev52bxvpfdrthr2z6
  text: |-
    Research done. Facts:
    - The pin 74fc2df contains client commit 3c49b6e. `AgentProcess.init(command:arguments:environment:currentDirectory:)` is public. `environment` is the WHOLE environment of the child (it replaces the host environment). `currentDirectory` is a spawn file action. `AgentProcess.exitStatus: AgentExitStatus?` is `nil` until the teardown reaps the child; the EOF path reaps the child before `transport.bytes` finishes.
    - `AgentExitStatus` has the cases `exited(code:)`, `signaled(signal:)` and `notCollected`. It has no text.
    - `ProcessLauncher.launch(program:arguments:environment:)` says that `environment` has the variables to ADD. Thus the launcher gives the host environment with the launch variables on top, or `nil` when the launch has no variables.
    - The protocol has no working directory parameter. The terminal auth methods do not have a working directory. Decision: `AgentProcessLauncher.init(currentDirectory:)` with a `nil` default.
    - The kit shows the end of the process in `LaunchedProcess.exitStatus`. Binding rule: that property gives the client value `AgentExitStatus?`, not a kit `Int32` copy. `FakeProcessLauncher` changes to match.
    - No kit view, demo or benchmark uses `ProcessLauncher` or `AgentProcessLauncher`. The demo starts `AgentProcess` directly. Thus no xcodebuild run is necessary.
    - `/usr/bin/env` text is only in the doc comments of `AgentProcessLauncher.swift`. README, plan.md and Docs do not have it (the script shebangs are not about the launcher).
  timestamp: 2026-10-08T20:25:03.534828+00:00
- actor: claude-code
  id: 01m4ekpsdqf78gpc95cr03rn0h
  text: |-
    Implementation done with /tdd.
    - RED: the new tests in `AgentProcessLauncherTests` did not compile. The reasons: no `AgentProcessLauncher.init(currentDirectory:)`, `exitStatus` was `Int32?`, and `AgentLaunchedProcess.process` was private.
    - GREEN: `AgentProcessLauncher` now starts the program itself with `AgentProcess(command:arguments:environment:currentDirectory:)`. With no launch variables it gives `nil` (the host environment). With launch variables it gives the host environment with the launch variables added. It still refuses an empty name or a name with `=` (`AgentProcessLauncherError.invalidEnvironmentName`).
    - Removed: `AgentProcessLauncher.environmentProgram`, the `command(program:arguments:environment:)` helper and the `AgentProcessLauncherError.programPathHasEqualSign` case. Nothing outside the launcher and its tests used them.
    - `LaunchedProcess.exitStatus` is now `AgentExitStatus?`, the client value. `AgentLaunchedProcess.exitStatus` gives `process.exitStatus`. `FakeProcessLauncher.scriptedExitStatus` is now `AgentExitStatus` (default `.exited(code: 0)`).
    - A test defect that I corrected: the temporary directory path has a trailing slash, so the first URL compare failed. The tests now compare directory URLs.
    - Note: the build prints one SwiftPM line "warning: missing creator for mutated node" for the mlx-swift Cmlx bundle. It is from a dependency bundle, not from a changed file.
  timestamp: 2026-10-08T20:36:34.359308+00:00
- actor: claude-code
  id: 01m4ekpzg1rk7f7mcky2azzzw0
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/ACP/AgentProcessLauncher.swift, Sources/AgentViewKit/Platform/ProcessLauncher.swift, Sources/AgentViewKitTestSupport/FakeProcessLauncher.swift, Tests/AgentViewKitTests/ACP/AgentProcessLauncherTests.swift, Tests/AgentViewKitTests/TestSupport/FakesTests.swift. `swift test`: 1034 tests in 110 suites, 93 tests in 11 suites and 1 test in 1 suite pass, 0 failures. `swift build --package-path Benchmarks`: Build complete. The demo app does not use the launcher, so no xcodebuild run was necessary.
    - next: /review
  timestamp: 2026-10-08T20:36:40.577313+00:00
position_column: doing
position_ordinal: '80'
title: Ask FoundationModelsACPClient for the environment, the working directory and the exit status of AgentProcess
---
## What
Source: the deleted update plan of 2026-10-02, section 9.4 (task ^g95wwbs moved its content into `plan.md` and deleted it). `AgentProcess` of FoundationModelsACPClient has only `init(command:arguments:)`. The child inherits the environment of the host, and the host cannot set the working directory. Thus `AgentProcessLauncher` (`Sources/AgentViewKit/ACP/AgentProcessLauncher.swift`) launches the agent through `/usr/bin/env`, and the exit status of the agent is not available.

- [x] Make a task in FoundationModelsACPClient: add an `environment` parameter and a `currentDirectory` parameter to `AgentProcess`, and give the exit status of the process. (FoundationModelsACPClient task 01M4CWECXYZTPR4H1FYXZ6SDN0. Commit 3c49b6e is on origin/main, and the kit pin 74fc2df contains it.)
- [x] When that commit is pinned, change `AgentProcessLauncher` to use the new parameters in place of `/usr/bin/env`, and show the exit status where the kit shows the end of the agent process.
- [x] Update each README, doc comment or plan.md text that says that the launcher uses `/usr/bin/env`. (Only the doc comments of `AgentProcessLauncher.swift` and `ProcessLauncher.swift` had such text.)

## Acceptance Criteria
- [x] FoundationModelsACPClient has a task for the three parts.
- [x] After the pin move, `AgentProcessLauncher` does not start `/usr/bin/env`.

## Tests
- [x] A unit test of `AgentProcessLauncher` with `FakeProcessLauncher` or the real launcher checks the environment and the working directory of the child.
- [x] A unit test checks the exit status that the launched process shows.
- [x] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.