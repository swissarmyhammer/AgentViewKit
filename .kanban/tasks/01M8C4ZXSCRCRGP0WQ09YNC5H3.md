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
- actor: claude-code
  id: 01m8f4h012qcev5fz9dd2v70qc
  text: |-
    EK 21a8a01d adoption (worktree agent-a12e72cd67814a792, main a1e31614 merged). Pins: root, IntegrationTests and ScreenshotTests Package.resolved all at 21a8a01dca258e95457609ce2e34748b363352c4.
    RED (one run, 22 tests, 27 issues):
    - Item 1: RowPixels compare now has no row shift. The Markdown pixel check passed (8 cases, light and dark) with no shift on EK 21a8a01d.
    - Item 3: new fixture diffFolded (a long context run between two changes). Parity failed at each width, the cache did not take it for exact, aDiffWithContextToFoldIsExact failed (old AVK TranscriptDiffLayout gives nil for foldable context).
    - Item 2: theMeasureDrawsAPictureOfCode / thePictureOfCodeHasTheMeasuredHeight (3 parts each) failed; the code and output slot picture counters were 0; the pixel check of the fence rows failed (mean 0.80 to 4.45, large part 0.0070 to 0.051 against limits 0.75 / 0.0075). The output and terminal rows passed with the old Text form (plain text, no colors).
    - Item 4: EK picture draws no citation chip (RenderedRowText: an inline widget shows one character as wide as its view, with no glyph), and no thread row gives citations (TextBlockView makes ResponseView with no citations). The Markdown with chips keeps the Text form.
  timestamp: 2026-11-27T18:33:17.602554+00:00
- actor: claude-code
  id: 01m8f5dqpzdpjyxrrkaqfh4w0w
  text: |-
    ### implement — changed
    - evidence: c4bd3a91 (on the merge of main a1e31614). 19 files: Sources (EditorLayoutTranscriptTextMeasure, TranscriptRowHeights, TranscriptStaticRowHeights, TranscriptStaticRow, TranscriptRowChrome, StaticEditorSlot, StaticMarkdownPicture, RenderedMarkdownView, CodeBlockView, OutputChrome; TranscriptDiffLayout removed), ARCHITECTURE.md, Tests (TranscriptStaticCodePictureTests new, TranscriptStaticPictureTests, RowPixels, StaticRowHost, StaticTextLayoutTests, TranscriptRowFixtures, EditorLayoutTranscriptTextMeasureTests).
    - Pins: root, IntegrationTests, ScreenshotTests Package.resolved at EditorKit 21a8a01d.
    - Picture now: Markdown (as before), code blocks (syntax colors, line numbers), command output and terminal in the plain text color. Text form stays: output with ANSI color runs (the code picture draws no color run), the diff slot (it shows the patch text), Markdown with citation chips (the EK picture draws a chip as a gap with no glyph; no thread row gives citations).
    - Diff: EK prepare(diff:style:gutterGap:) replaces TranscriptDiffLayout and the 12 pt strip constant. Folded context is exact now (new fixture diffFolded, parity 0.0 pt at each width and after each resize).
    - Discovery: each run of an output has a foreground (the palette default from ANSIText), so the output picture rule checks that each run has the palette foreground, no background, and that this foreground is the editor foreground.
    - Tests changed: StaticTextLayoutTests flick test now expects no Text layout (all pictured); the code block layout tests use a cache with no pictures (makeCached drawsPictures: false).
    - Item 5: no AVK test or committed fixture pins the band outline color or the image chip symbol; the root suite passed. The gallery images of code bands and image-loading rows will look different on the next gallery run (not run).
    - Counts: thread suites 414 tests in 54 suites passed; root swift test one run 2043 tests in 248 suites + 59 tests in 12 suites passed, 0 issues, no own warnings. IntegrationTests and ScreenshotTests swift build --build-tests complete, not run.
    - next: /review of c4bd3a91.
  timestamp: 2026-11-27T18:48:59.359638+00:00
- actor: claude-code
  id: 01m8ffdqsf0hahc3nr3wetzva3
  text: |-
    Flick work counts (2026-11-27, worktree agent-a1bfece229f6470fe, on b4facea2). Headless probe: MovingThread, 50 turns of FlickTranscript, 150 live steps of 40 pt, after the start of the live scroll.
    - With the height cache (AgentThreadView config): 12 new rows; 23 element bodies, 42 ForEach content calls, 1 content measure of a real row (a row real from rest), 0 content measures of a static row, 0 StaticTextColumns layouts, 16 picture bodies, 0 StaticMarkdownText bodies, 11 list bodies.
    - With no store (trace harness config, no cache, no pictures): 10 content measures of real rows (rows with no known height mount their editors), 29 StaticTextColumns layouts, 12 StaticMarkdownText bodies. If the trace shows StaticTextColumns and StaticMarkdownText.body, the harness probably has no expandedBlocksStore, or the rows hold text that the picture does not draw.
    - Cause of the 11 list bodies: SwiftUI writes the scroll position when a new row comes to the top edge, and the list made `$position` in its body (a Binding holds its value).
    Fix done: the position is in ConversationScrollPosition, bound by ConversationScrollPositionBinding. List bodies 11 -> 0.
    Not done, and why:
    (a) ForEach(slots, id: \.entry.rowKey) without .id(): no count change in the probe (content calls 42 -> 44, element bodies 23 -> 23), and ConversationFirstLayoutTests.theListShowsTheLastRowAfterTheFirstLayout fails again (shape 1, no row after the first layout), as in the earlier attempt.
    (b) The motion values change only at the start and the end of a motion, not in each frame, so init values in place of environment reads give no count change in the flick. A write of the same wait (TranscriptRowMount.waits) was guarded as a test: element bodies 23 -> 23, so it was reverted. One hit-test modifier on the stack failed TranscriptRowRedrawTests in the earlier attempt (de7bcece), so it was not tried again.
    (c) A static row never measured its content in the flick (0). The content measures are of real rows with no known height. To give them the estimate, they must show the static form at a height that is not exact, and the row then changes its height when it becomes real, against the card.
    (d) With a picture, StaticSlotStill already shows one Image (StaticPictureView) for each text slot, and builds no StaticTextColumns (0 with the cache). The cache has no picture of the row chrome, so one Image for a whole row is not possible.
    Discovery: SwiftUI makes rows ahead of the view in groups of 3, and drops and makes again some of them before they come into view (rows 135-140 made two times each, with a new identity; 6 of 23 element bodies). The cause is in the lazy stack of SwiftUI, not in a row.

    ### implement — changed
    - evidence: 290de3dd. Files: Sources/AgentViewKit/Thread/ConversationView.swift, Tests/AgentViewKitTests/Thread/TranscriptFlickWorkTests.swift (new), ARCHITECTURE.md. RED: aFlickEvaluatesNoListOfTheRows failed (11 list bodies). GREEN: 1/1. Thread suites: 479 tests in 60 suites passed. Root swift test one run: 2030 tests in 249 suites + 59 tests in 12 suites passed. IntegrationTests and ScreenshotTests swift build --build-tests complete, not run.
    - next: flick trace (parent); /review of 290de3dd.
  timestamp: 2026-11-27T21:43:45.199975+00:00
- actor: claude-code
  id: 01m8fjnbshyhv6ejwkafgvyvs8
  text: |-
    Livelock of 290de3dd (worktree agent-a1bfece229f6470fe).
    - Hung tests (on 290de3dd, each alone, killed by the guard): TranscriptSearchStepHostedTests.findNextHitRunsInAMountedThreadWithHits and SessionTranscriptViewHostedTests.aUserMessageAThoughtAndAnAgentMessageShowThreeRowsInOrder. These suites passed on 290de3dd: ConversationViewHostedTests, ThreadModelCacheHostedTests, ThreadBarBannerOverlapHostedTests, ThreadFloatingControlsHostedTests, ThreadBarControlJumpHostedTests, ThreadMinimapViewHostedTests, ConversationPillMountHostedTests, JumpLabelOverlapHostedTests.
    - Cause: the scroll view writes the position back through the @Bindable binding while it applies a request, inside the SwiftUI update. The write told an observation change, which evaluated ConversationScrollPositionBinding again in the same update, and that gave a new request. A @State (before 290de3dd) does not evaluate its readers in the update that writes it.
    - What did not work: an equal-value guard alone. Swift 6.4 @Observable already skips a write of an equal Equatable value (a test of that passed on 290de3dd). Each request of ScrollPosition has a new `seed`, so the values are not equal.
    - Headless probes (borderless window that is never ordered in, ConversationView and AgentThreadView, scrolls to items and to the bottom) showed no loop: SwiftUI does not run its scroll requests there. So the RED test is at the model level.
    - Fix: manual storage in ConversationScrollPosition. A write of the list to `value` tells a change only for a different position. `binding` (the binding of the scroll view) reads `value` for the observation, and its setter keeps the position with no change.

    ### implement — changed
    - evidence: b93507db. Files: Sources/AgentViewKit/Thread/ConversationView.swift, Tests/AgentViewKitTests/Thread/ConversationScrollPositionModelTests.swift (new), ARCHITECTURE.md. RED: aWriteOfTheScrollViewTellsNoChange failed on the seam (`binding` = Bindable(self).value, the 290de3dd behavior). GREEN: 4/4. The two hung tests pass on the fix (their suites: 2/2 and 9/9). Root swift test one run: 2034 tests in 250 suites + 59 tests in 12 suites passed, no own warnings. IntegrationTests full run one time: 1100 tests in 164 suites passed, exit 0 (5 known issues, all in FontRoleExpectationsTests, which checks on purpose that its checks fail).
    - next: /review of b93507db; merge by the parent.
  timestamp: 2026-11-27T22:40:20.785028+00:00
- actor: claude-code
  id: 01m8fnwn9x0pvebrkyszz1y0bs
  text: |-
    Defect TranscriptMotionEndTests.aRowThatTheListMakesBeforeTheRowsComeToRestWaits ("11 editors in view at rest"), research:
    - Bisect with the single test alone (filter on the test name): b4facea2 pass 4/4, 290de3dd pass 4/4, b93507db fail 3/3, main fail 6/6. With the whole suite filter the test passes on some runs (the other suite changes the order of work), so each agent saw a green suite by chance.
    - Cause (b93507db): the binding of ConversationScrollPosition is Binding(get:set:), and a Binding keeps the value that it had when the body made it. A write of the scroll view told no change, so no new binding was made. After a live scroll the binding still held the first scroll to the bottom (viewID of the last row, anchor bottom, seed 1). The list body evaluation at the end of the live motion (motion state change) updated the scroll modifier with that old value, and the scroll view went back to the bottom (y 1036 -> 2236). The rows in view at the end were then the real rows of rest at the bottom (39-49), not the waiting rows.
    - 290de3dd did not have it because the Observable write evaluated the modifier at once and made a new binding (but that gave the hosted loop that b93507db removed).
  timestamp: 2026-11-27T23:36:45.629126+00:00
- actor: claude-code
  id: 01m8fpkh5mnpcb39w80rjek3yp
  text: |-
    ### implement — changed
    - evidence: commit 6967642a on worktree-agent-a4d4f4bd2695361f5 (not pushed). 4 files: Sources/AgentViewKit/Thread/ConversationView.swift (ConversationScrollPosition.binding(noting:); ConversationScrollPositionBinding keeps each write of the scroll view in a @State, so the write evaluates only the modifier in a later update and the scroll view gets a new binding), Tests/AgentViewKitTests/Thread/TranscriptMotionEndTests.swift (new theEndOfALiveMotionKeepsTheOffsetOfTheList, RED before the fix), Tests/AgentViewKitTests/Thread/ConversationScrollPositionModelTests.swift (new theNoteGetsAWriteOfTheScrollView), ARCHITECTURE.md.
    - tests: root `swift test` 2036 tests / 250 suites + 59 / 12, 0 issues. Hosted, each under a 5 min guard: TranscriptSearchStepHostedTests 2 pass, SessionTranscriptViewHostedTests 9 pass, ThreadModelCacheHostedTests 2 pass. Full IntegrationTests (15 min guard): 1100 tests / 164 suites pass, 5 known issues (FontRoleExpectationsTests, by design). No guard kill.
    - next: /review.
  timestamp: 2026-11-27T23:49:15.060325+00:00
- actor: claude-code
  id: 01m8g28gcy75a0m2hk1hfedhqw
  text: |-
    Flick hitch work (worktree agent-a245360c9ed7cff2e, on main f0063a21). No push, no merge.
    1. Live Text in entering rows. Cause found: the published pictures had a byte bound (128 MiB) that dropped the OLDEST pictures first. The cache draws the rows in view first, so the bound dropped the pictures where a flick starts. At scale 2, one screen of pictures is about 7 MB, so the bound holds about 18 screens and a long thread has more. Fix: the bound drops the rows farthest from the rows in view; on each change of the rows in view the cache draws again the dropped pictures of the rows in view and 8 rows on each side (TranscriptRowHeights.pictureReach); the queue takes the row ahead of the last move first. A mounted slot now observes a per-row signal (TranscriptPictureSignal), so a row made before its picture (the lead row) shows the picture when it comes. Seam: pictureByteLimit on TranscriptStaticRowHeights / TranscriptRowHeights. Count: BoundedPictureFlickTests (50 turns, bound of 8 screens, worker awaited per step) Text layouts 12 -> 0; queue order test RED/GREEN; late-picture slot test 0 -> >0 picture bodies. Not checked: the trace harness config. If it still mounts ConversationView with no expandedBlocksStore, it has no cache and no pictures at all (see the comment of 2026-11-27 17:05).
    2. Lead row: TranscriptMountPlan mounts one row past the shown rows in the direction of the last move during a live motion. A new lead row mounts only in a pass with no other new row. Count: rows made in the step that first shows them (steady flick, after 10 warm-up steps) 10 -> 0.
    3. Idle steps: the offset record is written in the scroll-geometry transform (no action). The window geometry writes each report to a locked TranscriptViewportRecord and gives only the rows to mount as its value. The scroll position binding holds the SwiftUI writes in the model during a live motion and is evaluated again at the motion end. Count: actions and bodies of the list in steps that mount no row 156 -> 0. Hover: hit tests in live motion were already 0 (aLiveMotionHitTestsNoHoverResponderOfARow), and per-step hover bodies are 0. The SwiftUI-internal enqueueHoverUpdateIfNeeded cannot be counted in a unit test, so it is not verified.

    ### implement — changed
    - evidence: 788fc1f0, 879f069d, 524d5102, a2ff63d2. Root swift test one run: 2083 tests in 259 suites + 59 tests in 12 suites passed, 0 issues. Thread suites 453/65 passed before the last commit. IntegrationTests, ScreenshotTests, xctrace not run (parent).
    - next: flick trace by the parent; /review of 788fc1f0..a2ff63d2.
  timestamp: 2026-11-28T03:12:56.734763+00:00
- actor: claude-code
  id: 01m8g59kddd48g1xr149h3fke6
  text: |-
    EditorKit 0bc02f8c check of the row-entry fixes (worktree agent-a245360c9ed7cff2e, HEAD a2ff63d2). No push, no merge.
    - Pins: `swift package update EditorKit` in root, IntegrationTests and ScreenshotTests. Each Package.resolved shows 0bc02f8ce35e1f5f8b93412eb74be033d6f9f34b. The three Package.resolved files are in .gitignore, so the pin change gives no file to commit. The root tests, IntegrationTests and ScreenshotTests compiled with no change to the code (no API break).
    - Root swift test, one run: 2083 tests in 259 suites + 59 tests in 12 suites passed, 0 issues, exit 0.
    - IntegrationTests, one full run under a 15 min guard: 1100 tests in 164 suites passed, 5 known issues (FontRoleExpectationsTests, by design), exit 0, no guard kill.
    - ScreenshotTests gallery, one run: 47 tests in 4 suites passed. Copy: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/cb6ea94a-55e6-4196-a95c-8572bfe4fa85/scratchpad/gallery-rowentry/.
    - Pixel compare with gallery-6fax/run2 (same relative paths; run2 holds some images only in generated/, so its generated/ copy was used where snapshots/ had none): all 278 PNGs that index.html shows are the same to the pixel (mean 0, 0 pixels changed), with each thread and transcript image. One extra file that the page does not show differs: generated/GlassSnapshotTests/floating-notes-dark.png, mean 0.0023, large part 0.00002, 104 pixels in x 1502-1513, y 407-929 (the scroll bar strip at the right edge). It is in the RowPixels limits (0.75 / 0.0075) and it is not a thread image.
    - Tool friction: code_context `grep code` with `file_path` did not limit the search to the file; it searched the whole index (1.28 M characters).

    ### implement — no-change
    - evidence: no file changed (Package.resolved is gitignored in all three packages); root 2083/259 + 59/12 green; IntegrationTests 1100/164 green (5 known issues); gallery 278 shown PNGs same to the pixel as run2.
    - next: parent: merge decision for 788fc1f0..a2ff63d2; /review.
  timestamp: 2026-11-28T04:05:58.317545+00:00
- actor: claude-code
  id: 01m8gbn8bmmwhxmrk00fnrq705
  text: |-
    Idle-frame work of a flick: hover update and scroll observers (worktree agent-abccc0067a726ce86, on main 204a33b8). No push, no merge.

    A. Hover (572f0fab): the per-row `.onHover` is gone. One `.onContinuousHover` on the stack (`TranscriptRowsHover`) finds the row under the mouse from `TranscriptRowGeometry.row(atY:)` and gives it to `TranscriptRowHoverTarget`; each row reads its hold from its own `TranscriptRowHoverSignal`. A hover responder takes the hover over its whole frame also where no child takes the hit test: on the stack with no hit-test change it got 80 callbacks in 20 live steps with mouse moves; with `.allowsHitTesting(!rowsMoveLive)` on the stack (the per-element `TranscriptRowsHitTest` stays) it gets 0. TranscriptRowRedrawTests stay green with that modifier. Did not work: a clear overlay with the hover (it took the hover from the controls of a row: probe callbacks 0 at rest); a clear background (it got no hover over a row). RED: theMouseOverARowAtRestIsTheHoverOfThatRow (no row under the mouse). Not done: the rows still hold EditorKit hover responders (`EditorToolbarButton.onHover`, `.help` of `EditorButtonParts`) and the press gesture of a static slot; no unit test can count the responders that SwiftUI walks. New card ^zqsemdq: measure first, then remove them in a live motion if the trace still shows the cost.

    B. Scroll observers (fcc9de30): one `ConversationScrollGeometryObserver` (insets, bottom state, offset): 180 -> 60 transforms in 60 steps. Rows in view from the window report (`TranscriptWindowChange.visibleRowKeys`), `onScrollTargetVisibilityChange` removed: 9 SwiftUI visibility actions -> 0; 9 reports for 9 changes. A static row and its element with the exact cache height (no status line) have no size observer (background, conditional): 6 -> 0 transforms for the rows made in the flick (RED with the observers always on).
    Discoveries: SwiftUI runs the first action of onGeometryChange/onScrollGeometryChange with old == new; the old bottom observer used that first call to set contentFitsInView, so the merged action gives both parts on it. A report before the list's onAppear set the manager's last item first, so the list made no first scroll to the bottom (it stayed at the top under load); such a report now waits for the appearance (`ConversationEarlyRowsInView`). The stack report comes in the layout pass of the scroll; on main, SwiftUI's report came later, so an at-rest clip move to the middle went back to the bottom before the report. TranscriptRowAnchorTests now measures the first row in view (a scroll up can take the partly shown last row out of the stack).
    Seen once and not again: TranscriptFlickWorkTests.aSteadyFlickMountsNoRowInTheStepThatShowsIt failed one time in a two-suite run during the work, and passed in each later run, also in the full root run.

    ### implement — changed
    - evidence: ccd96c1e (RED counters and tests), 572f0fab (A), fcc9de30 (B). Root `swift test` one run: 2091 tests in 261 suites + 59 tests in 12 suites passed, 0 issues, no own warnings. Thread suites 562/88 green. IntegrationTests, ScreenshotTests, xctrace not run (parent); IntegrationTests files changed only in doc comments.
    - next: parent: flick trace, hosted hover/menu/scroll suites; /review of ccd96c1e..fcc9de30.
  timestamp: 2026-11-28T05:57:11.668816+00:00
- actor: claude-code
  id: 01m8gd95t5b8mj8fdppvm5e7xf
  text: |-
    Follow-up on the release traces of fcc9de30 (worse than main: 2924 vs 2611 ms, editor mounts 50/48 in 2 of 4 runs, other scroll paths).
    - Cause found (certain unit test): in fcc9de30 the size observer of an element was in a `.background`. With it, the first layouts of a long thread (MovingThread, 120 answers, no store, as the trace harness) ended at rows 0-8: content grew, isNearBottom went false, the manager unpinned. RED: ConversationStartTests.aLongThreadShowsItsLastRowAfterItsFirstLayouts failed on fcc9de30, passed on main 204a33b8. Bisect: the TranscriptStaticRow background was not the cause; an unconditional background on the element failed; an overlay (conditional) passes. Fix 39f90217: overlay for both observers. The top screen then the bottom screen of real rows is the likely cause of the 25 extra editor mounts and of the other scroll path; a new trace must confirm it.
    - The one failure of aSteadyFlickMountsNoRowInTheStepThatShowsIt: FlickTranscript gave all tests the same preview row keys, and the flick tests count makes per row key while they run at the same time. RED theTurnsOfTwoTestsShareNoRowKey (6 shared keys); fix b6003720: message ids with the test name.
    - Did not work: reading the rows in view in the transform of the scroll geometry of the list (after the commit): 5 failures in the root suite (stale rows after a jump, anchor and redraw tests). Reverted.
    - On main too, TranscriptRowAnchorTests depends on timing: in an isolated run on main it failed (the at-rest move to the middle does not stay or does not snap back the same way each run).
    - Hover: no evidence that TranscriptRowsHover makes rows real; not changed.

    ### implement — changed
    - evidence: 39f90217, b6003720. Root swift test one run: 2093 tests in 263 suites + 59 in 12 passed, 0 issues. A and B counts unchanged (TranscriptScrollObserverTests, TranscriptRowHoverTests green).
    - next: parent: release trace of b6003720 against main.
  timestamp: 2026-11-28T06:25:32.997569+00:00
- actor: claude-code
  id: 01m8gdpfej1g5tbp8cafra30rr
  text: |-
    ### trace — hover and scroll observer branch not landed
    - evidence: release flick, 4 rounds each, main 204a33b8 against b6003720 (branch worktree-agent-abccc0067a726ce86: one stack hover, one scroll geometry observer, no visibility observer, overlay size views): main-thread 2852 → 2757 ms, per 1000 pt 116 → 115 ms, hitches 48.5 → 53.5, hitch sum 442 → 498 ms, delivered 99.38 % both, largest 16.7 ms → one run 25 ms. The first try fcc9de30 was worse (2924 ms, largest 83 ms, 25 extra editor mounts).
    - result: the hover cost (550 ms in the analysis) did not go away; the rows still hold EditorKit hover responders and the press gesture (card ^zqsemdq). Hitch metrics regress, so the branch stays unmerged.
    - next: cause C (the static form holds and measures the full real row content), one flat picture of the whole row while rows move.
  timestamp: 2026-11-28T06:32:48.850350+00:00
- actor: claude-code
  id: 01m8gekaac4dmq9z49zachewd5
  text: |-
    Flat moving row, research (2026-11-28, worktree agent-a4dbd496cdb4401c9, on main 204a33b8).
    - Probe 1 (headless, StaticRowHost, agent answer of one line, width 480): with a `messageFooter` of `MessageActions`, the cache height is 48 pt, the static row is 48 pt, and the real row is 73 pt. `transcriptRowsHaveDefaultLook` does not look at `messageFooter`, and no chrome rule has a footer. Thus in a host with a footer (the demo app, `SessionThreadColumn`), each static message row has a wrong height, and it jumps 25 pt when it becomes real. This is a defect of the current main.
    - Probe 2: SwiftUI `ImageRenderer` of the real chrome view (`MessageHeader`) at scale 2, put above the worker picture of the text in a plain `VStack` with the padding of the message, gives a row that is the same as the real row: mean 0.0013, large part 0.0 (light and dark). `ImageRenderer` also draws an `EditorToolbarButton` (25x25 px).
    - EditorKit has no off-main picture of a diff (only `render(markdown:)` and `render(code:)`). A diff slot shows `StaticCodeText`, so a row with a diff cannot be one flat picture without new EditorKit work.
    - EditorKit buttons (`EditorPlainButton`, `EditorToolbarButton`) use internal style parts (`tint.style(in:)`, `clearingHostTint()`), so AVK cannot copy their look with plain SwiftUI views. A picture of the real chrome view keeps the look exact.
    Plan: the chrome rules give a layout tree (`TranscriptRowNode`) in place of a bare height; the height is the height of the tree (no copy of the rules). The worker publishes the tree of each row with its height. A static row with an exact height, the pictures of each text part, and a chrome picture for each chrome line shows one flat view (`TranscriptFlatRow`): one layout that places the pictures and the chrome pictures at the rects of the tree, in a frame of the exact height. Chrome pictures: `ImageRenderer` of the real chrome view of the line, kept by line, width and appearance.
  timestamp: 2026-11-28T06:48:33.868179+00:00
- actor: claude-code
  id: 01m8gh7v2792zctc0hx3qxkdr1
  text: |-
    Flat moving rows landed in 0ee8c5c4 (worktree agent-a4dbd496cdb4401c9, on main 204a33b8). No push, no merge.
    - Design: `TranscriptRowChrome` gives a layout tree (`TranscriptRowNode`); the height is the height of the tree (one rule for the cache and the flat form). A static row (moving, or waiting at rest) with an exact height, a picture of each text part and a chrome line for each chrome view shows one `TranscriptFlatRow`: one `TranscriptFlatRowLayout` (no size query of a part) of `StaticPictureView`s, chrome line pictures (`ImageRenderer` of the real `MessageHeader`, `StatusCaption`, `CodeBlockHeader`, `ReasoningHeader`, `ToolCallToggle`, in the whole environment of the row, 8 pt bleed, kept by line/size/appearance in `TranscriptChromePictures`), and `editorBlockFrame()` bands. One accessibility element with the text of the row; press / assistive press / focus release a waiting row (`TranscriptStillInteraction`, shared with `StaticEditorSlot`). Kinds: user and agent messages (prose and fences), closed thought, closed tool call.
    - Counts per entering row (StaticRowHost, width 480), before -> after: views of the real row (ItemRow, item view, EntryContentView, ResponseView, tool header bodies) user 4->0, prose 4->0, fenced 4->0, thought 2->0, tool 2->0; flat body 1; flat layout 2 calls (one size, one placement); frame sizeThatFits 1->1; CA layers user 5->4, prose 3->3, fenced 10->7, thought 4->2, tool 6->2; chrome pictures drawn for a row that enters again: 0.
    - Pixels, flat vs real (mean / large part; limits 0.75 / 0.0075): user 0.0025/0 (light) 0.0024/0 (dark); prose 0.0016/0, 0.0016/0; fenced 0.077/0.0006, 0.078/0.0006; thought 0.035/0.0002, 0.038/0.0004; tool call 0.212/0.0021, 0.229/0.0021.
    - RED: 6 new tests (22 cases) and aFlickBuildsNoRealRowForARowThatComesIn failed on the old code (real-row bodies > 0). The footer, find-hit and chrome-cache guards were checked by one mutation run each (3 of 3 failed).
    - Did not work: a `@State` flag from `entersWhileMoving` to keep a row made at rest out of the flat form (onChange did not always run for a row past the view). Now the static row notes each body that shows the real views (`TranscriptRowRealViews`).
    - Discoveries: (1) a host footer (`MessageActions`) is in no chrome rule: cache 48 pt, real row 73 pt -> card ^grwk69d; such messages keep the old static form. (2) EditorKit has no off-main diff picture, so diff rows are not flat -> card ^5ywdsmm (also outputs, expanded tool bodies, terminal, plan, error, compaction, session message). (3) `aSteadyFlickMountsNoRowInTheStepThatShowsIt` depends on the test order: with `--filter "aSteadyFlick...|TranscriptFlatRowTests"` it fails 6/6 also with the flat form off (main behavior): the row above the view leaves before the flick and is made again in the showing step -> card ^dwybk4c. (4) FlickTranscript rows had shared row keys across tests; now message ids hold the test name.
    - Behavior changes: a waiting flat row has no context menu, no keyboard focus stops and no hover views until an interaction makes it real; `MessageRole` is nonisolated.
    - Tool friction: kanban `add comment` / `add task` return the whole board plan (~187 k characters) to a file.

    ### implement — changed
    - evidence: 0ee8c5c4, 18 files. Root `swift test` one run: 2093 tests in 260 suites + 59 tests in 12 suites, 0 issues, no own warnings. New tests (TranscriptFlatRowTests + aFlickBuildsNoRealRowForARowThatComesIn) 6 runs, 0 issues each. IntegrationTests, ScreenshotTests, xctrace not run (parent).
    - next: parent: release flick trace of 0ee8c5c4; /review.
  timestamp: 2026-11-28T07:34:43.527101+00:00
- actor: claude-code
  id: 01m8gk153hh11he4tr8srrha2p
  text: |-
    Check of the flat moving rows (worktree agent-a4dbd496cdb4401c9, HEAD 0ee8c5c4 -> 128a0e63). No push, no merge.
    - Pins: `swift package update EditorKit` in IntegrationTests and ScreenshotTests. Root, IntegrationTests and ScreenshotTests Package.resolved: EditorKit ea0ff6f76e0e76be94088ef7c16d811176e0b657.
    - IntegrationTests, one full run under a 15 min guard: 1100 tests in 164 suites passed, 5 known issues (FontRoleExpectationsTests, by design), exit 0, no guard kill. The build log had one own warning: CodeBlockView.swift, "main actor-isolated static property 'plainTextName' can not be referenced from a nonisolated autoclosure" (0ee8c5c4 made title(language:filename:) nonisolated). Fix 128a0e63: plainTextName is nonisolated. No unit test can show a compile warning, so no RED test; the IntegrationTests and root builds after the fix show no own warning.
    - Root swift test on 128a0e63, one run: 2093 tests in 260 suites + 59 tests in 12 suites passed, no own warnings.
    - ScreenshotTests gallery, one run (cache folder cleared first): 47 tests in 4 suites passed. Copy: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/cb6ea94a-55e6-4196-a95c-8572bfe4fa85/scratchpad/gallery-flat/ (388 PNGs).
    - Pixel compare with gallery-rowentry (main look): 383 same paths same to the pixel; 28 images that rowentry has only in snapshots/ (an old cache folder) compared with the flat generated/ copies, and the 4 thread images that flat has only in generated/ compared with the rowentry snapshots/ copies. Each thread, transcript and row image is the same to the pixel. Two images differ: generated/GlassSnapshotTests/floating-notes-reduce-transparency-light.png and floating-notes-dark.png (vs rowentry snapshots/), each mean 0.0023, large part 0.00002, 104 pixels in x 1502-1513, y 407-929: the scroll bar strip at the right edge. The rowentry run showed the same strip difference against run2, so this strip changes from run to run, and it is not a row. No flat-row defect found.

    ### implement — changed
    - evidence: 128a0e63 (Sources/AgentViewKit/Code/CodeBlockView.swift). IntegrationTests 1100/164 green (5 known issues); root 2093/260 + 59/12 green; gallery 47/4 green, no thread image changed.
    - next: parent: /review of 0ee8c5c4..128a0e63; merge decision.
  timestamp: 2026-11-28T08:06:01.585470+00:00
position_column: doing
position_ordinal: '8380'
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
