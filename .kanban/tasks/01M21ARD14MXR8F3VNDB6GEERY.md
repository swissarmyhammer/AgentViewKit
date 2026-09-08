---
depends_on:
- 01M21AH4QCEFEBPTZ8GR061H51
- 01M21AGTHBZSXFCZHZE5A7FQWQ
position_column: todo
position_ordinal: ac80
title: 'Benchmarks: Textual streaming cost and observation granularity with committed baselines (plan §8, research R1 and R4)'
---
## What
Create a separate benchmark package at `Benchmarks/` with `ordo-one/benchmark`, the same shape as `../EditorKit/Benchmarks`, plus `Scripts/check-benchmarks.sh`. This task settles research R1 and R4 with numbers, and records both decisions in `Benchmarks/README.md`.

- `StreamingBenchmarks`: feed a 2,000-line Markdown message at 50 tokens per second into `StreamingMessage` and render through `ResponseView` in a hosted view. Measure time per chunk and body evaluations per chunk with the paragraph split on and off. The gate: with the split on, the p90 per-chunk cost stays under 4 ms and settled paragraphs are not re-evaluated.
- `ObservationBenchmarks`: with a fake `LanguageModel`, stream 1,000 chunks through `SessionThreadSource` and count invalidations of an observer on `thread.items` versus one on `thread.streaming[id]`. The gate: the items observer fires only on entry boundaries. Compare `Snapshot.transcriptEntries` and `SessionPropertyValues.history` as the tail source and record which one the source uses.
- Commit p90 baselines under `Benchmarks/Baselines/`. The script fails when a run regresses past the threshold.

## Acceptance Criteria
- [ ] `swift package --package-path Benchmarks benchmark` runs both suites.
- [ ] Baselines exist and `Scripts/check-benchmarks.sh` passes on the committed run.
- [ ] `Benchmarks/README.md` records the R1 and R4 decisions with the numbers.

## Tests
- [ ] The benchmark gates above, run by `Scripts/check-benchmarks.sh`.
- [ ] `Tests/AgentViewKitTests/Streaming/ParagraphReuseTests.swift`: the "settled paragraphs are not re-evaluated" property as a fast unit test.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.