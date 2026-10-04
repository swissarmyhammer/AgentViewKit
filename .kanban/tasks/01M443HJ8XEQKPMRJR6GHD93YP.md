---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m44gny5zhgyh6dppzghym694
  text: |-
    Research:
    - All four FoundationModels scenarios are in `ObservationBenchmarks.swift`. The file imports AgentViewKitFoundationModels and FoundationModels. The full file goes.
    - `FakeLanguageModel.swift` in the benchmark target is a symbolic link to `Sources/DemoSupport/FakeLanguageModel.swift` (not to the test target, as the Package.swift comment says). It imports FoundationModels. The link goes.
    - `ChangeCounter.swift` (link to `Sources/AgentViewKitTestSupport/ChangeCounter.swift`) has no user other than `ObservationBenchmarks`. After the removal it is dead code in the benchmark target. Then the benchmark target has no symbolic link, and `BenchmarkSymlinkTests.theBenchmarkTargetHasLinks` fails.
    - `BenchmarkPolicy` has members that only the observation scenarios use: `itemsInvalidations`, `streamingInvalidations`, `tailUpdates(gated:)`, `recordedCount`, and the `gated` parameter of `configuration`. They become dead code.
    - The gate reads a second baseline: `Benchmarks/.benchmarkBaselines/AgentViewKitBenchmarks/main/results.json`. It holds an entry for each of the six scenarios. The four removed entries must go from this file too, not only from `Benchmarks/Baselines/`.
    - `ImportScanner` in PackageStructureTests can scan `Benchmarks/Benchmarks` for the forbidden imports. It reads a symbolic link file through the link.
  timestamp: 2026-10-04T22:31:16.415629+00:00
- actor: claude-code
  id: 01m44kqjzkqbg07vj631kprs66
  text: |-
    Implementation landed.
    - TDD: new `Tests/PackageStructureTests/BenchmarkBoundaryTests.swift` (2 tests: the benchmark sources import no FoundationModels or AgentViewKitFoundationModels module; `Benchmarks/Package.swift` links no such product). RED: both failed on FakeLanguageModel.swift, ObservationBenchmarks.swift and the manifest product. GREEN after the removal.
    - Removed `ObservationBenchmarks.swift`, the `FakeLanguageModel.swift` link and the `ChangeCounter.swift` link (no user left), the four baseline files in `Benchmarks/Baselines/`, and the four scenario entries in `Benchmarks/.benchmarkBaselines/AgentViewKitBenchmarks/main/results.json`. The two streaming entries in that file are byte for byte the same as before.
    - `BenchmarkPolicy`: removed the dead members `itemsInvalidations`, `streamingInvalidations`, `tailUpdates(gated:)`, `recordedCount` and the `gated` parameter. The streaming configuration is the same.
    - `BenchmarkSymlinkTests`: removed `theBenchmarkTargetHasLinks`, because the target has no link now. `eachLinkOfTheBenchmarkTargetPointsAtAFile` stays for a later link.
    - Docs: `Benchmarks/README.md` (scenarios, metrics, gates, policy; R4 kept as a record because `SessionThreadSource` still points to it), `Benchmarks/Package.swift` header, `Main.swift`, `Scripts/check-benchmarks.sh` header, and the `ChangeCounter` doc comment.
    - `Benchmarks/Package.resolved` changed when the package resolved: it only removes pins that the root package no longer uses (Router, mlx and others, left from the Router removal). No remaining pin moved.
    - Discovery: under the load of other sessions on this machine (load average 15 to 32), the "Streaming chunk, paragraph split on" scenario fails its own 4 ms p90 gate (4.2 to 4.6 ms). An unchanged copy of HEAD failed the same way (4.23 ms), so the cause is the load, not this change. A later run passed.
  timestamp: 2026-10-04T23:24:36.211779+00:00
- actor: claude-code
  id: 01m44kqp3bgy21y4q8xk6x53nf
  text: |-
    ### implement — changed
    - evidence: 16 paths — Tests/PackageStructureTests/BenchmarkBoundaryTests.swift (new), Tests/PackageStructureTests/BenchmarkSymlinkTests.swift, Benchmarks/Package.swift, Benchmarks/Package.resolved, Benchmarks/README.md, Benchmarks/Benchmarks/AgentViewKitBenchmarks/{Main,BenchmarkPolicy}.swift, deleted {ObservationBenchmarks,FakeLanguageModel,ChangeCounter}.swift, 4 deleted Benchmarks/Baselines/*.p90.json, Benchmarks/.benchmarkBaselines/AgentViewKitBenchmarks/main/results.json, Scripts/check-benchmarks.sh, Sources/AgentViewKitTestSupport/ChangeCounter.swift. `swift test`: 1528 tests passed, 0 warnings. `Scripts/check-benchmarks.sh`: exit 0 on the last run (3 earlier runs failed the 4 ms p90 gate under machine load; HEAD failed the same way).
    - next: /review
  timestamp: 2026-10-04T23:24:39.403442+00:00
- actor: claude-code
  id: 01m44m0vcsrdp4m7kfb388kpc8
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 332dfa8). 0 findings, 0 confirmed, 0 refuted. 10 files reviewed. 7 files had no matching validator (baseline JSON files, Package.resolved, README.md). The engine declined some rule items only for the three deleted Swift files.
    - next: task moved to done
  timestamp: 2026-10-04T23:29:39.737898+00:00
- actor: claude-code
  id: 01m44m0wt6t0htwv2phx2rs1kz
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — removed the FoundationModels benchmark scenarios, links and baselines; BenchmarkBoundaryTests (new); BenchmarkSymlinkTests, BenchmarkPolicy, docs
    - test: green — swift test, 1528 passed
    - commit: 332dfa8
    - review: clean — 0 findings
  timestamp: 2026-10-04T23:29:41.190778+00:00
depends_on:
- 01M443H1PVEMMXJ3E2VK9MXMEM
position_column: done
position_ordinal: d380
title: Remove the FoundationModels benchmarks and their baselines
---
## What
`Benchmarks/Package.swift` uses the `AgentViewKitFoundationModels` product, and the observation benchmarks import it and FoundationModels. After the target removal, the benchmark gate (`Scripts/check-benchmarks.sh`) fails. Source: update.md §7 item 2.

- [x] Remove the `AgentViewKitFoundationModels` product and the FoundationModels import from `Benchmarks/Package.swift` and from the files in `Benchmarks/Benchmarks/AgentViewKitBenchmarks/`.
- [x] Remove the benchmarks that need FoundationModels: "Observation, SessionThreadSource over 1,000 chunks", and the three "Tail source" benchmarks (`session.transcript`, `SessionPropertyValues.history`, `Snapshot.transcriptEntries`).
- [x] Delete their baseline files in `Benchmarks/Baselines/`. Keep the two "Streaming chunk, paragraph split" benchmarks and baselines.
- [x] Change `Benchmarks/README.md`. A later task adds an observation benchmark against `SessionModel`.

## Acceptance Criteria
- [x] No file in `Benchmarks/` imports FoundationModels or `AgentViewKitFoundationModels`.
- [x] `Scripts/check-benchmarks.sh` passes against the committed baselines.

## Tests
- [x] `Tests/PackageStructureTests/BenchmarkSymlinkTests.swift` passes. Change it if it lists the removed benchmarks.
- [x] `Scripts/check-benchmarks.sh` exits with 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.