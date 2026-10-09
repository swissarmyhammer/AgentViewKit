---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4gj7dr7qtzg641t8b9vh1rf
  text: |-
    Research and reproduction:

    - How to reproduce: run 6 test-bundle processes at the same time with `swiftpm-testing-helper --test-bundle-path <AgentViewKitTests binary> --testing-library swift-testing --filter theShowErrorButtonMovesToTheErrorEntry --repetitions 30 --repeat-until fail`, with `DYLD_FRAMEWORK_PATH` and `DYLD_LIBRARY_PATH` set to the Xcode MacOSX platform paths. With `waitTimeout` at 5 s, 4 of 6 processes failed (then 3 of 6, 3 of 6, 5 of 6 in the next runs). The failure is the same as on the card: `visibleIDs` is `[m0, m1, m2, m3, m4]`, with no error row.
    - Temporary log lines (now removed) show that the scroll DOES go to the error row. In each failed run: the NSScrollView clip origin is y=8 (the top of the content). The accessibility frame of the error row is inside the frame of the list (error row y 261..320, list y 83..320, screen points). The frames are the same as in a run that passes. Thus the statement on the card "a scroll that did not go to the error row" is not correct.
    - The cause: `ScrollAnchorManager.visibleIDs` comes from the SwiftUI `onScrollTargetVisibilityChange` callback. After the long jump, the LazyVStack does a first layout pass with estimated row positions. In that pass the error row view is a row that SwiftUI kept from the mount, and it still has an old position far below the viewport (y=2056 in scroll view space). The callback reports `[m0..m4]` from that pass. The next layout pass puts the error row at y=0, but the content offset and the content size do not change, and SwiftUI does not call `onScrollTargetVisibilityChange` again. Thus `visibleIDs` stays stale for all of the wait. A longer wait cannot help: no new callback comes. In a run that passes, the error row appears new in the first pass, so the first report is correct.
    - Why load makes it happen: the timing of the mount passes decides if the error row view is still alive (with an old position) when the jump starts.
    - Thus the test is wrong, not the scroll code: it checks a SwiftUI report that SwiftUI does not refresh after the lazy stack corrects its layout. The correct check is what the user sees: the frame of the error row is in the frame of the list.
    - Discovery for later: after a long jump, `ScrollAnchorManager.visibleIDs` can be stale until the next scroll. I will add a separate card for this.
  timestamp: 2026-10-09T14:49:11.175819+00:00
- actor: claude-code
  id: 01m4gmyx4eh7005r577dnz68sy
  text: |-
    Implementation landed.

    Change (test code only, no production code change):
    - `HostedViewHarness.frame(identifier:)` (new, AgentViewKitTestSupport): the accessibility frame of an element, in screen points. TDD: `HostedViewHarnessTests.readsTheFrameOfAnElement` failed first (no member `frame`), then passed.
    - `ConversationViewHostedTests.showsRow(_:in:)` (new): true when the accessibility frame of the row is in the frame of the list. Its doc comment tells why the test does not read `visibleIDs`.
    - `theShowErrorButtonMovesToTheErrorEntry` now waits for and checks `showsRow(errorKey)`. Before the press it checks `!showsRow(errorKey)`. It does not check `anchors.visibleIDs.contains(errorKey)` any more.
    - `waitTimeout` is 5 s again. The 30 s limit is not necessary: the failure was a stale report, not a slow scroll, and a longer wait cannot help. The doc comment no longer says that a scroll takes more than five seconds.

    What did not work / was not done:
    - A fix in `ConversationView` was not possible without a geometry callback on each row: when only the rows move, SwiftUI gives no scroll geometry change and no visibility change. A new card ^8wb97aa ("Decide if ScrollAnchorManager.visibleIDs must be correct after a long jump in ConversationView") records this for a person to decide.

    Verification:
    - Same load as the reproduction (6 parallel processes x 30 repetitions of the test): 180 of 180 passed (before: 4 of 6 processes failed).
    - 6 parallel processes x 10 repetitions of ConversationViewHostedTests and HostedViewHarnessTests: all passed.
    - 5 full `swift test` runs one after the other (acceptance criterion):
      - run 1: exit 0; 1035 tests in 110 suites passed, 93 tests in 11 suites passed, 1 test passed; theShowErrorButtonMovesToTheErrorEntry passed (5.984 s)
      - run 2: exit 0; 1035 / 93 / 1 passed; the test passed (6.633 s)
      - run 3: exit 0; 1035 / 93 / 1 passed; the test passed (6.281 s)
      - run 4: exit 0; 1035 / 93 / 1 passed; the test passed (6.586 s)
      - run 5: exit 0; 1035 / 93 / 1 passed; the test passed (6.856 s)
    - The test time of about 6 s in a full run is the wait for the hosted-test lock: the other hosted tests of the suite take 6 to 11 s in the same run. Alone, the test takes 0.5 s.
    - The only warning is the known mlx-swift build warning "missing creator for mutated node".
  timestamp: 2026-10-09T15:36:57.742683+00:00
- actor: claude-code
  id: 01m4gmz7s1j1t990kskrw032ka
  text: |-
    ### implement — changed
    - evidence: cause found — the scroll goes to the error row, but `onScrollTargetVisibilityChange` reports the rows of a first lazy-stack layout pass (with an old position for the kept error row view) and does not report again after the correction, so `anchors.visibleIDs` stays stale. Files: Sources/AgentViewKitTestSupport/HostedViewHarness.swift (new `frame(identifier:)`), Tests/AgentViewKitTests/TestSupport/HostedViewHarnessTests.swift (new `readsTheFrameOfAnElement`, red then green), Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift (`showsRow(_:in:)`, the test checks the frames, `waitTimeout` 30 s back to 5 s). Reproduction load (6 parallel processes x 30 repetitions): 180/180 pass (before: 4 of 6 processes failed). 5 full `swift test` runs one after the other: 5 of 5 exit 0, each 1035 + 93 + 1 tests passed, the target test passed each time; only the known mlx-swift build warning.
    - next: /review
  timestamp: 2026-10-09T15:37:08.641963+00:00
position_column: doing
position_ordinal: '80'
title: Make ConversationViewHostedTests.theShowErrorButtonMovesToTheErrorEntry stable in the full suite run
---
## What
During the test step of ^ahfhekw, `theShowErrorButtonMovesToTheErrorEntry` in `Tests/AgentViewKitTests/Thread/ConversationViewHostedTests.swift` failed one time in a full `swift test` run. After the test pushed Show Error, `anchors.visibleIDs.contains(errorKey)` stayed false for all of the 5-second wait. The list showed `conversation-m0` to `conversation-m4`, and did not show the error row. The test passed alone, and the full suite passed alone.

The tester increased `waitTimeout` in this file from 5 seconds to 30 seconds. This does not correct the cause. The failed state was a scroll that did not go to the error row. It was not a scroll that was only slow.

- [x] Find why the scroll does not go to the error row when the full suite runs.
- [x] Correct the cause. Then decide if the 30-second wait is necessary, and set it back to 5 seconds if it is not.

## Acceptance Criteria
- [x] The test passes in 5 full `swift test` runs one after the other.

## Tests
- [x] `swift test` passes.