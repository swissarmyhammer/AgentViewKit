---
assignees:
- claude-code
depends_on:
- 01M443RKGV6F3SAJAVGGZJ5CYE
position_column: todo
position_ordinal: a480
title: Add an observation benchmark for the transcript view over SessionModel
---
## What
The FoundationModels observation benchmark is removed. Add a benchmark that measures the cost of the transcript view when a `SessionModel` gets many chunks, and a test that checks the redraw scope. Source: update.md §7 item 2 ("write them again against the client models"). Owner rule (2026-10-06): the transcript view binds directly to the `TranscriptEntry` objects of `SessionModel`. The benchmark measures that direct binding: the chunks go through the coalescing of the model (`SessionModel.defaultCoalescingCadence`), with no kit coalescer and no kit copy of the text in the path.

- [ ] Add `Benchmarks/Benchmarks/AgentViewKitBenchmarks/SessionModelObservationBenchmarks.swift`: 1,000 `agent_message_chunk` updates into one `SessionModel` (cadence `.zero` and the default cadence), with the transcript view hosted. Measure the time.
- [ ] Add the `FoundationModelsACP` and `FoundationModelsACPClient` products to `Benchmarks/Package.swift` if the benchmark needs them.
- [ ] Record the baselines in `Benchmarks/Baselines/`.
- [ ] Add `Tests/AgentViewKitTests/Thread/SessionModelRedrawScopeTests.swift`: with `BodyEvaluationCounter`, stream 100 chunks into one agent message in a transcript of 10 rows, and assert that the body count of the other 9 rows does not grow, and that the streamed row shows the text of the entry object after the last flush.

## Acceptance Criteria
- [ ] The benchmark runs in `Scripts/check-benchmarks.sh` and its baselines are committed.
- [ ] `SessionModelRedrawScopeTests` passes: only the streamed row evaluates its body, and the row text equals the text of the model entry.
- [ ] The measured path has no kit `@Observable` object between the entry and the row view.

## Tests
- [ ] `swift test --filter SessionModelRedrawScopeTests` passes.
- [ ] `Scripts/check-benchmarks.sh` exits with 0.
- [ ] `Tests/PackageStructureTests/BenchmarkSymlinkTests.swift` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.