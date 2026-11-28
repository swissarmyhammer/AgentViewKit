---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8fp720mzk2neraz8mdtwhvr
  text: |-
    Research (virtual4 worktree, after the merge of main 7b76664a as 2d4f56d6). An A/B probe in the unit host (MovingThread, 50 flick turns, 399 live steps of 40 pt, debug, scratch test, deleted) compared the virtual stack with the LazyVStack of main in the same build. Virtual: 0.20-0.21 s, LazyVStack: 0.13-0.14 s. The ratio is near the ratio of the release traces (5.8 s against 3.4 s).

    Counts of the virtual stack in that flick: 76 stack bodies, each body computed the whole geometry (11,400 height reads, 17 ms debug); 64 bodies came only from a change of the rows in view, 20 from a first record of a row at the height that the stack already used (geometry did not change). 616 ForEach element builds.

    What did not help: an Equatable wrapper around each element (no change), and the removal of the per-row onGeometryChange (no change). What the probe showed as the main cost: the overscan. With overscanScreens 0 the virtual stack is equal to the LazyVStack (0.15-0.16 s both). With 0.5 it is 0.20-0.27 s. Each mounted row costs SwiftUI work on each scroll step, the real rows from rest stay mounted in the overscan at the start of a flick (132 NSViews and 8 text views at step 50, against 55 and 3), and the rows come in batches of about 3 per body (largest step 12-18 ms debug against 4-5 ms).

    Side discovery: during the first layout the stack mounts the rows at the top of the transcript one time (preview-0..13 get records), before the bottom anchor applies. Also the real height of some rows differs from the exact static height (for example 1057 against 1153 at the start of a live motion), so the geometry changes at the start of a flick.
  timestamp: 2026-11-27T23:42:26.324175+00:00
- actor: claude-code
  id: 01m8fpng33mt31vkk1j44qnsct
  text: |-
    ### implement — changed
    - evidence: worktree virtual4, branch worktree-agent-a5cf34a37aa5709be. Merge of main 2d4f56d6, fix b722bf9f. Root `swift test`: 2065 tests in 253 suites and 59 tests in 12 suites pass, 0 warnings in the changed files. IntegrationTests and ScreenshotTests were not run and not built (they use no changed symbol).
    - causes and counts (unit host, 50 flick turns): (1) overscan of one screen: probe flick 0.20-0.27 s against 0.13-0.16 s of the LazyVStack; with no overscan, equal (TranscriptRowGeometryTests/theMountedRowsAreTheRowsInView). (2) the whole geometry in each body: 11,400 height reads in 399 steps, now 0 (TranscriptFlickWorkTests/aFlickReadsNoRowHeightWhenNoHeightChanges). (3) a body for each change of the rows in view: 21 window bodies for 12 rows made in 150 steps, now at most one for each row made (aFlickEvaluatesTheWindowOnlyToMountARow; 76 stack bodies became 11-33 window bodies in 399 steps). (4) a first record at the height in use bumped the revision (20 of 76 bodies), now no change (TranscriptElementHeightsTests/aFirstRecordAtTheHeightInUseIsNoChange). (5) the stack body read the pin state of the scroll anchors, so the first move from the bottom computed the geometry again; the body reads no scroll state now.
    - not helped: an Equatable wrapper around each element; removal of the per-row onGeometryChange.
    - open: in the debug unit host the virtual stack only equals the LazyVStack. A release trace must show whether it is faster. Each row that comes into view costs a little more in the virtual stack (about 2.8 ms against 2.4 ms in debug: window body, ForEach diff, a new placement of each mounted row).
    - next: the parent runs the release flick trace and the hosted suites.
  timestamp: 2026-11-27T23:50:19.491443+00:00
- actor: claude-code
  id: 01m8frfxxnw490zy2xyamktyp0
  text: |-
    Height check (virtual4, before the release decision). The virtual height 49,720 pt is right; the LazyVStack height of main (75,644 pt) is an estimate.
    Evidence: (1) New root test TranscriptStackHeightTests (MovingThread with the height cache, 4 rounds of markdown, code block, tool call, diff, thought): the list height equals the top inset + the sum of the exact cache heights + 19 spacings + the bottom padding, within 1 pt. For each of the 5 kinds, a row of the middle round scrolled into view at rest becomes real (editors in view), and the list height stays equal to the exact sum, so each real row fills its exact slot (no cut, no overlap). (2) Flick JSONs of the release harness, same 312-entry transcript: the LazyVStack height of one build changes from run to run (final r1-r6: 75,537-76,048; rest r1-r6: 75,573-76,389); the virtual height is 49,720 in each of 4 runs. (3) In each LazyVStack run, the flick starts at offset 13,340 (the bottom of an estimate of about 14,200 pt), and sweep 2 jumps from 10,392 to 68,854 (58,000 pt in one sweep), when the estimate grows. The virtual run starts at the bottom (48,820 + 900 = 49,720) and each sweep moves 2,948 pt. Thus the two flicks did not scroll the same rows: the LazyVStack flick path is 81,298 pt (with the jump), the virtual path 20,393 pt. The perf comparison (2586 against 3149 ms) is valid for the virtual stack, but the LazyVStack number includes the jump. (4) Spike V1 measured each real row with ceil (older AVK): 51,365.
    What did not work: reading the row frames from the accessibility tree in MovingThread (withAccessibilityTree, settle in the hold) gave nil for each row, so the slot test reads the list height after the rows become real.
  timestamp: 2026-11-28T00:22:14.197001+00:00
- actor: claude-code
  id: 01m8frvpkn5vnw2sj3x8g0wv4j
  text: 'Hosted IntegrationTests run 1 (virtual4, EditorKit pin updated to 21a8a01 like the root) stopped after 100 s with "Fatal error: Index out of range". lldb stack: TranscriptRowStack.targetGeometry read transcript[-1] with 0 entries. Cause: the stack reads session.transcript itself, but shownCount comes from ConversationView; a resume with a replay from the start empties the transcript (SessionModel.resetTranscript), and SwiftUI evaluated the stack before the list, with the old shownCount. RED: TranscriptRowStackResetTests/aReplayThatEmptiesTheTranscriptRemovesEachRow (ScriptedSession with 6 answers in a MovingThread, then resumeSession(replayFromStartRequest)) stopped the test process with the same fatal error. GREEN: the stack shows at most transcript.count entries, and the window mounts only positions of its own transcript. Second defect of the same kind (RED then GREEN in TranscriptRowGeometryTests): the kept-row margin of mountedRows could hold the index -1 or count (a kept row past the end after a shorter transcript); the margin is now clamped to the rows of the geometry. That fix alone did not stop the hosted crash (run 2 crashed the same way).'
  timestamp: 2026-11-28T00:28:39.925445+00:00
- actor: claude-code
  id: 01m8fvh82n426t6bmvjvrtae33
  text: |-
    ### implement — changed
    - evidence: commit 2461b9cf (worktree virtual4): TranscriptRowGeometry.swift, TranscriptRowStack.swift, TranscriptRowGeometryTests.swift, TranscriptRowStackResetTests.swift (new), TranscriptStackHeightTests.swift (new).
    - height: the virtual height 49,720 pt is right; the LazyVStack 75,644 pt is an estimate (see the comment above). TranscriptStackHeightTests: list height = top inset + sum of exact cache heights + spacings + bottom padding (1 pt tolerance), and a real row in view of each kind (markdown, code block, tool call, diff, thought) keeps its exact slot. No fix was needed for the height.
    - fixes (RED then GREEN): the stack read transcript[-1] after a reset of a replay (hosted crash "Index out of range"); the kept-row margin could hold the index -1 or count.
    - IntegrationTests (EditorKit pin 21a8a01, temp HOME, 15-min guard): run 1 and 2 crashed; run 3 after the fix: 1100 tests in 164 suites pass, 5 known issues. A later run (with a reverted change) also 1100 pass.
    - root swift test (final): 2072 tests in 255 suites and 59 tests in 12 suites pass, 0 issues.
    - gallery: main is stable (two runs byte-identical). virtual4 differs in 21 PNGs (13 in screens/ and generated/, and the 8 snapshots/ copies of the generated glass images): thread-light/dark (about 4 pixels), scrolled-light/dark, inspector-dark, floating-notes x4, floating-sign-in x4 (at most 0.12 % of the pixels each). The real difference: no row mounts under the top glass bar (scrolled screens). New card ^6fax5yx records it, with a failed attempt (insets record) that made the gallery jump drift; that attempt is reverted.
    - tool friction: each kanban add comment / add task returned the whole board plan (about 187,000 characters).
    - next: review; ^6fax5yx for the rows under the bars.
  timestamp: 2026-11-28T01:15:23.093570+00:00
depends_on:
- 01M8C4Z702KVEKGM5TY9H7BM9J
position_column: todo
position_ordinal: '8580'
title: 'Scroll 2: a virtual transcript layout with an exact total height in ConversationView'
---
From spike ^fa3j934 (2026-11-26). The LazyVStack of `ConversationView` estimates its total height +72 % too high (88,271 pt against 51,365 pt), and it corrects while the user scrolls. The spike variant V1 (an exact height and a fixed pool of rows) gave -9 % main-thread time and a largest hitch of 33 ms against 50 ms. It is also the base of the static rows (the next card).

## What
- [ ] In `Sources/AgentViewKit/Thread/ConversationView.swift`, replace the `LazyVStack` with one custom SwiftUI `Layout`: `sizeThatFits` returns the exact total height from the prefix sums of the cached heights (^9h7bm9j), and the placement places only the rows in view plus 1 screen of overscan.
- [ ] The visible range comes from the scroll geometry, but the state changes only when the first or the last visible index changes, not on each frame.
- [ ] Slot ids come from a fixed pool (index modulo the pool size), as in the spike (`scratchpad/spike-virtual/Tests/ScrollProfileTests/VirtualTranscript.swift`). Row `@State` that must survive stays in the model.
- [ ] Keep the `ScrollView`, the bottom anchor, `scrollPosition`, the floating controls, the jump to an item and the visibility reports. With prefix sums, a scroll to an item or to the bottom goes to an exact offset.
- [ ] Keep the `TranscriptRowElement` contract (one view for each element), the row ids, the reading order and the accessibility identifiers.

## Acceptance Criteria
- [ ] The total content height equals the sum of the row heights plus the spacing.
- [ ] All hosted thread suites pass: ThreadFloatingControlsHostedTests, RecordedSessionsGalleryHostedTests, ThreadBarBannerOverlapHostedTests, AgentItemFocusHostedTests and the full IntegrationTests run.
- [ ] The flick trace of the spike harness shows main-thread time at or below V1 of the spike.

## Tests
- [ ] Unit tests: the prefix sums, the visible range for an offset, the pool slot ids, and the exact offset of a scroll to an item.
- [ ] `swift test` passes with 0 failures and 0 warnings. The full IntegrationTests run passes (a hosted run with start and end lines).

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #perf