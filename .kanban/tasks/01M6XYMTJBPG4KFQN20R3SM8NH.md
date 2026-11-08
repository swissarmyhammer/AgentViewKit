---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6xzhsdbqcer4dqjg7vmba2v
  text: |-
    Research and work:
    - New file ScreenshotTests/Tests/ScreenshotTests/SelectionGalleryFixtures.swift. New test HostedSnapshotTests.theSelectionAndTheFocusOfTheItems, also called from ReviewGalleryScreenTests.recordSnapshots. ScreenshotTests/Package.swift now names the EditorCommands and EditorCommandsUI products.
    - A window holds one focus, so the screen is 4 images (each Light and Dark): item-focus-row, item-focus-chip, item-focus-message (key window, \.appearsActive true) and item-focus-row-not-key (\.appearsActive false). Each image shows the same items: AgentRowList (current row "Inbox" selected), AttachmentChip "notes.bin", AttachmentView chip "report.bin" selected through InspectorSelection, and a user message in an agentCommandScope.
    - The settle lands the focus through the command system: #require(areBeaconsLive), then #require(geometry.requestFocus(at:)) (sync), one RunLoopBlockFence pass, render. No timeout, no poll. Each image and look has its own CommandSystem.
    - The capture window of ReviewGallery is the key window (CaptureWindow takes key focus for a capture). So the not-key look comes only from \.appearsActive false, as in EK SelectableItemGallery.
    - Discovery (defect of ^v3zpcpd): a focused AgentRowList row shows the system focus ring and no focused fill. Checked in the settle: the first responder is SwiftUI KeyViewProxy (the .focusable() of AgentRowClicks), the beacon holdsFocus is false. The hosted tests miss it because the harness window is never key. New task 01M6XZHDR31KKRYTTKAN73FFTT records it (same cause as ^ekc1mpb, waits for EK ^tmwpx2x).
    - The scope ring of a focused message shows a band that is thin at the top and left and thick at the bottom and right. A person must judge it.
  timestamp: 2026-11-08T16:23:33.547137+00:00
- actor: claude-code
  id: 01m6xzs9qr4pxtshtf421msxef
  text: |-
    ### implement — changed
    - evidence: 4 files — ScreenshotTests/Package.swift, ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift, ScreenshotTests/Tests/ScreenshotTests/ReviewGalleryScreenTests.swift, ScreenshotTests/Tests/ScreenshotTests/SelectionGalleryFixtures.swift (new). swift test: 1074 + 50 tests passed. IntegrationTests: 1037 tests passed, 5 known issues (FontRoleExpectationsTests, deliberate). ScreenshotTests: 33 tests passed.
    - PNGs: ~/Library/Caches/AgentViewKit/screenshot-check/snapshots/HostedSnapshotTests/item-focus-{row,chip,message,row-not-key}-{light,dark}.png.
    - Looks checked: selected fill on row "Inbox" and on "report.bin" (soft accent) shows; focused fill on chip "notes.bin" (stronger accent) shows; inactive grey shows in row-not-key; ring of the focused message shows (band thicker at the bottom and right, a person must judge it). Defect: the focused row "Drafts" shows the system focus ring and no focused fill, in each look. New task 01M6XZHDR31KKRYTTKAN73FFTT records it.
    - next: /review
  timestamp: 2026-11-08T16:27:39.640668+00:00
- actor: claude-code
  id: 01m6y00pe6bssecr69wcze2bhp
  text: |-
    ### test — green
    - evidence: swift test: 1074 + 50 tests passed. IntegrationTests: 1037 tests passed (5 known issues, deliberate negative tests in FontRoleExpectationsTests). ScreenshotTests: 33 tests passed. 0 failures, 0 skipped. Only warning: SwiftPM "missing creator for mutated node" for the mlx-swift_Cmlx.bundle, a build-system message outside the changed code.
    - next: review
  timestamp: 2026-11-08T16:31:42.022556+00:00
position_column: doing
position_ordinal: '80'
title: Snapshot of the selection and focus look of AVK items
---
Found during ^v3zpcpd. No snapshot of ScreenshotTests shows a focused item, so after ^v3zpcpd no PNG changed and the user cannot review the new focus look.

To do:
- [ ] Add a HostedSnapshotTests screen (light and dark) with: an AgentRowList with a selected row and a focused row, a focused AttachmentChip, a selected AttachmentView chip, and a focused message (ring, no surface). Land the focus through the command system in the harness window. The window is never ordered in and never key; the inactive grey of a window that is not key is part of the look, so also show the active look as EK SelectableItemHostedTests does (`\.appearsActive`).
- [ ] Give the PNG paths to the user.

Test rules: no clock/sleep/poll/retry/timeLimit/XCUITest; no window shown and no focus taken.