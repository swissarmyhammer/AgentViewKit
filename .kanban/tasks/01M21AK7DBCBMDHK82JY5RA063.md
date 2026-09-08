---
depends_on:
- 01M21AEPX6A1KRH0TQ0D4QV9CP
- 01M21AJ767SWK19SZA82PZWGZ2
- 01M21BD0YVS2J4MD6VXDM317W6
- 01M21BCRF2JZ6W49NKXHE8KKT1
position_column: todo
position_ordinal: 9b80
title: 'PermissionView: request card with options, subject, comment, terminal link, switch to auto (plan §9 E, §12)'
---
## What
Create `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift` and `PendingRequestsHost.swift`, per plan.md §9 E and §12.

- `PermissionView(request:)`: a glass card with the required `title`, the `description`, and the subject: a tool call summary (title and kind) or a command with `command`, `cwd`, and a link that opens the `TerminalView` for `terminalId` when set. One button per option from the request, in the order given, identifier `permission-option-<id>`; `allowAlways` and `rejectAlways` are visually secondary; the primary allow uses `.glassProminent`. A comment field (`permission-comment`) appears on a reject choice. "Switch to auto" (`permission-switch-auto`) appears when a `mode` config option with an `auto` value exists and calls `setConfigOption` before answering. Esc maps to `cancelled`.
- The card calls `AgentThreadActions.respond(to:_:)` with `PermissionDecision`.
- `PendingRequestsHost`: the piece of `AgentThreadView` that renders `thread.pendingPermissions`, `pendingElicitations`, and `pendingAuthorizations` in-thread at the bottom, one card each, identifier `pending-card-<id>`. On a new card it calls the environment `FocusReporter` with the card identifier; on resolve, with `prompt-editor`.

## Acceptance Criteria
- [ ] Four options mount four `permission-option-*` elements in request order.
- [ ] A press on a reject option mounts `permission-comment`; a submit passes the comment in the decision.
- [ ] Esc sends `cancelled`.
- [ ] Adding a request makes `RecordingFocusReporter` record `pending-card-<id>`; resolving it records `prompt-editor`.

## Tests
- [ ] `Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift`: buttons, comment, Esc, focus, through `NoopThreadActions` and `RecordingFocusReporter`.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.