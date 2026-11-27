---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8c9kmpwt8zrv4wzf82w6b92
  text: |-
    ### review — findings
    - evidence: review sha ac33f639..70c4b045 — 6 findings (9 confirmed, 2 refuted, 14 attempted, 0 failed): Sources/AgentViewKit/Content/CommandOutputView.swift:200, Sources/AgentViewKit/Content/StaticMarkdownText.swift:58, Sources/AgentViewKit/Terminal/TerminalView.swift:186, Tests/AgentViewKitTests/Thread/StaticRowHost.swift:144, Tests/AgentViewKitTests/Thread/StaticRowHost.swift:195, Tests/AgentViewKitTests/Thread/TranscriptStaticRowTests.swift:45. ARCHITECTURE.md is not reviewed (no validator matches it).
    - next: Correct the 6 findings in "Review Findings (2026-11-26 09:55)". Then do the review again. The review is not clean, so the evidence items (unit tests, root swift test, IntegrationTests, gallery) are not checked yet. The flick target of 2000 ms or less waits for ^9h7bm9j.
  timestamp: 2026-11-26T16:04:23.900979+00:00
- actor: claude-code
  id: 01m8ccnvqw62t0wxm5hvstzxyz
  text: |-
    ### review — findings
    - evidence: review sha 14047377^1..14047377 (the merge of bf47d40b and 25df5567) — 7 findings (11 confirmed, 5 refuted, 14 attempted, 0 failed): Sources/AgentViewKit/Content/StaticMarkdownText.swift:76, Sources/AgentViewKit/Thread/InterimTranscriptTextMeasure.swift:55, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:82, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:166, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:169, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:172, Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:175. The range b229006c~1..14047377 that the request gave is empty (b229006c~1 is 14047377), so the review used the first parent of the merge. Five Swift code-hygiene rules found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift and did not read it.
    - next: Correct the 7 findings in "Review Findings (2026-11-26 10:47)". Then do the review again. The review is not clean, so the evidence items (unit tests, frame check, pixel check, root swift test, IntegrationTests, gallery) are not checked yet. The flick target waits for the trace with the cache heights.
  timestamp: 2026-11-26T16:58:02.364763+00:00
- actor: claude-code
  id: 01m8dv6pfmyacm8k82xmbesvxv
  text: |-
    Probe result (2026-11-27): SwiftUI hit-tests hover responders for synthetic mouse moves in a window that is never ordered in, but only after the hosting view gets mouseEntered(with:). window.sendEvent(.mouseMoved) and hosting.mouseMoved(with:) alone gave 0 hit tests. With mouseEntered then 5 moves at rest: 10 path(in:) calls of the contentShape, 10 NSView hitTest calls, 5 active onContinuousHover callbacks. In a live motion: 0 of each. A draw of the row does not call path(in:), so the path count is the hit-test count.

    Also: after the full disk, .build/out/ModuleCache.noindex had a cut-short SwiftShims .pcm ("file too small to contain precompiled file magic"). Delete that cache to build again.

    ### implement — changed
    - evidence: 8c7940af. Files: Tests/AgentViewKitTests/Thread/HoverResponderProbe.swift (new), Tests/AgentViewKitTests/Thread/StaticRowHost.swift (messageFooter slot, moveMouse(over:moves:)), Tests/AgentViewKitTests/Thread/TranscriptRowHitTestTests.swift (aLiveMotionHitTestsNoHoverResponderOfARow). RED: with .allowsHitTesting(!rowsMoveLive) taken out, the #expect of a zero count in the live motion failed, and the #require of a count above zero at rest passed. GREEN: 1 test passed. Root swift test, one run: 2001 tests in 242 suites and 59 tests in 12 suites passed, 0 issues. The only warnings come from the mlx-swift C++ headers (third-party).
    - next: /review of 8c7940af.
  timestamp: 2026-11-27T06:31:08.532688+00:00
- actor: claude-code
  id: 01m8emm8je9kx9snzh1ansxyfs
  text: |-
    Research (2026-11-27, flick hitch defect: EK mounts in TranscriptStaticRowFrame.sizeThatFits in the first pass of a flick). Read-only research while builds are held.
    - The cache does compute all rows, but in a bad order and with one late publish: `update(entries:width:rowsInView:)` sends ALL rows that are not in view as ONE worker batch, and publishes them only when the whole batch is done.
    - At the first feed, `TranscriptStaticRowHeights.rowsInView` is `0..<0` (`noteRowsInView` only records the span, it does not feed or reorder). So no row is "in view", and the batch is in transcript order: row 0 first. The list starts at the BOTTOM (`defaultScrollAnchor(.bottom)`), so the rows in view and the rows that a flick reaches first are the LAST to get a height.
    - A width change starts a second full batch at the new width. The old batch is not stopped: the serial worker finishes it first, and `publish` then drops its results (old generation). Each width wobble at launch adds a full pass of wasted work in front of the real one.
    - The worker keeps the prepared parts of the newest 256 rows (LRU by measure order). With a full pass in priority order, the far rows are measured last, so they push out the prepared parts of the rows near the view. A width change then prepares those near rows again.
    - Code rows (Markdown fences, code, output) are exact with EK ed5eaab6 (`unmeasuredElement` gives nil for a block widget), so the cause is the time of the heights, not exactness.
    - Plan: a priority drain on the main actor that sends the pending rows to the worker in small batches, the rows in view first and then outward in both directions (the bottom rows first when no row in view is known), that takes the new order at each batch when the rows in view change, that stops old-width work at the next batch, and that keeps prepared parts only for the rows nearest the view. Awaited seam for tests: `finishPendingHeights()` (awaits the drain task, no clock).
  timestamp: 2026-11-27T13:55:27.438614+00:00
- actor: claude-code
  id: 01m8en5egebdtb8acj6c2fz0hs
  text: 'RED (commit e0f89bec, old code + the awaited seam `finishPendingHeights()`): `swift test --skip-build --filter "TranscriptRowHeightOrderTests|aLiveJumpToRowsThatWereNeverShown"`, 7 tests, 4 issues. FAIL: near<far (row 248 after row 50), no row in view → last<first, static rows in view first, new width prepares no row in view again. PASS on old code: far row height after the transcript is set, rows in view before their neighbors, live far jump mounts no editor. The old cache computes every row in the end, so a test that waits for the end of the work does not fail; the defect is the order (row 0 first while the list starts at the bottom) and the one publish at the end of the full batch.'
  timestamp: 2026-11-27T14:04:50.574027+00:00
- actor: claude-code
  id: 01m8enxy4379vp5b21gt7fekht
  text: |-
    ### implement — changed
    - evidence: commits e0f89bec (RED tests + awaited seam) and ceb1b6b4 (fix). Files: Sources/AgentViewKit/Thread/TranscriptRowHeights.swift, Sources/AgentViewKit/Thread/TranscriptRowHeightQueue.swift (new), Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift, ARCHITECTURE.md, Tests/AgentViewKitTests/Thread/TranscriptRowHeightOrderTests.swift (new), Tests/AgentViewKitTests/Thread/TranscriptMotionMountTests.swift. RED: 7 new tests, 4 failed on the old code (order tests); the far-row test, the rows-in-view-first test and the live far jump test passed on the old code, because the old cache computes every row in the end. GREEN: 7/7. Thread suites: 379 tests in 49 suites passed. Root `swift test` one time: 2008 tests in 243 suites + 59 tests in 12 suites passed, exit 0. IntegrationTests `swift build --build-tests`: complete, not run.
    - fix: a priority drain (batches of 16) in the order of TranscriptRowHeightQueue — rows in view first, then outward in both directions, the last rows first when no row in view is known; the list gives the cache its rows in view at each report; each batch publishes before the next; an old-width batch is the last of its width; the worker keeps prepared parts only for the 256 rows nearest the view.
    - not changed: the copy of each new entry (TranscriptRowContent) still runs on the main actor in `register`, one time per new or changed entry, because it reads the main-actor models and sets the observation of the entry.
    - next: /review; then a flick trace to confirm the drop of the mounts in the first pass.
  timestamp: 2026-11-27T14:18:12.995447+00:00
- actor: claude-code
  id: 01m8er4c9nn5bn78440a21w11m
  text: |-
    ### implement — changed
    - Merge of main (57af2605) into the static picture branch, commit cf2cc58b.
    - TranscriptRowHeights.swift: main's queue and drain are kept. Each Batch now holds the jobs and a TranscriptRowHeightWorker.Pass (width, appearance and their generations). The drain calls worker.heights(of:width:appearance:) and publish(_:pass:), so the pictures are drawn in the same batches as the heights, rows in view first. noteAppearance(_:) adds each known row to the queue. computeHeights(of:) uses the pass. In the worker, kept(_:width:keepsPrepared:) keeps the measured parts and the prepared-parts limit of main.
    - TranscriptStaticRowHeights.swift: the appearance property, noteAppearance and picture(of:inRow:appearance:) stay; main's rowsInView doc and noteRowsInView to the cache stay.
    - ARCHITECTURE.md: main's worker bullet, then the picture bullet, which now says that the pictures come in the same batches and order as the heights.
    - EditorKit: swift package update EditorKit in root, IntegrationTests, ScreenshotTests; pin stays ed5eaab6.
    - evidence: swift build --build-tests clean (no own warnings); thread suites 136 tests in 11 suites passed; root swift test 2023 tests in 244 suites + 59 tests in 12 suites passed, 0 skipped; IntegrationTests and ScreenshotTests build --build-tests complete (not run).
    - next: review.
  timestamp: 2026-11-27T14:56:41.269721+00:00
- actor: claude-code
  id: 01m8exzngkc1nm3spqrpbv8mt4
  text: |-
    Motion-end hitch work picked up (worktree agent-ab2b4bbc40f7c2b0f, main 078bc880 merged, EditorKit pin already ed5eaab6).
    Research:
    - TranscriptRowHolds.keepsRealRow counts isHovered also for a row whose mount waits at rest, so onHover(true) at the motion end makes every slot of that row real in one frame (no queue).
    - ConversationView sets isMoving and isLiveMoving in the same onScrollPhaseChange call, so the hit test, the hover and the form change of the rows land in one transaction.
    - ForEach passes entersWhileMoving: rowsMoveLive; in the motion-end transaction it is false, so a row made there does not wait.
    - No click path exists on a still view: before this change the hover always made the row real before a click. A click test is needed when the hover no longer does that.
    - The per-row .allowsHitTesting(!rowsMoveLive) is in TranscriptRowElement; the hover-count test hosts one row in StaticRowHost.
    Plan: gate the hover hold on !waitsToMount; a motion-state value type with a one-frame end (the queue runs the end action in its next frame); rows made in that frame wait; one hit-test modifier on the LazyVStack, shared with StaticRowHost.
  timestamp: 2026-11-27T16:38:58.323009+00:00
- actor: claude-code
  id: 01m8ez5hskqp5cq6qtzn8ykhps
  text: |-
    Research (2026-11-27, Text measure in placeSubviews of the static row frame). Headless count: a probe replaces -[NSTextLayoutManager ensureLayoutForRange:] and counts each main-thread layout of a layout manager with no text view (the SwiftUI Text path: ResolvedStyledText.TextLayoutManager.computeMetrics). Flick: ConversationView 900x1000, 50 synthetic turns of the trace harness (user, thought, answer with prose and a python fence), live scroll, 399 steps of 40 pt, after the cache computed each row.
    - The trace harness (spike-final ScrollProfileHarness, V0) mounts ConversationView with NO expandedBlocksStore. With no store, TranscriptStaticRowHeights.makeCache gives nil: no height cache and NO picture. AgentThreadView sets a store, so the product path has the cache.
    - Before, harness config (no store): 208 Text layouts, 96 layout managers. Markdown (answers + user messages) 112 = 54 % (cause b: no picture, because no cache), code 96 = 46 % (cause d: no picture path for code). Repeats 112 of 208 = 54 % (cause c), all in the SAME frame as the first layout.
    - Before, product config (store): 96 Text layouts, 32 managers, all code text and line numbers (d = 100 %). Markdown Text 0 (cause a = 0, cause b = 0 after the cache finished). Repeats 64 of 96 = 67 % (c).
    - Why the repeats: the container size of each layout. Code Text: inf x inf, inf x inf, 0 x inf. The HStack of StaticCodeText asks each Text for its ideal and its MINIMUM width (0 wide: the hyphenation frames of the trace), and the stacks around ask for the spacing of the Text (Text.spacing() -> computeMetrics at inf, from a call stack in the test). Markdown Text: inf x inf (spacing query of an outer HStack through the VStack of the pieces), then 892 x inf.
    - placeSubviews of TranscriptStaticRowFrame proposed (width, nil), not the cached size.
  timestamp: 2026-11-27T16:59:39.699833+00:00
- actor: claude-code
  id: 01m8ezh351v508d4q9cwxvd4rw
  text: |-
    ### implement — changed
    - evidence: commit 9e657292. Files: Sources/AgentViewKit/Content/StaticTextColumns.swift (new), Sources/AgentViewKit/Content/StaticCodeText.swift, Sources/AgentViewKit/Content/StaticMarkdownText.swift, Sources/AgentViewKit/Thread/TranscriptStaticRow.swift, ARCHITECTURE.md, Tests/AgentViewKitTests/Helpers/TextLayoutProbe.swift (new), Tests/AgentViewKitTests/Helpers/FlickTranscript.swift (new), Tests/AgentViewKitTests/Thread/StaticTextLayoutTests.swift (new), Tests/AgentViewKitTests/Thread/SizeQueryProbe.swift, Tests/AgentViewKitTests/Thread/TranscriptStaticRowFrameTests.swift.
    - RED: 5 new tests failed on the old code: the code Text, the line numbers, the flick of the harness turns, the flick of Markdown with no picture (each had repeated layouts), and the placement proposal ((320, nil) and not (320, 96)). A first Markdown test with a lone answer passed on the old code, so it was replaced by the flick with pieces. The first placement test recorded no placement, because a probe with no subview is not placed; the probe now holds Color.clear.
    - GREEN: 5/5. Thread suites: 399 tests in 51 suites passed (with the pixel and parity tests). Root swift test one time: 2028 tests in 245 suites + 59 tests in 12 suites passed, exit 0. IntegrationTests and ScreenshotTests swift build --build-tests: complete, not run.
    - Counts after the fix (same flick): with the cache 96 -> 32 layouts, 0 repeated; no cache (harness config) 208 -> 96, 0 repeated. The remaining layouts are one first layout for each code Text and line-number column of a row that comes in (no picture path for code), plus the Markdown of the harness config, which has no cache.
    - Not changed: the trace harness has no expandedBlocksStore, so it has no height cache and no pictures. Giving ConversationView its own store would change the open state of the thoughts (the store default collapses each block), and ConversationView belongs to another agent. A person must decide: give the harness a store (as AgentThreadView does), or give ConversationView a default store.
    - next: /review of 9e657292; a flick trace with a store in the harness.
  timestamp: 2026-11-27T17:05:57.921637+00:00
- actor: claude-code
  id: 01m8f0n7ncce39gw5b9de8z9kd
  text: |-
    Motion-end hitch work landed in de7bcece (worktree agent-ab2b4bbc40f7c2b0f). No push.
    1. Hover: the mouse does not hold a waiting row (keepsRealRow(waitsToMount:)). RED: aMouseThatComesOnAWaitingRowAtRestMountsNoEditor, theRowUnderTheMouseMountsOneEditorSlotInTheFirstMountOfTheQueue, theHoverDoesNotMakeAWaitingRowRealAtOnce; GREEN after. Click: a press on the still view of a waiting slot releases the row (StaticEditorSlot). Synthetic clicks do not reach SwiftUI gestures in an unordered window (a probe showed 0 drags and 0 taps), so the click test is hosted: TranscriptWaitingRowClickPointerHostedTests, built, NOT run. A press gesture on the row VStack made aLiveMotionHitTestsNoHoverResponderOfARow fail (hit tests > 0), so the gesture is on the still view only.
    2. Rows made at the motion end: aRowThatTheListMakesInTheEndOfALiveMotionWaits passed before the change (this host makes the rows of the end move while the motion is live). With the split, rows made in the end frame did not wait (aRowThatTheListMakesBeforeTheRowsComeToRestWaits RED): rows whose State was made at rest appeared with rowsMoveLive false. Fix: \.transcriptRowsMoveLive stays true in the end frame (rowsEnterLive), so those rows enqueue, and rows evaluate nothing in that frame.
    3. Split: TranscriptMotionState + TranscriptRowMountQueue.afterNextFrame. RED: theRowsKeepTheirMotionFormInTheFirstLayoutAfterALiveMotion; guards: hit test in the end frame, rest one frame later, a new motion before that frame keeps the rows moving. One allowsHitTesting on the LazyVStack: the hover-count test passed, but TranscriptRowRedrawTests (error, moving) failed 2 of 2 runs (a layer drawn again at 5 of 30 steps). So the modifier is one per ForEach element, outside the row body (redraw test green).
    4. ID lookup: text ids on the ForEach (no .id()) removed the scan of rows 0-16 at the motion end (a RED/GREEN counter test showed 2 -> 0 makes of the first row), but ConversationFirstLayoutTests.theListShowsTheLastRowAfterTheFirstLayout failed (no row after the first layout, 30 s waits). Reverted; the lookup stays.
    ARCHITECTURE.md updated for the hover rule and the two-frame end.
  timestamp: 2026-11-27T17:25:42.188928+00:00
- actor: claude-code
  id: 01m8f0ncyw6p5kkeb1ta385kbq
  text: |-
    ### implement — changed
    - evidence: de7bcece; 16 files (Sources: StaticEditorSlot, ConversationView, TranscriptRowElement, TranscriptRowMotion, TranscriptRowMountQueue, TranscriptStaticRow; Tests: MovingThread, TextHitTest, RowMotionProbe, StaticRowHost, TranscriptMotionEndTests, TranscriptMotionMountTests, TranscriptRestMountTests, TranscriptRowMountQueueTests; IntegrationTests: TranscriptWaitingRowClickPointerHostedTests; ARCHITECTURE.md). Thread suites 403 tests / 52 suites green; root swift test 2032 tests / 246 suites + 59 / 12 green, 0 warnings in the package. IntegrationTests built, not run.
    - next: run TranscriptWaitingRowClickPointerHostedTests hosted; flick trace to measure the motion-end frame; review.
  timestamp: 2026-11-27T17:25:47.612259+00:00
position_column: doing
position_ordinal: '80'
title: 'Scroll 3: static rows while the transcript moves, real rows at rest'
---
From spike ^fa3j934 (2026-11-26). This card gives most of the gain: in the spike, static rows in motion (V2) used 1927 ms of main-thread time in a 15 s flick, against 6731 ms for the current list (-71 %), with 16 hitches against 63. The cost is the EK editor that mounts in each row while the list moves.

## What
- [x] While the transcript moves (the SwiftUI scroll phase is not idle), each row in the virtual layout (^kr7cx7b) shows a static form with its cached height (^9h7bm9j): the text as SwiftUI `Text` from the same attributed text, or the EK static rendering of a measured document (EK ^8zv7set) when it is on EK main.
- [x] At rest, the rows in view mount the real row. The row that has the keyboard focus, the mouse, a selection or a running stream stays real at all times.
- [x] The static form and the real row have the same height (the cache height), so no row jumps when it changes.
- [x] The static form looks the same as the real row: the same fonts, colors, padding and chrome. A look difference while the list moves is acceptable only for syntax colors of code, if EK ^8zv7set is not ready.

## Acceptance Criteria
- [ ] The flick trace of the spike harness on the real ConversationView shows main-thread time at or below 2000 ms for the 15 s flick (V2 of the spike: 1927 ms).
  - Not met (2026-11-26): main d57ae798 with EK c3c46d6a measured 4218 ms (3 rounds: 4119, 4431, 4103); EK 034fbd4e measured 4178 ms. Old main 366d9120 measured 6653 ms. The check on this item was wrong, so it is removed.
- [x] No row changes its height when it changes from static to real.
- [x] VoiceOver, text selection, the search marks and the jump targets work on a list at rest as before.

## Tests
- [x] Unit tests: a row gets the static form while the phase is not idle, the real row at rest, and the real row while it has the focus; the two forms have the same height.
- [x] The full IntegrationTests run passes (hosted, with start and end lines). The gallery images (light and dark) of a thread at rest do not change.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf

## Review Findings (2026-11-26 09:55)

> Scope: `review sha ac33f639..70c4b045` — reviewed the diffs only — lines this change added or modified. 16 file(s) reviewed, 1 not reviewed.

> 1 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file

- [x] `Sources/AgentViewKit/Content/CommandOutputView.swift:200` `duplication/duplication` — The static-form block of the output text area (a StaticEditorSlot with an EditorView that has editorTextMenu(.ancestor), sizedToContent(), and transcriptSearchMarks(searchMark), and a StaticCodeText.colored still view) is copied almost word for word into TerminalView. Both copies must change together, so a fix to one can drift from the other. Extract one shared view, for example OutputTextArea(model:, text:, runs:, searchMark:), that holds the StaticEditorSlot, the EditorView modifiers, and the StaticCodeText.colored fallback. Call it from both CommandOutputView and TerminalView, and delete the copy in each file.
- [x] `Sources/AgentViewKit/Content/StaticMarkdownText.swift:58` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Terminal/TerminalView.swift:186` `duplication/duplication` — The static-form block of the terminal output text area repeats the block in CommandOutputView. The two copies hold the same editor modifiers and the same colored static fallback, so they will drift apart as the output views change. Move the shared block into one view that both output views use, as described for CommandOutputView.swift:200. Keep the call sites small so each file passes only its text and its color runs.
- [x] `Tests/AgentViewKitTests/Thread/StaticRowHost.swift:144` `reuse/reuse` — The new `StaticRowHost.textViews(in:)` reimplements a helper that already exists in the test suite. Its body is identical to the private `textViews(in:)` in `LiveRowModelsTests`. Two copies of the same view-tree walk will drift apart, and a fix to one will not reach the other. Move the walk to one shared test-support helper, for example an extension on `NSView` in `Sources/AgentViewKitTestSupport/`, and call it from both `StaticRowHost` and `LiveRowModelsTests`. Do this in an existing target, since the rules forbid a new SwiftPM target unless the user asks. Delete both private copies.
- [x] `Tests/AgentViewKitTests/Thread/StaticRowHost.swift:195` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Thread/TranscriptStaticRowTests.swift:45` `reuse/reuse` — The new static helper `update(_:)` repeats the body of a private helper that already exists. `InspectionNameTests` has `private func update(_ json: String)` with the same one-line body: decode `SessionUpdate` from `json`, then wrap it with `.update(...)`. Two copies of one test helper must be kept in step. Shared test code belongs in one place. Move the helper to a shared test support file under Tests/AgentViewKitTests/Helpers/ (for example, as an internal static func on a test support type). Have TranscriptStaticRowTests and InspectionNameTests call it. Do not add a new SwiftPM target to hold it.

## Review Findings (2026-11-26 10:47)

> Scope: `review sha 14047377^1..14047377` — reviewed the diffs only — lines this change added or modified. 23 file(s) reviewed, 0 not reviewed.

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at Tests/AgentViewKitTests/Helpers/TextViewTree.swift, so its declarations are unread

- [x] `Sources/AgentViewKit/Content/StaticMarkdownText.swift:76` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Sources/AgentViewKit/Thread/InterimTranscriptTextMeasure.swift:55` `code-hygiene/missing-docs-swift` — AllPublicDeclarationsHaveDocumentation: add a documentation comment for 'isExact(_:)'.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:82` `reuse/reuse` — `noteRowsInView(positions:)` rebuilds the first-to-last span of the visible row positions. `LiveRowRange.noteVisible(positions:)` already does the same min and max over the same kind of positions, and then builds its own range. Two copies of the rule exist, so a change to how the visible span is taken would have to be made twice. Add one small helper that returns the first and last position of a collection, or the visible span as a range, and call it from both `noteRowsInView` and `LiveRowRange.noteVisible`. If the two must differ in how they treat an empty set, keep that choice at the call site.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:166` `code-hygiene/dead-code-swift` — var.instance `faces` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:169` `code-hygiene/dead-code-swift` — var.instance `expandedBlocks` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:172` `code-hygiene/dead-code-swift` — var.instance `session` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Thread/TranscriptStaticRowHeights.swift:175` `code-hygiene/dead-code-swift` — var.instance `hasDefaultLook` is assignOnlyProperty.
