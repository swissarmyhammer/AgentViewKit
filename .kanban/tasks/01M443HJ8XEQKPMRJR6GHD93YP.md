---
assignees:
- claude-code
depends_on:
- 01M443H1PVEMMXJ3E2VK9MXMEM
position_column: todo
position_ordinal: '8580'
title: Remove the FoundationModels benchmarks and their baselines
---
## What
`Benchmarks/Package.swift` uses the `AgentViewKitFoundationModels` product, and the observation benchmarks import it and FoundationModels. After the target removal, the benchmark gate (`Scripts/check-benchmarks.sh`) fails. Source: update.md §7 item 2.

- [ ] Remove the `AgentViewKitFoundationModels` product and the FoundationModels import from `Benchmarks/Package.swift` and from the files in `Benchmarks/Benchmarks/AgentViewKitBenchmarks/`.
- [ ] Remove the benchmarks that need FoundationModels: "Observation, SessionThreadSource over 1,000 chunks", and the three "Tail source" benchmarks (`session.transcript`, `SessionPropertyValues.history`, `Snapshot.transcriptEntries`).
- [ ] Delete their baseline files in `Benchmarks/Baselines/`. Keep the two "Streaming chunk, paragraph split" benchmarks and baselines.
- [ ] Change `Benchmarks/README.md`. A later task adds an observation benchmark against `SessionModel`.

## Acceptance Criteria
- [ ] No file in `Benchmarks/` imports FoundationModels or `AgentViewKitFoundationModels`.
- [ ] `Scripts/check-benchmarks.sh` passes against the committed baselines.

## Tests
- [ ] `Tests/PackageStructureTests/BenchmarkSymlinkTests.swift` passes. Change it if it lists the removed benchmarks.
- [ ] `Scripts/check-benchmarks.sh` exits with 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.