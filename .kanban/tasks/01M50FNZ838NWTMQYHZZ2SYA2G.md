---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m50fpv189y0cbjjn0k28ay1a
  text: |-
    ### Decision from the step owner
    Find the cause by reading first. The test fails only sometimes, so it is a bad test. The fix is an event wait or a direct render pass (T4-A0), not a longer pump. This fix goes in the push with T4-A0, ^yr4zgpz and the MathEngine fix, after one full run.
  timestamp: 2026-10-15T19:13:01.480475+00:00
- actor: claude-code
  id: 01m50g5cdp6nsdw1hzvaxpgvfx
  text: |-
    ### Research (by reading, no test run)
    - Product path: `GrowingResponse.body` reads `growing.text` -> `ResponseView` -> `ParagraphList` -> `ForEach(paragraphs)` keyed by `Paragraph.ID` (index + FNV-1a hash of the text) -> `ParagraphView(...).equatable()`. `ParagraphView` has no `@Environment`, no `@State` and no observable read. Its `==` compares messageID, paragraph, citations and readingGroupID. For paragraph 0 after the chunk " ends here.", all four stay equal in each later chunk (no citations, no message group in the environment, same text, same index). Thus no chunk gives SwiftUI a reason to evaluate it again. The first test (`aChunkThatStartsAParagraph...`) checks the same property with count == 0 and passes.
    - Test path: `append` sets the text, then `pump(until: 2 s)` runs the main run loop in 0.05 s slices until the new last paragraph has a count, then `pump()` runs it 0.05 s more. The counts are read after that. So the run loop runs for a time that a clock sets, between the change and the read.
    - Cause: during those clock-timed run loop turns, the main run loop also handles work that does not belong to the chunk under test: a late part of the SwiftUI update of an earlier chunk, and window or application events from outside the test (the failed run had another test process on the machine; an activation or key-window change makes the hosting view update). An evaluation from such work lands in the measure window of a later chunk. Paragraph 0 had count 2 at the end of chunk 4 (the test skips that check, because paragraph 0 was the last paragraph before chunk 4), and count 3 at a later chunk. Three evaluations with equal input, spread over the chunks and not one for each chunk, agree with this cause. They do not agree with a chunk-driven product defect, which would give one more evaluation at each chunk.
    - Fix: set the text and call `harness.render()` (T4-A0). The pass applies the observation change synchronously with `layoutSubtreeIfNeeded`, with no run loop turn and no clock. The test does not suspend, so no other main-actor work and no run loop source runs between a chunk and its read. Each chunk has exactly one render, in a fixed order. If paragraph 0 still evaluates again, the test then fails each time: that is a real product defect and not a race.
  timestamp: 2026-10-15T19:20:58.038191+00:00
- actor: claude-code
  id: 01m50gc45t5vmx8022t8z5bwes
  text: |-
    ### implement — changed
    - evidence: 1 file, Tests/AgentViewKitTests/Streaming/ParagraphReuseTests.swift. `append` now sets the text and calls `harness.render()` one time (no `pump(until:)`, no `pump()`). Each mount calls `harness.render()` and not `pump()`. The constant `changeWaitSeconds` and the `id` parameter of `append` are removed. Both tests are now synchronous, so they do not suspend. The suite doc states the rule. No assertion is weaker.
    - Cause (from reading, see the research comment): the clock-timed run loop turns of `pump` between a chunk and the read of the counts let other main-run-loop work (a late update of an earlier chunk, or a window or app event from outside, such as another test process) evaluate paragraph 0 in the measure window of a later chunk. The product path gives no reason for that evaluation: `ParagraphView` has no environment, state or observable read, and `==` stays true for paragraph 0. Not a product defect by this evidence. If it were one, the new deterministic test would fail each time.
    - Run: `swift test --filter 'MathEngineDecisionTests|ParagraphReuseTests|PackageFilesTests|SourceLineScannerTests'` one time: `aChunkThatStartsAParagraphEvaluatesOnlyTheChangedParagraphs` passed, `aLongTextNeverEvaluatesAnEarlierParagraphAgain` passed after 0.149 s (it took 14.0 s in the failed run); 8 tests in 2 suites passed.
    - next: review.
  timestamp: 2026-10-15T19:24:38.970835+00:00
- actor: claude-code
  id: 01m50gx5mn71xe91heaf8k1j6k
  text: |-
    ### test - green
    - evidence: One run of swift test. Exit 0. Swift Testing: 1201 tests in 138 suites passed with 2 known issues. 0 failures. 0 skipped. The 2 known issues are expected failures in tests that check the failure path (HostedLayoutExpectationsTests.swift:23:60 and ThemeHeightExpectationsTests.swift:35:61). Both tests passed.
    - warnings: 0 from project sources. Only the mlx-swift "missing creator for mutated node" warning from a dependency.
    - readme gate: Scripts/check-readme.sh passed.
    - resolved revisions: FoundationModelsACPClient 9cedcb9cf6b5e21f01ed2d3ef469f99d6666cd5a; FoundationModelsACP fb55b2fe90c124863dc3e5e907cd0ff070f61885; FoundationModelsACPAgent 180333bac6d48bc87ddd2cdd3522e95e7cb96599; FoundationModelsRouter fa9bf08885099ad4397772750eb98ad9323ce04e; FoundationModelsExtras dbd91deb34062d9e25655ed64bd41f0d7493cc0d.
    - log: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/43998bc3-6f4e-4bb7-909b-93c5172edb4f/scratchpad/swift-test-7.log
    - next: Push is decided by this green result.
  timestamp: 2026-10-15T19:33:57.525303+00:00
- actor: claude-code
  id: 01m50htjyf20rt6630khjh6kwj
  text: |-
    ### review — clean
    - evidence: review sha 277f657~1..277f657 — 0 findings (0 confirmed, 0 refuted, 7 attempted, 0 failed). 1 file reviewed.
    - next: none. The task moved to done.
  timestamp: 2026-10-15T19:50:01.423932+00:00
- actor: claude-code
  id: 01m50hv52vjhfx8mbrryv1ers2
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — ParagraphReuseTests.swift (direct render for each chunk)
    - test: green — swift test, 1201 passed in 138 suites (1 run)
    - commit: 277f657 (pushed)
    - review: clean — 0 findings
  timestamp: 2026-10-15T19:50:19.995301+00:00
position_column: done
position_ordinal: ffc380
title: 'Mail step 7: aLongTextNeverEvaluatesAnEarlierParagraphAgain failed one time (an earlier paragraph evaluated again)'
---
Found in the full run of the rebased push branch. A test that fails only sometimes is a bad test: find the cause and make it deterministic, or fix the race. Do not run it again and again.

- Test: `aLongTextNeverEvaluatesAnEarlierParagraphAgain()` at Tests/AgentViewKitTests/Streaming/ParagraphReuseTests.swift:129.
- Failure: "The earlier paragraph paragraph-paragraph-reuse-long-0-5072fc234dbf37f8 evaluated again." `current[key]` was 3, `count` was 2. The test took 14.0 s. Another test process ran on the machine at the same time.
- The test waits with `harness.pump()` (a fixed 0.05 s run of the run loop) and the `append` helper. During a timed run of the run loop, other events (for example a window or appearance change, or a late update of the earlier chunk) can make SwiftUI evaluate a body again. Find the cause by reading the code (ParagraphView, GrowingResponse, the append helper, BodyEvaluationCounter): which event can evaluate paragraph 0 a third time.
- Fix: use the direct render pass of T4-A0 (`render()` / `render(when:)`) and an event wait on the model, so that each chunk has exactly one render, in a fixed order; or fix the product if paragraph 0 really evaluates again (that is a real reuse defect). No time bound. Write all text in STE. #mail-step-7