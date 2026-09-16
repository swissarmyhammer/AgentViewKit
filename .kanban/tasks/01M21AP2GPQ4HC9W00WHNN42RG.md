---
comments:
- actor: claude-code
  id: 01m2p56843cy7t2frwh1a8dgr3
  text: 'Note from ^2pzwgz2 (TerminalView, done): show the terminal auth process with `TerminalView(record:rowLimit:model:stdin:)` (Sources/AgentViewKit/Terminal/TerminalView.swift). Read the record from `thread.terminals[id]` (ACPThreadActions.runTerminalAuth writes it). Pass `stdin:` to show the single-line input field; the closure gets each line with no newline at the end, so the caller must add "\n" before it writes to the process. The field is disabled after `exitStatus` is set. The footer shows "Exit code N", "Stopped by SIGNAL", or "Exited". Accessibility identifiers are static members of TerminalView (`inputIdentifier`, `footerIdentifier`, `progressIdentifier`).'
  timestamp: 2026-09-16T22:25:24.099171+00:00
- actor: claude-code
  id: 01m2p5ppjghk3j5a4qzmprmbdh
  text: |-
    ### finish iteration 1 — done
    - implement: Added AgentAuthView, TerminalRecord.authID(for:), and the new verb AgentThreadActions.writeTerminalLine(_:to:). ACP writes the line to the running process. The Router and logging actions only log. Added FakeProcessLauncher keepsOutputOpen and finishOutput(). The host placement (in the thread and in settings) goes to the demo app task ^ny9e8rr. (The "^RR" text in the description means ^ny9e8rr.)
    - test: swift test exit 0. PackageFileSupportTests 20, AgentViewKitTests 846 (was 835), AgentViewKitRouterTests 71, AgentViewKitFoundationModelsTests 1, AgentViewKitACPTests 93. No new warnings.
    - commit: 2a4a88f feat(connections): add AgentAuthView with sign in, terminal auth input, and sign out (^hnn42rg)
    - review: review sha HEAD~1..HEAD, 11 files, 0 findings. Clean.
  timestamp: 2026-09-16T22:34:23.184369+00:00
depends_on:
- 01M21AFDM0RPN9SPB5D35Y2FDR
- 01M21AJ767SWK19SZA82PZWGZ2
- 01M21AGCKBQJRDAVFZD6Q9P7JZ
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: done
position_ordinal: ac80
title: 'AgentAuthView: agent and terminal auth methods with sign-out (plan §9 E2, §12)'
---
## What
Create `Sources/AgentViewKit/Connections/AgentAuthView.swift`, per plan.md §9 E2 and §12 item 5.

- `AgentAuthView(methods: [AuthMethod], isAuthenticated: Bool)`: one row per method. An `agent` method shows a Sign in button that calls `AgentThreadActions.login(methodId)`. A `terminal` method shows a Run button that calls `runTerminalAuth(method)` and then hosts the returned `TerminalRecord` in a `TerminalView` with `stdin` enabled. When authenticated, a Sign out button calls `logout()`.
- The view appears in-thread when the ACP source reports `authenticationRequired` (error code -32000) and in the settings surface next to `ConnectionsView`.
- The `terminal` method never calls `login`.

## Acceptance Criteria
- [x] An `agent` row calls `login` with the method id.
- [x] A `terminal` row calls `runTerminalAuth` and shows a `TerminalView` with an input field.
- [x] Sign out calls `logout` and is hidden when not authenticated.

## Tests
- [x] `Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift`: the three cases through `NoopThreadActions`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Implementation Notes
- `runTerminalAuth` returns no record. The source writes the record with the id `TerminalRecord.authID(for: methodId)` (`auth-<methodId>`). `AgentAuthView` finds that record in its `thread` argument or in the `agentThread` environment value.
- The input field needs a path to the process. `AgentThreadActions` has the new verb `writeTerminalLine(_:to:)`. `ACPThreadActions` writes the line and a newline to the running process. The Router and logging actions only log.
- The in-thread and settings placement is host work (demo app task ^RR).

## Review Findings (2026-09-16 17:31)

> Scope: `review sha HEAD~1..HEAD` (commit 2a4a88f). 11 files reviewed. 0 findings.