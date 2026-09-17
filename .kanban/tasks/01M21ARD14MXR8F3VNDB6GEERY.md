---
comments:
- actor: claude-code
  id: 01m2nxv1fq2ekszp9z52btkq11
  text: 'Note from ^r061h51: the body evaluation keys are `ParagraphView.counterKey(messageID:paragraphID:)` (`paragraph-<message id>-<index>-<hash>`) and `ResponseView.tailCounterKey(messageID:)` (`response-tail-<message id>`). Tests/AgentViewKitTests/Content/ResponseViewHostedTests.swift shows how to reset and read them.'
  timestamp: 2026-09-16T20:16:56.823217+00:00
- actor: claude-code
  id: 01m2pr3jhk1jjkk5zmca3m6a7c
  text: |-
    ### finish iteration 1 — findings
    - implement: added the Benchmarks package, the check script, ParagraphReuseTests, the resumed paragraph split, the lazy settled paragraphs in scroll views, the streaming-turn fix in SessionThreadSource, and ChangeCounter in the test support target.
    - test: swift test passed. AgentViewKitTests 1003, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 44. Scripts/check-benchmarks.sh passed (split-on p90 3.18 ms).
    - commit: 01167d0.
    - review: 6 findings (5 magic numbers, 1 print). Back to implement.
  timestamp: 2026-09-17T03:55:59.411652+00:00
- actor: claude-code
  id: 01m2prpzqpycf5d8ahcx1j3eba
  text: |-
    ### finish iteration 2 — clean
    - implement: named each benchmark number (HostConstants, StreamingIterations, the workbench constants) and moved the p90 report from print to the unified log.
    - test: swift test passed. AgentViewKitTests 1003, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 22, AgentViewKitFoundationModelsTests 44. Scripts/check-benchmarks.sh passed.
    - commit: 9b895f3.
    - review: 0 new findings. All prior findings checked. Moved to done.
  timestamp: 2026-09-17T04:06:35.510012+00:00
depends_on:
- 01M21AH4QCEFEBPTZ8GR061H51
- 01M21AGTHBZSXFCZHZE5A7FQWQ
position_column: done
position_ordinal: b880
title: 'Benchmarks: Textual streaming cost and observation granularity with committed baselines (plan §8, research R1 and R4)'
---
## What
Create a separate benchmark package at `Benchmarks/` with `ordo-one/benchmark`, the same shape as `../EditorKit/Benchmarks`, plus `Scripts/check-benchmarks.sh`. This task settles research R1 and R4 with numbers, and records both decisions in `Benchmarks/README.md`.

- `StreamingBenchmarks`: feed a 2,000-line Markdown message at 50 tokens per second into `StreamingMessage` and render through `ResponseView` in a hosted view. Measure time per chunk and body evaluations per chunk with the paragraph split on and off. The gate: with the split on, the p90 per-chunk cost stays under 4 ms and settled paragraphs are not re-evaluated.
- `ObservationBenchmarks`: with a fake `LanguageModel`, stream 1,000 chunks through `SessionThreadSource` and count invalidations of an observer on `thread.items` versus one on `thread.streaming[id]`. The gate: the items observer fires only on entry boundaries. Compare `Snapshot.transcriptEntries` and `SessionPropertyValues.history` as the tail source and record which one the source uses.
- Commit p90 baselines under `Benchmarks/Baselines/`. The script fails when a run regresses past the threshold.

## Acceptance Criteria
- [x] `swift package --package-path Benchmarks benchmark` runs both suites.
- [x] Baselines exist and `Scripts/check-benchmarks.sh` passes on the committed run.
- [x] `Benchmarks/README.md` records the R1 and R4 decisions with the numbers.

## Tests
- [x] The benchmark gates above, run by `Scripts/check-benchmarks.sh`.
- [x] `Tests/AgentViewKitTests/Streaming/ParagraphReuseTests.swift`: the "settled paragraphs are not re-evaluated" property as a fast unit test.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 22:49)

- [x] `Benchmarks/Benchmarks/AgentViewKitBenchmarks/BenchmarkHost.swift:23` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Benchmarks/Benchmarks/AgentViewKitBenchmarks/BenchmarkHost.swift:26` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Benchmarks/Benchmarks/AgentViewKitBenchmarks/StreamingBenchmarks.swift:58` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Benchmarks/Benchmarks/AgentViewKitBenchmarks/StreamingBenchmarks.swift:59` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Benchmarks/Benchmarks/AgentViewKitBenchmarks/StreamingBenchmarks.swift:121` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Benchmarks/Benchmarks/AgentViewKitBenchmarks/StreamingBenchmarks.swift:198` `code-hygiene/disallowed-constructs-swift` — no_direct_standard_out_logs: Do not commit print(…), debugPrint(…), dump(…) or _printChanges(), which write to standard out in release. Log to a dedicated logging system, or silence one debug-only line with // swiftlint:disable:next no_direct_standard_out_logs and the reason after it.

## Review Findings (2026-09-16 23:04)

No new findings. The review of 9b895f3 is clean.