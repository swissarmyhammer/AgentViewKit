---
assignees:
- claude-code
depends_on:
- 01M49GHXXC7CY7R1PRZ83200VG
position_column: todo
position_ordinal: b980
title: Show the unsupported sign-in failures from the client auth state
---
## Start condition
The client session has a task: `ConnectionModel` records `unsupported` in `authState` as `.failed(AuthFailure)` with a reason that has text. Start this task after the client pushes that change. Then remove the tag `blocked-upstream`.

## What
Rule: the agent streams to FoundationModelsACPClient over ACP. The client keeps an observable state. The kit views bind directly to that state and keep no state or logic of their own.

At pin `36f3249`, `login(_:)`, `logout(_:)` and `loginWithTerminal(_:runner:)` throw `ConnectionModelError.unsupported(method:)` and do not change `authState`. Thus `AgentAuthView` has no data to show this failure. This item moved here from ^83200vg.

- [ ] Move the pins in `Package.resolved`, `Benchmarks/Package.resolved` and `Tests/PackageStructureTests/ResolvedPinsTests.swift` to the client commit that records `unsupported` in `authState`.
- [ ] `Sources/AgentViewKit/Connections/AgentAuthView.swift` shows the text of the new `unsupported` reason through the `failureIdentifier` text. The kit keeps no error and no error map.

## Acceptance Criteria
- [ ] `login(_:)` with an unknown method id shows the `unsupported` failure text in the sign-in card.

## Tests
- [ ] Hosted test in `Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift`: `login(_:)` with an unknown method id shows the `unsupported` failure text.
- [ ] Command: `swift test --filter AgentAuthViewHostedTests`. Then `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #blocked-upstream