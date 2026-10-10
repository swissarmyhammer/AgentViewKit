---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4k35bv2ax075e0hnpyv0h5g
  text: |-
    Research and work notes:
    - `git ls-files Benchmarks` listed 13 tracked files. `git rm` removed them. `Benchmarks/.build` is untracked; this step did not touch it.
    - `Benchmarks/README.md` held the R1 and R4 numbers. plan.md §14 R1 and R4 now keep the numbers inline (R1: 3.3 ms per chunk with the split, 86 ms with no split; R4: 209 ms for 1,000 chunks at the default cadence, 10.9 s at cadence zero), say that the package is removed, and name `ParagraphReuseTests` and `SessionModelRedrawScopeTests`.
    - `ScriptedSession.swift` had `#if canImport(DemoSupport)` only for the benchmark link. `AgentViewKitTestSupport` always depends on `DemoSupport` (Package.swift), so the file now has a plain `import DemoSupport`.
    - The root targets use `.defaultIsolation(MainActor.self)`, so `@MainActor` on `ScriptedWireAgent` and `ScriptedSession` was only for the benchmark target. The attribute stays; only the comment changed.
    - `ResolvedPinsTests` now checks one committed file (`rootPath = "Package.resolved"`). The parameterized test became `theRootFilePinsTheExpectedACPRevisions`.
    - The only remaining matches for "benchmark" outside `.kanban/` are the two plan.md sentences that say the package is removed. The task order asks for these sentences.
  timestamp: 2026-10-10T14:23:38.338979+00:00
- actor: claude-code
  id: 01m4k3gx01th46vz4107q9w6az
  text: |-
    ### implement — changed
    - evidence: removed 16 tracked files (13 in `Benchmarks/`, `Scripts/check-benchmarks.sh`, `BenchmarkSymlinkTests.swift`, `BenchmarkBoundaryTests.swift`); changed 9 files (`.github/workflows/ci.yml`, `README.md`, `plan.md`, `Sources/AgentViewKitTestSupport/ScriptedSession.swift`, `Sources/DemoSupport/ScriptedWireAgent.swift`, `Tests/AgentViewKitTests/Streaming/ParagraphReuseTests.swift`, `Tests/AgentViewKitTests/Thread/SessionModelRedrawScopeTests.swift`, `Tests/PackageStructureTests/ResolvedPinsTests.swift`, `Tests/PackageStructureTests/DecisionRecordTests.swift`). `Scripts/check-readme.sh` passed. `swift test`: 1040 tests in 110 suites passed, 0 failures, load average about 36 to 51. The build printed one warning that this change did not cause: "missing creator for mutated node" for the `mlx-swift_Cmlx.bundle` dependency bundle.
    - next: /review. The task stays in `doing`. No commit.
  timestamp: 2026-10-10T14:29:56.353099+00:00
position_column: doing
position_ordinal: '80'
title: Remove the Benchmarks package and the benchmark gate
---
## What
Decision (2026-10-10, owner): the `Benchmarks/` package was temporary content. It was used to decide the design (research R1 and R4). Remove it and the benchmark gate. The deterministic tests in the root package stay: `ParagraphReuseTests` and `SessionModelRedrawScopeTests`.

- [x] Delete the tracked files of `Benchmarks/` (sources, the three links, `Package.swift`, `Package.resolved`, `README.md`, `Baselines/`, `.benchmarkBaselines/`) with `git rm -r`. Do not touch `Benchmarks/.build`: a separate `rm -rf` deletes it now.
- [x] Delete `Scripts/check-benchmarks.sh`.
- [x] Remove the `benchmarks` job and its comments from `.github/workflows/ci.yml`.
- [x] Delete `Tests/PackageStructureTests/BenchmarkSymlinkTests.swift` and `Tests/PackageStructureTests/BenchmarkBoundaryTests.swift`.
- [x] Change `ResolvedPinsTests` so that it does not read `Benchmarks/Package.resolved`, and change `DecisionRecordTests` so that it does not scan `Benchmarks/` files or `Scripts/check-benchmarks.sh`.
- [x] Remove the benchmark text from `README.md` ("The benchmark gate" and the script list) and from `plan.md` (§8 gate). Keep the R1 and R4 results in `plan.md`, but say that the benchmark package is removed and name the tests that keep the guarantees.
- [x] Remove the text that names `Benchmarks/` from the doc comments in `Sources/` and `Tests/` (for example `ScriptedWireAgent.swift`, `ScriptedSession.swift`, `ParagraphReuseTests.swift`, `SessionModelRedrawScopeTests.swift`). If `@MainActor` on `ScriptedWireAgent` was only for the benchmark target, keep it and change only the comment.
- [x] Search the repository (not `.kanban/`) for `Benchmark`, `benchmark` and `check-benchmarks`, and remove each reference that remains.

## Acceptance Criteria
- [x] No tracked file in `Benchmarks/` remains, and `Scripts/check-benchmarks.sh` is gone.
- [x] CI has no benchmark job.
- [x] `Scripts/check-readme.sh` passes.

## Tests
- [x] `swift test` passes.