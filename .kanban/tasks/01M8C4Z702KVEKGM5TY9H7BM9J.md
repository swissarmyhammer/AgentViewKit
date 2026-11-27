---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8ca6p22ty6fjp3rqgewyr4e
  text: |-
    ### review — findings
    - evidence: review sha 70c4b045..5bb17441; 29 findings (31 confirmed, 6 refuted, 14 files). Files: TerminalView.swift:63 (2), InterimTranscriptTextMeasure.swift:24, TranscriptRowChrome.swift:85,156,188,195,219,259,272,273,320,337, TranscriptRowContent.swift:173,274, TranscriptRowChromeTests.swift:16, TranscriptRowHeightBed.swift:29,68,97, TranscriptRowHeightsTests.swift:126,136,161,181,199,244,253,264,270, TranscriptRowMeasureTests.swift:14.
    - next: correct each finding in the "Review Findings (2026-11-26 10:02)" section, then review again. The card stays in review. The checklist items and the "waits for EK ^ep9f55d" note are not written, because the review is not clean.
  timestamp: 2026-11-26T16:14:47.874995+00:00
- actor: claude-code
  id: 01m8cd02aa0v08af41b5ndy2rp
  text: |-
    ### review — clean
    - evidence: review sha 14047377..70c6ba4a (the merge of 5d0809f5) — 0 findings (0 confirmed, 1 refuted, 7 attempted, 0 failed); 13 files reviewed, 4 .kanban files not reviewed (.reviewignore). Five Swift code-hygiene rules found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift and Tests/AgentViewKitTests/Thread/TranscriptRowMeasureTests.swift and did not read them. Evidence of the checked items: the chrome rules equal the mounted row with 0.0 pt for 12 row kinds (compaction and session message included) at 320/480/720; the cache copies no unchanged row; the root swift test: 1897 + 59 passed, 0 skipped. The EK measure item is open: EK EditorLayoutMeasure (^ep9f55d) is not on EK main; the measure tests come back with it (section on the card).
    - next: review clean; waits for EK ^ep9f55d
  timestamp: 2026-11-26T17:03:36.778634+00:00
- actor: claude-code
  id: 01m8d5f1kf3mmgrn41v4e5kakk
  text: |-
    ### review — clean
    - evidence: review sha e2449cee^1..e2449cee (the merge of 293cc9dd) — 0 findings (0 confirmed, 0 refuted, 7 attempted, 0 failed); 10 files reviewed; ARCHITECTURE.md not reviewed (no validator matches it). Five Swift code-hygiene rules found no file at the deleted InterimTranscriptTextMeasure.swift and InterimTranscriptTextMeasureTests.swift. Evidence of the EK measure item: EK 6295826b has EditorLayoutMeasure; EditorLayoutTranscriptTextMeasure is the default measure; the parity suite TranscriptRowMeasureTests is back, 36 cases at 0.0 pt; 9 of 12 row kinds are exact; code fences, command output and diff wait for the EK gutter measure ^v8t0pka. All items are checked.
    - next: the card moves to done.
  timestamp: 2026-11-27T00:11:13.391081+00:00
position_column: done
position_ordinal: ffffffffb680
title: 'Scroll 1: a row height cache from data, off the main thread'
---
From spike ^fa3j934 (2026-11-26). The virtual transcript needs the exact height of each row with no view, off the main thread. Measuring the views costs 1.7 s on main for 200 rows, and Core Text is too inexact (mean error 246 pt). EK makes an exact measure: `EditorLayoutMeasure.height(of:width:style:)` (EK ^ep9f55d, 0 pt error for text; images from their natural size, ^chy02jm; code with a gutter, ^v8t0pka).

## What
- [x] A new type `TranscriptRowHeights` (Sources/AgentViewKit/Thread/): a cache of the height of each entry by entry id, entry version (row key and content digest) and width. It computes on a background task, and it publishes the heights to the main actor.
- [x] A chrome rule for each row kind (user message, agent message, collapsed thought, tool call card, diff, command output, plan, notice): the row padding, the header heights and the block frames that AVK adds around the EK text. Each rule is a pure function of the entry and the theme metrics.
- [x] The EK measure for the text parts, when EK ^ep9f55d is on EK main. Until then, the type takes an injected measure, so the next cards can start.
  - Note: EK EditorLayoutMeasure (^ep9f55d) is not on EK main; the measure tests come back with it (section on the card).
  - Evidence (2026-11-26): commit 293cc9dd (merge e2449cee). EK 6295826b has `EditorLayoutMeasure`. `EditorLayoutTranscriptTextMeasure` is the default measure. The parity suite `TranscriptRowMeasureTests` is back: 36 cases at 0.0 pt. 9 of 12 row kinds are exact with the EK measure. Code fences, command output and diff wait for the EK gutter measure ^v8t0pka.
- [x] Only the last row, while it streams, gets a new height per update. A width change computes again in the background, and the rows in view first.

## Acceptance Criteria
- [x] For each row kind, the cached height equals the height of the mounted row within 0.5 pt at 320, 480 and 720 pt widths.
- [x] The cache does no work on the main thread for a row that does not change.

## Tests
- [x] Unit tests in Tests/AgentViewKitTests/Thread/ that mount each row kind in a window that is never ordered in, and compare its height with the cache. No sleep, poll, retry or clock; wait on the observable publish.
- [x] `swift test` passes with 0 failures and 0 warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf

## Review Findings (2026-11-26 10:02)

> Scope: `review sha 70c4b045..5bb17441` — reviewed the diffs only — lines this change added or modified. 14 file(s) reviewed, 1 not reviewed.

> 1 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file

- [x] `Sources/AgentViewKit/Terminal/TerminalView.swift:63` `duplication/duplication` — The new untitledCommand copies the localized string "Terminal" that accessibilityLabel already uses for its no-command branch. If the wording or its localization key changes in one place only, the command label and the accessibility label diverge. Have accessibilityLabel return untitledCommand in its else branch, so the localized literal exists once. Keep the change in the else branch only; the "Terminal, \(command)" branch is a different string.
- [x] `Sources/AgentViewKit/Terminal/TerminalView.swift:63` `reuse/reuse` — The new `untitledCommand` builds the localized string "Terminal" by itself. The same call with the same key already exists in `accessibilityLabel` (line 216). Two copies of one localized literal can drift apart when the text changes. The new helper should be the single source, and the existing `else` branch should call it. Make `accessibilityLabel` return `Self.untitledCommand` in its `else` branch, so the string exists once.
- [x] `Sources/AgentViewKit/Thread/InterimTranscriptTextMeasure.swift:24` `code-hygiene/missing-docs-swift` — AllPublicDeclarationsHaveDocumentation: add a documentation comment for 'height(of:width:)'.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:85` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:156` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:188` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:195` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:219` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:259` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:272` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:273` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:320` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowChrome.swift:337` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowContent.swift:173` `swift/immutability` — The function textBlocks builds its result with a var accumulator. A for loop with a where filter appends the text of each visible block. A reader must read the whole loop to learn the final value. The loop returns nil on a non-text block, so the result can be built in one expression. Use a check followed by a map, so the result is a let. Use `let visible = EntryContentView.joiningAdjacentText(in: content).filter(\.isVisibleToUser)`, then `guard visible.allSatisfy(\.isText) else { return nil }`, then `return visible.compactMap { block in if case .text(let text) = block { return text.text } else { return nil } }`. If `isText` is not defined, write the check as a `case .text` closure, or keep the loop and state why it stays.
- [x] `Sources/AgentViewKit/Thread/TranscriptRowContent.swift:274` `duplication/duplication` — The terminal shaping copies the output-cap logic of commandOutput. Both build a TerminalOutput with EnvironmentValues().editorTheme.terminalPalette, then return nil when shown.rows.isCapped. The only differences are the row limit value and the output text. If the cap rule changes in one copy, the other copy drifts. The two row limits are also equal (TerminalView.defaultRowLimit = CommandOutputView.defaultRowLimit). Extract one helper, for example static func cappedRows(_ output: String, limit: Int) -> TerminalOutput.Rows?, that builds the TerminalOutput with the theme palette and returns nil when the rows are capped. Call it from commandOutput with CommandOutputView.defaultRowLimit and from terminal with TerminalView.defaultRowLimit, then delete the second copy of the block.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowChromeTests.swift:16` `completeness/invariant-propagation` — The parity test that compares each chrome rule with the mounted row height does not cover the compaction row kind or the session message row kind. Both kinds have chrome rules in TranscriptRowChrome.swift (`compaction` and `sessionMessage`), and TranscriptRowContent.swift builds both. Their rules can drift from the mounted views with no test failure. The file header says the tests mount each row kind and compare its height with the rule, and that is not true for these two kinds. Add a `compaction` case and a `sessionMessage` case to TranscriptRowFixtures.Row, with a PreviewTranscriptItem fixture for each, and map them in `item`. The existing `theChromeRuleGivesTheMountedHeight` test then checks both kinds at every test width. If a fixture cannot be built for one of them, say why in the test file.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightBed.swift:29` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightBed.swift:68` `duplication/duplication` — The new `mount` helper repeats the pattern of the test-only mount helpers already in the codebase. Each one builds an NSHostingView, puts it in a window that is never shown, and lays it out. Copies of this code must be kept in step. Make one shared, off-screen mount helper in the test support target, or in this bed, that takes a root view and returns the hosting view and window. Have the new `mount` call it. Report the counterpart files as a separate task.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightBed.swift:97` `reuse/reuse` — The new private static func textViewFrames walks the view tree the same way as the existing private textViews(in:) helpers. Those are in StaticRowHost and LiveRowModelsTests. This adds a third copy of the same recursive subview walk instead of extending one shared helper. The new walk differs in its contract: it matches EditorKit class-name suffixes, not NSTextView, returns outermost matches only, and converts frames to the root view. That is why this is a near-match, not an exact duplicate. Move one generic walk into AgentViewKitTestSupport, parameterized by a predicate that picks the matched views (NSTextView, or class-name suffix). Have the bed, StaticRowHost and LiveRowModelsTests call it. If the frame conversion and outermost-only rule must stay in the bed, keep only the generic walk shared and convert the result in the bed.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightsTests.swift:126` `duplication/duplication` — The setup block repeats in this test, in the test at line 161, the test at line 181, and the test at line 199. It opens a session, makes the metrics, a RecordingTextMeasure, and a TranscriptRowHeights, calls update with rowsInView 0..<2, and waits for each height. Copies of this setup can drift apart. The provider helper at line 222 repeats the same first five steps. Extract one helper, for example `settledHeights(of session:, width:, measure:) async -> (TranscriptRowHeights, TranscriptRowMetrics)`, that does the open, make, update, and wait steps. Call it from each test and from `provider`. Keep `measure.reset()` in the tests that need it.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightsTests.swift:136` `duplication/duplication` — The pair of calls that sends a streamed chunk and then waits for the heights repeats in four tests. A change to how a streamed chunk is awaited must be made in each copy. Extract a helper, for example `streamAndSettle(_ text:, in session:, heights:, model:, width:, metrics:)`, that calls `stream` and then `waitForEachHeight`. Call it from each test.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightsTests.swift:161` `duplication/duplication` — The setup of the DEBUG-only test repeats the setup of the other streaming tests: open session, metrics, RecordingTextMeasure, TranscriptRowHeights, update, and wait. A fix to the setup in one test may miss this copy. Use the shared setup helper proposed for line 126, and pass the user key lookup and the counter key lookup after it returns.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightsTests.swift:181` `duplication/duplication` — The setup of the no-change test repeats the setup of the streaming and width-change tests. Each copy must be kept in step by hand. Use the shared setup helper proposed for line 126.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightsTests.swift:199` `duplication/duplication` — The setup of the width-change test repeats the setup of the other cache tests. The copies can drift apart. Use the shared setup helper proposed for line 126.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightsTests.swift:244` `duplication/duplication` — The prelude of this test repeats the prelude of the test at line 232 and the test at line 253. Each copy opens a session, sets up a deferred close, builds the provider, and reads the last or first entry. Extract a helper that returns the session and the provider for one scripted session, or fold the entry lookup into the `provider(of:)` helper so that each test reads only the entry it needs.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightsTests.swift:253` `duplication/duplication` — The prelude of this test repeats the prelude of the tests at lines 232 and 244. The copies can drift apart. Use the same shared helper proposed for line 244.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightsTests.swift:264` `reuse/reuse` — The new test theProviderKnowsNoHeightOfARowThatNoRuleCovers builds its entry by calling SessionModel.preview(transcript:) and taking the first entry. This is the same work as TranscriptRowHeightBed.entry(_:), which this change adds in the same test target for this purpose. The test re-implements the helper instead of calling it. Replace the inline preview call with `let unknown = try TranscriptRowHeightBed.entry([.update(.agentMessageChunk(ContentChunk(content: .unknown("x", .null), messageId: MessageId(rawValue: "x"))))])`.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowHeightsTests.swift:270` `duplication/duplication` — The setup of this test repeats the cache setup of the other cache tests. It makes the metrics, a RecordingTextMeasure, and a TranscriptRowHeights, calls update, and waits for each height. This is one more copy of the setup that the shared helper for line 126 would replace. Use the shared setup helper proposed for line 126. Pass the combined `entries` array to it, so that this test does not repeat the setup.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptRowMeasureTests.swift:14` `test-integrity/no-test-cheating` — The new suite `TranscriptRowMeasureTests` is disabled with `.disabled(...)`, so its test `theDefaultMeasureGivesTheMountedHeight` never runs in any test pass or CI run. A test that never runs cannot fail, so it gives no coverage of the default measure. The reason given is a card reference in another project (EditorKit ^ep9f55d), not a link to an issue in this repository, so it is not clearly an accepted skip. Keep the suite enabled and make it pass with the current measure, or move it into a separate, explicitly named pending target that CI does not run until the EditorKit measure lands. Also link the skip to an issue in this repository, and record in the code which CI task runs the suite once it is enabled. Do not leave a new test suite disabled inside the unit target.

## Measure tests that come back with EK ^ep9f55d

The review (2026-11-26) did not permit a disabled suite in the unit target, and the user rule permits no new target. So `TranscriptRowMeasureTests` is deleted (commit 5d0809f5). When EK `EditorLayoutMeasure` lands, make it the default measure of `TranscriptRowHeights`, add the `measure:` parameter to `TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow` again (`measure: (any TranscriptTextMeasure)? = nil`, used as `measure ?? mountedMeasure`), and add this suite, enabled:

```swift
@MainActor @Suite
struct TranscriptRowMeasureTests {
  @Test(arguments: TranscriptRowFixtures.Row.allCases, TranscriptRowHeightBed.widths)
  func theDefaultMeasureGivesTheMountedHeight(row: TranscriptRowFixtures.Row, width: CGFloat) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    try await TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow(
      entry, width: width, expanded: row.isExpanded, measure: <the EK measure>)
  }
}
```