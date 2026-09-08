---
depends_on:
- 01M21BD0YVS2J4MD6VXDM317W6
- 01M21BYFK7KVCKXYXJFCJW7FSM
- 01M21A9KJGPPJE0X01JE0B9V33
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: c880
title: AgentThreadActions protocol, NoopThreadActions, and ThreadFixtures (plan §3.4)
---
## What
Create `Sources/AgentViewKit/Model/AgentThreadActions.swift`, `Sources/AgentViewKit/Model/UserInput.swift`, `Sources/AgentViewKitTestSupport/NoopThreadActions.swift`, and `Sources/AgentViewKitTestSupport/ThreadFixtures.swift`, per plan.md §3.4.

- `UserInput { text: String; attachments: [Attachment] }`. `Attachment` here is the value type from the attachments task; until that task lands, use `[URL]` and rename in that task.
- `AgentThreadActions` (`AnyObject`, `@MainActor`): `send(_ input: UserInput) async`, `cancel() async`, `respond(to: PermissionRequest, _ decision: PermissionDecision) async`, `respond(to: ElicitationRequest, _ result: ElicitationResult) async`, `setConfigOption(_ id: ConfigOptionID, _ value: ConfigValue) async`, `connect(_ request: AuthorizationRequest) async throws`, `login(_ methodId: AuthMethodID) async throws`, `runTerminalAuth(_ method: AuthMethod.Terminal) async throws`, `logout() async throws`.
- `EnvironmentValues.threadActions` and `.threadActions(_:)`. The default is a `NoopThreadActions` that logs at `debug`.
- `NoopThreadActions`: records every call in order as `enum Call` values with their arguments; `calls` is readable and `reset()` clears it. Optional closures per verb let a test throw or delay.
- `ThreadFixtures`: builders for a `Message`, a `ToolCallRecord` per status, a `Reasoning`, a `PermissionRequest` with four options, an `ElicitationRequest` in both modes, and `sampleThread(items:)`.

## Acceptance Criteria
- [ ] Each of the nine verbs on `NoopThreadActions` appends one `Call` with the arguments passed.
- [ ] `reset()` leaves `calls` empty.
- [ ] `ThreadFixtures.sampleThread(items: 5)` returns a thread with five items and distinct ids.

## Tests
- [ ] `Tests/AgentViewKitTests/TestSupport/NoopThreadActionsTests.swift`: one test per verb, reset, and a throwing closure.
- [ ] `Tests/AgentViewKitTests/TestSupport/ThreadFixturesTests.swift`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.