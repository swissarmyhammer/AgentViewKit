---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4rzap4dws3batt4bqg4nvq7
  text: |-
    ### Research: the launch on this machine does not show a block

    - Demo build: `xcodebuild build` (-skipMacroValidation -skipPackagePluginValidation, derived data in `.build/examples/AgentViewKitDemo/DerivedData`) — BUILD SUCCEEDED.
    - Launch 1: the executable directly with `--in-memory-agent`. Sample at 1.4 s after launch: the main thread is idle in `NSApplication run` → `__CFRunLoopServiceMachPort` → `mach_msg2_trap`. All samples to 48 s are the same.
    - Launch 2: `open -n` with `--in-memory-agent` (through LaunchServices, as XCUITest does). Samples at 3 s, 6 s and 20 s: the main thread is idle in the event loop. CPU 0.0 %. `lsappinfo front` gives the demo app: the app comes to the front. Footprint 66 MB.
    - The unified log shows no TCC request from the app during the launch.
    - I stopped each demo process that I started. No demo process stays.

    ### Research: the CI evidence refutes the main-thread block

    1. The result bundle of run 38296969149 (artifact 11771711620) has the stdout of the app (pid 31601). At 2 s after the launch the app logs `rpc.method=initialize`, `rpc.method=session/new` and `rpc.method=session/list`. These requests come from the `.task` of the ACP tab on the main actor. Thus the main actor ran, and the start of the in-memory agent completed.
    2. The session log of the test runner: the state goes `Not Running -> Running Background` at 21.327 s, and `accessibility active (loaded) NO -> YES` at 21.522 s. The runner then waits 60 s for `activated` (activation policy 0, regular). The state does not change. The app is alive and responsive, but the system does not make it the active app.
    3. Run 38150800563 (commit e41cacd, 2026-10-11) has the SAME failure: `Failed to activate application ... (current state: Running Background)`, then `Alarm clock`. At e41cacd the package does not declare FoundationModelsACPAgent and DemoSupport does not import it (checked with `git show`). Thus the failure is not caused by the agent package.
    4. Run 38248679318 (commit 0669fc3), the first run after the owner restarted the CI box, passed the four ACP tab tests.
    5. In attempt 2 of run 38296969149, XCUITest first terminated pid 17443: the app of attempt 1 was still alive about 20 minutes after the alarm stopped `xcodebuild`. `Scripts/test-examples.sh` stops only `xcodebuild` at the time limit. The app under test and the test runner stay.

    ### Conclusion

    The cause is in the CI host session, not in the app code: the system on the CI box does not activate a launched app (for example a locked screen, a display that sleeps, or a session state that a restart clears). The failure follows the state of the box: it failed before the restart without the agent package, it passed after the restart, and it failed again later with the agent package.

    ### Main-actor work on the code paths (no block found on the failing path)

    - `--in-memory-agent`: no `ComposedAgent.compose` call. The in-memory start completes in less than 1 s (CI log).
    - The 32 static initializers of `AgentViewKitDemo.debug.dylib` (MLX `error.cpp`, `fft.cpp`, `reduce.cpp`, `device.cpp`, `metal.cpp`, and xgrammar) set constants. They do not open a Metal device. The local launch reaches the event loop in less than 1.4 s.
    - The Gallery tab copies 8.2 MB of recordings synchronously on the main actor (`RecordedSessionsStage.make(copying:)`). The ACP tests do not open the Gallery tab, so this copy is not on the failing path.

    Thus I cannot write an honest in-process test that fails before a fix: no code defect causes this CI failure.
  timestamp: 2026-10-12T21:12:05.005944+00:00
- actor: claude-code
  id: 01m4rzbempazz10hekr9ms58em
  text: |-
    ### implement — stuck
    - evidence: local launch with `--in-memory-agent` (direct and through `open -n`): the main thread is idle in the event loop at 1.4 s, 3 s, 6 s and 20 s; the app is front (`lsappinfo front`); no TCC request. CI result bundle of run 38296969149: the app logs `initialize`, `session/new` and `session/list` 2 s after launch, accessibility loads, and only the activation fails. Run 38150800563 (commit e41cacd, without FoundationModelsACPAgent) has the same failure. The cause is the session state of the CI box, not the app code. No file in the repository changed. Demo build: BUILD SUCCEEDED. `swift test` not run, because no code changed. Load average 13.04 14.49 15.93. New card 01M4RZB5WBQEA5DZR6PK7N05YP: the time limit of test-examples.sh leaves the app under test alive.
    - next: a person examines the CI box (screen lock, display sleep, login session) and runs the Examples job again, or closes this card.
  timestamp: 2026-10-12T21:12:30.102110+00:00
- actor: claude-code
  id: 01m4rzbzxgxj5x4bgd8rxa73hh
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — no block in the app: local samples (1.4 s to 48 s) show the main thread idle in the event loop and the app in front; the CI app log shows initialize, session/new and session/list 2 s after launch, and only the activation fails; commit e41cacd (before the agent package) has the same failure. Cause: the session state of the CI box (screen lock, display sleep or login session). No file changed.
    - test: not run
    - commit: not run
    - review: not run
    - next: the owner examines the CI box and reruns the Examples job, or closes this card. New card ^k7n05yp: test-examples.sh stops only xcodebuild at its time limit.
  timestamp: 2026-10-12T21:12:47.792199+00:00
- actor: claude-code
  id: 01m4tj40ygntqtm1r0tg36d4fb
  text: |-
    ### CI result after the push of 8c5aef9 (run 38391106969)
    - The owner reports: the screen of the CI box was not locked, and auto-login is set.
    - The 4 ACP tab UI tests passed (10.4 s, 6.3 s, 6.3 s, 9.6 s). The log has 0 "Failed to activate" lines.
    - The change of ^k7n05yp now stops the app under test and the test runner at the time limit. Before it, an app from an earlier attempt stayed alive on the box.
    - next: the owner decides if this card closes.
  timestamp: 2026-10-13T11:59:44.080413+00:00
position_column: doing
position_ordinal: '80'
title: Find why the demo app does not come to the front on CI, with an in-process test that shows it
---
## What
CI runs 38296969149 (commit 7c63709, two attempts): the Examples job fails in `ACPTabEndToEndTests.testASendOfHelloShowsTheReplyOfTheAgent` with "Failed to activate application 'org.agentviewkit.examples.AgentViewKitDemo' (current state: Running Background)", then xcodebuild stops until the time limit of `Scripts/test-examples.sh`. The run before 0e61008 (FoundationModelsACPAgent added to the demo, after the owner restarted the CI box) passed the four ACP tab UI tests. Probable cause: the app main thread blocks at launch since the agent package is in the app (for example package initialization, a Gallery or ACP tab start that runs on the main actor, or MLX setup).

Owner decision (2026-10-12): a sub agent may launch the built demo app on this machine for about 30 seconds and sample it, BUT the fix must come with an in-process test (a package test, not a UI test) that shows the problem.

## Work
- [x] Build the demo and launch it with the UI test launch arguments (`--in-memory-agent` and the ones the UI tests pass). Sample the main thread with `sample` during the first seconds. Quit the app. Record the stack of the block.
- [ ] Write an in-process test first (for example a hosted test that mounts `DemoRootView` / the tab views with the same launch options, or a test of the start code, with a time bound on the main actor work) that fails because of the block.
- [ ] Fix the cause (for example move the agent compose off the main actor, start it lazily only when its tab shows, or remove eager package work at launch).
- [ ] Run the full `swift test` and build the demo. Do not run UI tests on this machine; CI must confirm.

## Blocker (2026-10-12)
The evidence refutes the probable cause. The main thread does not block. See the comments for the full record.

- On this machine the app comes to the front. The main thread is idle in the event loop at 1.4 s after launch.
- On CI (run 38296969149) the app logs `initialize`, `session/new` and `session/list` 2 s after launch: the main actor ran the start of the ACP tab. Only the activation fails.
- Run 38150800563 (commit e41cacd) has the same failure, and that commit does not have FoundationModelsACPAgent in the app.

The cause is the session state of the CI box, not the app code. Thus no in-process test can fail before a fix. A person must decide the next step: for example, examine the CI box (screen lock, display sleep, login session) and run the job again, or close this card.