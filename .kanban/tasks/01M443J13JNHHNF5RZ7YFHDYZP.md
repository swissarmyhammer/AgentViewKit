---
assignees:
- claude-code
depends_on:
- 01M443HB3E33J2VKEYYF9NN7AX
position_column: todo
position_ordinal: '8780'
title: 'First pin move: FoundationModelsACP acf7700 and FoundationModelsACPClient 108e2d6 in the three Package.resolved files'
---
## What
Move the pins to a pair that is consistent and still has the old client API. Source: update.md §7 item 3 ("Now").

**Do not run a plain `swift package update`.** It takes the newest `main` of the two packages, and that removes the old client API. Pin each package to the given revision.

If FoundationModelsACPClient `a65af8a` (or later) is pushed when this task starts, skip this task. The second pin move task does the move in one step.

- [ ] Move FoundationModelsACP from `3b0a4fd` to `acf7700` (alpha.3 with the trace context codec), and FoundationModelsACPClient from `144b168` to `108e2d6`, in the root `Package.resolved`.
- [ ] Do the same move in `Benchmarks/Package.resolved` and in the `Package.resolved` of `Examples/AgentViewKitDemo/AgentViewKitDemo.xcodeproj`.
- [ ] Make sure that the graph resolves. It brings `swift-metrics`, `swift-otel` and swift-log 1.15.1 or later. The Router and Extras pins go away, because the targets that used them are removed.

## Acceptance Criteria
- [ ] The three `Package.resolved` files give the same revisions for FoundationModelsACP and FoundationModelsACPClient.
- [ ] `swift build --build-tests`, `swift test`, `Scripts/check-benchmarks.sh`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Tests
- [ ] Add `Tests/PackageStructureTests/ResolvedPinsTests.swift`: it reads the three `Package.resolved` files and asserts that each in-family package has the same revision in each file. Use `PackageFileSupport`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.