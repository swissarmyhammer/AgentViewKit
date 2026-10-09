---
assignees:
- claude-code
position_column: todo
position_ordinal: bc80
title: Make the demo agent suites pass in the full swift test run under high machine load
---
## What
In two full `swift test` runs on 2026-10-09 (load average 29 to 80 from other sourcekit-lsp and swift-build processes), the demo agent suites failed at the start of the run. Each failure is "The operation did not end in time." at `ScriptedWireAgent+Bounded.swift` (the 5-second bound), then follow-on failures (for example `ConnectionError.closed`). In the same window, each other test passed after about 5 to 10 seconds, so the whole test process stalled.

Suites: `DemoAgentTests`, `DemoAgentMessageIdTests`, `DemoAgentTerminalSignInTests`, `TerminalAppAuthRunnerTests`. The same suites passed alone right after (`swift test --filter 'DemoAgentTests|DemoAgentMessageIdTests|TerminalAppAuthRunnerTests'`: 34 tests in 5 suites passed in 0.35 s).

^pbgn012 (the main-actor stall card) found no stall in the code and named load from other processes as the probable cause. `ScriptedWireAgentBoundedTests` forbids a bound larger than 5 seconds.

- [ ] Find why the test process stalls for 5 to 10 seconds at the start of a full run under high load.
- [ ] Make the demo agent suites pass in the full run under that load, with no larger bound.

## How to reproduce
Run `swift test` while the load average is above 30 (for example, with other agents that build Swift packages). Found while ^8wb97aa was implemented.