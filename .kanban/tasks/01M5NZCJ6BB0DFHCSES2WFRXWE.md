---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5pkckaejvwwheyqg20acncx
  text: 'Fixed by the work on ^hzez035 (not committed yet). The cause was the kit, not the sidebar. `DeckStackLayout.sizeThatFits` (Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift) measured each card at `(width: proposal.width, height: nil)`. On SwiftUI''s `.zero` minimum probe, the permission card''s text wrapped at width 0, so `RequestDeck(session:)` reported a minimum height of about 1218 pt. That grew the window to 1558 pt as soon as a request showed. The sidebar''s three Lists have only a 208-pt minimum. Fixes: (1) the layout passes a zero proposed height through, so the minimum probe gets each card''s own minimum. A new hosted test, `RequestDeckHostedTests.theMinimumHeightOfADeckIsNotMoreThanItsHeightAtTheWindowWidth`, uses HostedLayoutExpectations; it failed first and passes now. (2) The demo WindowGroup gets `.defaultWindowPlacement` (1100x800, clamped to the visible rect of the screen it opens on) and `.windowIdealSize(.maximum)`. The window now opens at 1100x800 on the 2560x1410 display and stays that size with a permission request waiting. `Scripts/test-examples.sh AgentViewKitDemo` passes 7/7. Still open on this card: the subtask ''A demo UI test that checks the window frame fits the screen of the window'' (XCUITest cannot read a screen''s visible frame; the hosted kit test guards the cause instead).'
  timestamp: 2026-10-24T09:20:37.710114+00:00
- actor: claude-code
  id: 01m5pn56t72m9qdmr6f6ebfbrc
  text: 'Picked up. Verified against HEAD that 3f186b0 (^hzez035) holds the fix for the first two subtasks: `DeckStackLayout.sizeThatFits` (Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift) passes a zero proposed height through on the minimum probe (`isMinimumProbe`), guarded by `RequestDeckHostedTests.theMinimumHeightOfADeckIsNotMoreThanItsHeightAtTheWindowWidth`; the demo `WindowGroup` (Examples/AgentViewKitDemo/AgentViewKitDemo/AgentViewKitDemoApp.swift) has `.defaultWindowPlacement` sizing the window to min(1100x800, visibleRect of the default display) and `.windowIdealSize(.maximum)`. Correction to the earlier comment: the UI test runner is a macOS process and can `import AppKit` and read `NSScreen.screens` (frame/visibleFrame). Plan for the third subtask: a new UI test class in Examples/AgentViewKitDemo/Tests that converts each screen''s visibleFrame from AppKit''s bottom-left-origin coordinates (relative to the primary screen, `NSScreen.screens[0]`) into XCUITest''s top-left-origin global coordinates, picks the screen with the largest overlap with `app.windows.firstMatch.frame`, and asserts the visible frame contains the window frame: after launch on the Gallery tab, after launch on the ACP tab, and while the Gallery''s scripted permission request (`gallery-permission`) waits. The permission-session opening that MainMenuEndToEndTests has privately moves into the shared DemoTestValues.swift so both classes use it. RED: temporarily revert the two 3f186b0 fixes (deck minimum probe + window placement) and run the new tests under the UI-test lock.'
  timestamp: 2026-10-24T09:51:32.679183+00:00
- actor: claude-code
  id: 01m5pnr58w5thpv0t6btymn5xy
  text: 'Implementation landed (uncommitted). New `Examples/AgentViewKitDemo/Tests/WindowFrameEndToEndTests.swift` (3 tests). The runner imports AppKit; `NSScreen.visibleFrame(ofScreenHolding:)` flips each screen frame and visible frame with `y'' = primaryScreen.frame.maxY - rect.maxY` (primary = `NSScreen.screens[0]`) into XCUITest top-left global coordinates, picks the screen with the largest overlap with `app.windows.firstMatch.frame`, and the test asserts `visibleFrame.contains(windowFrame)` with no tolerance. The permission-session opening moved from MainMenuEndToEndTests into `XCUIApplication.openThePermissionSession()` in DemoTestValues.swift (identifiers `permissionSessionRow`, `permissionAgentMessageRow`, `permissionCard` now shared), so both classes call one helper. RED, run under the shared UI-test lock with only this class: I temporarily reverted the two 3f186b0 fixes (removed `.defaultWindowPlacement`/`.windowIdealSize(.maximum)` and set the deck card proposal back to `height: nil`). The permission-state test failed with `The window frame (730.0, 30.0, 1100.0, 1558.0) does not fit the visible frame (0.0, 30.0, 2560.0, 1320.0) of its screen.`, which is the 1558-pt bug. The two launch-state tests passed even without the fix, because the window grows only once a request shows. I then restored both files with `git checkout --`, and all 3 pass. Finding: on this machine the 2560x1440 display has a visible frame of 2560x1320 at y=30 in XCUITest coordinates (menu bar 30, Dock 90).'
  timestamp: 2026-10-24T10:01:53.692999+00:00
- actor: claude-code
  id: 01m5pnr8wq9ardtktmdeat9w61
  text: |-
    ### implement — changed
    - evidence: 3 files — Examples/AgentViewKitDemo/Tests/WindowFrameEndToEndTests.swift (new), Examples/AgentViewKitDemo/Tests/DemoTestValues.swift, Examples/AgentViewKitDemo/Tests/MainMenuEndToEndTests.swift. `swift test`: 1798 tests in 220 suites passed, 7 known issues. Demo `xcodebuild clean build` (-skipMacroValidation -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile): BUILD SUCCEEDED, 0 warnings from repo sources (only mlx-swift and appintentsmetadataprocessor). `Scripts/test-examples.sh AgentViewKitDemo`: 10/10 UI tests passed, "The example gate passed." RED observed for the permission-state test with the 3f186b0 fixes temporarily reverted. All 3 subtasks checked off; the first two cite 3f186b0.
    - next: /review
  timestamp: 2026-10-24T10:01:57.399673+00:00
- actor: claude-code
  id: 01m5pq0yh4rh54n9f5j7dmrwge
  text: |-
    ### test — green
    - evidence: swift test: 1801 tests in 220 suites passed, 7 known issues. xcodebuild AgentViewKitDemo build: BUILD SUCCEEDED, zero warnings from repo sources (only the Xcode tool line "appintentsmetadataprocessor: Metadata extraction skipped, no AppIntents.framework dependency found"). Scripts/test-examples.sh AgentViewKitDemo: TEST SUCCEEDED, 10 UI tests, 0 failures, including the 3 WindowFrameEndToEndTests. The WIP references no window-size constants from DemoWindowLayout, so no change was needed. The xcodeproj was regenerated with generate_xcodeproj.rb.
    - next: review / commit
  timestamp: 2026-10-24T10:24:10.276303+00:00
- actor: claude-code
  id: 01m5pq3yqmm78t8zn6g6w5dtzr
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (9979b38) — 0 findings (confirmed 0, refuted 1, attempted 7, failed 0, skipped 0); 3 files reviewed, 0 not reviewed
    - next: none — task moved to done
  timestamp: 2026-10-24T10:25:48.788498+00:00
- actor: claude-code
  id: 01m5pq4d3x56qbm422h763v8aj
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — WindowFrameEndToEndTests.swift (new), DemoTestValues.swift, MainMenuEndToEndTests.swift; first two subtasks covered by 3f186b0
    - test: green — swift test 1801/220 (7 known issues), demo build 0 repo warnings, test-examples.sh 10/10 under lock (after merge d56b4de)
    - commit: f6cb334 (chore kanban), 9979b38 (code, HEAD)
    - review: clean — 0 findings on HEAD~1..HEAD; task in done
  timestamp: 2026-10-24T10:26:03.517685+00:00
position_column: done
position_ordinal: ffffd780
title: 'AgentViewKitDemo: the window opens taller than a 1440-pt display, so the request deck and the composer sit off-screen'
---
Found while doing ^hzez035. On a 2560x1440 display the demo window opened at 900x1558 pt (XCUITest frame `{{830, 30}, {900, 1558}}`), even with a saved frame of 900x1320, and the Zoom button kept the height at 1558. The bottom of the window, where the thread's floating controls hold the `RequestDeck` and the composer, is then below the screen: XCUITest reports `permission-card` and `prompt-editor` as not hittable, and a click there lands nowhere.

The height looks like the minimum or ideal height of the content (the Gallery sidebar stacks three lists: 414 + 414 + 470 pt), and the ACP tab window measured the same 1558 pt.

## What to do
- [x] Measure the content minimum height of `DemoRootView` on each tab and find what pins it at ~1558 pt. (Done in 3f186b0: the cause was `DeckStackLayout.sizeThatFits` in RequestDeck.swift measuring each card at the zero-width minimum probe, about 1218 pt for the permission card; guarded by `RequestDeckHostedTests.theMinimumHeightOfADeckIsNotMoreThanItsHeightAtTheWindowWidth`.)
- [x] Make the window fit a 1440-pt display (for example a sidebar that scrolls as one list, or `.defaultSize` / `.windowResizability` on the `WindowGroup`), so the deck and the composer stay on screen. (Done in 3f186b0: `.defaultWindowPlacement` sizes a new window to min(1100x800, visible rect of its display), plus `.windowIdealSize(.maximum)`.)
- [x] A demo UI test that checks the window frame fits the screen of the window. #avk-8 (`Examples/AgentViewKitDemo/Tests/WindowFrameEndToEndTests.swift`: reads `NSScreen.screens` in the runner, flips each visible frame into XCUITest top-left coordinates, and asserts the visible frame of the screen that holds the window contains the window frame, after launch on the Gallery and ACP tabs and while the Gallery permission request waits.)