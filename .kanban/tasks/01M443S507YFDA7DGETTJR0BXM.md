---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4cm88cwyb0k5xmdhddn2dcn
  text: |-
    Research before the work:
    - SessionModel.init is internal in FoundationModelsACPClient. The only public path to a SessionModel is ConnectionModel(coalescingCadence:) plus a transport. ConnectionModel(coalescingCadence:) is public.
    - The benchmark package can link only products. DemoSupport and AgentViewKitTestSupport are not products. Benchmarks/README.md says: put a symbolic link to a test support file in the benchmark target. ScriptedWireAgent.swift imports only AgentViewKit, Foundation and FoundationModelsACP. ScriptedSession.swift also imports DemoSupport, so the benchmark build cannot compile that import.
    - ScriptedSession.open always uses a cadence of zero. The benchmark and the redraw scope test need the default cadence too, so open needs a coalescingCadence parameter.
    - SessionTranscriptViewHostedTests.expectAChunkEvaluatesOnlyTheRowOfItsEntry already checks one chunk over 3 rows with cadence zero. The new test checks 100 chunks over 10 rows with the default cadence.
    - BodyEvaluationCounter exists only in debug builds. The benchmark builds in release, so it uses EvaluationProbe of BenchmarkHost.swift.
    - BenchmarkPolicy.bodyEvaluations and paragraphsParsed have no caller since ^gzj5cye.
  timestamp: 2026-10-08T02:07:37.884202+00:00
- actor: claude-code
  id: 01m4cq3avgjkrd7jqpbrkknag5
  text: |-
    Implementation notes:
    - TDD: SessionModelRedrawScopeTests failed first to compile (no coalescingCadence parameter on ScriptedSession.open). After the parameter, it passed. A temporary change (ItemRow == gives false, and the row list reads the content of each entry) made it fail with 9 issues: the 9 other rows evaluated. The change is reverted.
    - BenchmarkSymlinkTests.theBenchmarkTargetLinksTheScriptedSessionSources and BenchmarkBoundaryTests.benchmarkSourcesDeclareNoObservableClass failed first (no links; a temporary @Observable probe file). Both pass now.
    - What did not work: defaultIsolation(MainActor) on the benchmark target. The benchmark plugin writes __BenchmarkBoilerplate.swift into the target, and its BenchmarkRunnerHooks conformance becomes main actor isolated, which does not compile. Fix: no default isolation in the benchmark target; ScriptedWireAgent and ScriptedSession state @MainActor; ScriptedSession imports DemoSupport only with #if canImport(DemoSupport).
    - The benchmark plugin can only link products, so the benchmark opens the model through ConnectionModel(coalescingCadence:) over the linked ScriptedSession. SessionModel.init is internal.
    - BenchmarkPolicy: removed the count metrics (bodyEvaluations, paragraphsParsed, CountMetric) that had no caller; configuration(iterations:) now.
    - Discovery: with cadence zero, 1,000 chunks cost 10.9 s (about 10 ms for each chunk) because each chunk renders the message again, and TranscriptMessageView joins and splits the whole text for each change. With the default cadence, the same stream costs 209 ms. The cadence-zero scenario records only 3 samples in its 30 s.
    - Baselines recorded at load average 7 to 11 (normal for this machine).
  timestamp: 2026-10-08T02:57:22.288980+00:00
- actor: claude-code
  id: 01m4cq3fpp0yjxzx3gdptjy4qh
  text: |-
    ### implement — changed
    - evidence: 15 paths — Tests/AgentViewKitTests/Thread/SessionModelRedrawScopeTests.swift (new), Benchmarks/Benchmarks/AgentViewKitBenchmarks/SessionModelObservationBenchmarks.swift (new), links Benchmarks/Benchmarks/AgentViewKitBenchmarks/{ScriptedWireAgent,ScriptedSession}.swift (new), Benchmarks/Baselines/AgentViewKitBenchmarks.Transcript_stream,_{cadence_zero,default_cadence}.p90.json (new), Benchmarks/.benchmarkBaselines/AgentViewKitBenchmarks/main/results.json (new), Benchmarks/Package.swift, Benchmarks/README.md, Benchmarks/Benchmarks/AgentViewKitBenchmarks/{Main,BenchmarkPolicy}.swift, Sources/AgentViewKitTestSupport/ScriptedSession.swift, Sources/DemoSupport/ScriptedWireAgent.swift, Tests/PackageStructureTests/{BenchmarkSymlinkTests,BenchmarkBoundaryTests}.swift, Scripts/check-benchmarks.sh. swift test: 1 + 96 + 1021 tests passed, 0 warnings (only the expected mlx-swift "missing creator" warning). Scripts/check-readme.sh exit 0. Scripts/test-examples.sh AgentViewKitDemo passed. swift build --package-path Benchmarks: no warning. Scripts/check-benchmarks.sh exit 0 at load average 10 to 13. Baseline p90: cadence zero 10.9 s and 97.3 G instructions; default cadence 209 ms and 2.73 G instructions; recorded at load average 7 to 11.
    - next: /review. Nothing is committed.
  timestamp: 2026-10-08T02:57:27.254902+00:00
- actor: claude-code
  id: 01m4cqpndv6awqkbyz3s8t19sg
  text: |-
    ### test - green
    - evidence: `swift test` - 1021 tests in 110 suites passed, 0 failed, 0 skipped. `Scripts/check-readme.sh` - passed (3 snippets). `Scripts/test-examples.sh AgentViewKitDemo` - passed (4 UI tests, 0 failures). `swift build --package-path Benchmarks` - build complete. `Scripts/check-benchmarks.sh` - passed on the first run, no threshold or baseline change.
    - load: uptime before the benchmark gate was 5.89 11.49 13.84. After it, 7.93 9.80 12.44. No time-limit failure occurred.
    - warnings seen: only the expected mlx-swift "missing creator for mutated node" and the Xcode AppIntents notice.
    - next: review
    step: test
    outcome: green
    evidence: swift test 1021/110 suites passed; check-readme passed; test-examples AgentViewKitDemo 4 UI tests passed; Benchmarks build complete; check-benchmarks passed; load 5.89 11.49 13.84 before, 7.93 9.80 12.44 after
    task: ^tjr0bxm
  timestamp: 2026-10-08T03:07:55.707515+00:00
depends_on:
- 01M443RKGV6F3SAJAVGGZJ5CYE
position_column: doing
position_ordinal: '80'
title: Add an observation benchmark for the transcript view over SessionModel
---
## What
The FoundationModels observation benchmark is removed. Add a benchmark that measures the cost of the transcript view when a `SessionModel` gets many chunks, and a test that checks the redraw scope. Source: update.md §7 item 2 ("write them again against the client models"). Owner rule (2026-10-06): the transcript view binds directly to the `TranscriptEntry` objects of `SessionModel`. The benchmark measures that direct binding: the chunks go through the coalescing of the model (`SessionModel.defaultCoalescingCadence`), with no kit coalescer and no kit copy of the text in the path.

- [x] Add `Benchmarks/Benchmarks/AgentViewKitBenchmarks/SessionModelObservationBenchmarks.swift`: 1,000 `agent_message_chunk` updates into one `SessionModel` (cadence `.zero` and the default cadence), with the transcript view hosted. Measure the time.
- [x] Add the `FoundationModelsACP` and `FoundationModelsACPClient` products to `Benchmarks/Package.swift` if the benchmark needs them.
- [x] Record the baselines in `Benchmarks/Baselines/`.
- [x] Add `Tests/AgentViewKitTests/Thread/SessionModelRedrawScopeTests.swift`: with `BodyEvaluationCounter`, stream 100 chunks into one agent message in a transcript of 10 rows, and assert that the body count of the other 9 rows does not grow, and that the streamed row shows the text of the entry object after the last flush.

## Acceptance Criteria
- [x] The benchmark runs in `Scripts/check-benchmarks.sh` and its baselines are committed.
- [x] `SessionModelRedrawScopeTests` passes: only the streamed row evaluates its body, and the row text equals the text of the model entry.
- [x] The measured path has no kit `@Observable` object between the entry and the row view.

## Tests
- [x] `swift test --filter SessionModelRedrawScopeTests` passes.
- [x] `Scripts/check-benchmarks.sh` exits with 0.
- [x] `Tests/PackageStructureTests/BenchmarkSymlinkTests.swift` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.