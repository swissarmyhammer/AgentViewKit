---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5yxf530rhacap3mx6jv96yd
  text: |-
    Research (implement):
    - The green comes from AVK, not from an EditorKit default being wrong: `SendStateLabel` and `OutputExitLabel` each put `.foregroundStyle(editorTheme.statusColor(for:))` on a whole `Label`, so the caption text takes `statusSucceeded` (34c759 in light). `statusSucceeded` is the right color for a status symbol; the fix belongs in AVK (the two views), so no EditorKit change and no stuck.
    - Both views draw the same shape (caption Label, status symbol, text), so the fix is one shared view: the symbol through `StatusSymbolImage` (the kit's status-symbol view, hierarchical, symbol weight) in the status color, and the title in a readable hierarchical style.
    - `.secondary` in light is about 3.8:1 on the window background (the card itself measured 3.9:1 on white), below the 4.5:1 that the requester asked the hosted test to check (`CompositedSnapshotTests.minimumTextContrast`). The test decides: if `.secondary` does not reach 4.5:1 in the hosted image, the title takes `.primary`.
    - Test plan: hosted path A image (`ViewSnapshot.makeHarness` + `pixels(of:)`), the accessibility frame of the label in window space (`ThreadBarControlJumpHostedTests.windowSpaceFrame`), the symbol = the first run of columns with ink, the text = the columns after it; contrast via the test-target `RegionColors`. No TestSupport change.
    - Snapshots expected to change: thread-*.png and terminal-*.png of HostedSnapshotTests.
  timestamp: 2026-10-27T14:50:42.656444+00:00
- actor: claude-code
  id: 01m5yy5g6q80bqktst3rv0jqxj
  text: |-
    Implementation landed (not committed):
    - New `StatusCaptionLabel` (Sources/AgentViewKit/Items/StatusCaptionLabel.swift): `Label { Text(title).foregroundStyle(.primary) } icon: { StatusSymbolImage(name:color:) }` in the caption UI font. `SendStateLabel` and `OutputExitLabel` both use it, so neither tints a whole `Label` with `statusColor(for:)` any more. The status color reaches only the symbol; the unknown-outcome exit label keeps `Color.secondary` on its symbol.
    - Deviation from the card text, measured: the card says `.secondary`, but `.secondary` measured 3.95:1 in light in the hosted image (RED/GREEN run of `theTitleIsReadable`), below the 4.5:1 the requester asked for. The requester allowed primary or secondary, so the title is `.primary`. Dark passes either way.
    - Test: `Tests/AgentViewKitTests/Items/StatusLabelColorHostedTests.swift` (12 cases: Sent and Exit code 0, light and dark). Path A image; the label's accessibility frame; symbol = the first run of inked columns, title = the columns after the gap. It checks that the symbol has a pixel close to `statusSucceeded`, that the title has none, and that the title contrast is at least `CompositedSnapshotTests.minimumTextContrast` (4.5). RED before the fix: title green in all 4 cases, contrast fails in light for both labels.
    - `EditorThemeViewsTests.defaultThemeSucceeded(in:)` was added, generalizing the light-only helper. No change to Sources/AgentViewKitTestSupport.
    - Re-recorded only the snapshots that failed: HostedSnapshotTests thread-{light,dark,reduce-transparency,increase-contrast}.png and terminal-{light,dark,reduce-transparency,increase-contrast}.png.
    - Regenerated the gallery (`swift test --filter ReviewGallery`). Updated ReviewGalleryNotes for thread, banners, signIn, scrolled and inspector. The new images were not judged by eye: I could not view the PNGs in this session.
    - The card has no checkbox subtasks to tick.
  timestamp: 2026-10-27T15:02:54.935650+00:00
- actor: claude-code
  id: 01m5yy5kyexm1bqn27xnqfhz3s
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Items/StatusCaptionLabel.swift (new), Sources/AgentViewKit/Items/UserMessageView.swift, Sources/AgentViewKit/Content/OutputChrome.swift, Sources/AgentViewKit/Items/StatusSymbolImage.swift (doc), Tests/AgentViewKitTests/Items/StatusLabelColorHostedTests.swift (new), Tests/AgentViewKitTests/Theme/EditorThemeViewsTests.swift, Tests/AgentViewKitTests/Snapshots/ReviewGalleryNotes.swift, 8 re-recorded PNGs (thread-*, terminal-* of HostedSnapshotTests). `swift test`: 1862 tests in 231 suites passed (7 known issues, all pre-existing withKnownIssue tests), plus 255 tests in 34 suites passed. The only warning is the pre-existing SwiftPM "missing creator" warning for the mlx-swift bundle.
    - next: /review. The title uses `.primary`, not the card's `.secondary` (3.95:1 measured); the reviewer should confirm that choice.
  timestamp: 2026-10-27T15:02:58.766520+00:00
- actor: claude-code
  id: 01m5yyb1nta2dfh6444htg9pqy
  text: |-
    ### test — green
    - evidence: `swift test` (one full run, exit 0) — 1862 tests in 231 suites passed, 0 failures, 0 skipped, 7 known issues (the expected count: SnapshotStoreTests 1, HostedLayoutExpectationsTests 1, FontRoleExpectationsTests 5, all negative-path tests). No compiler warnings in repo code; the only `warning:` line is SwiftPM's "missing creator for mutated node" for the mlx-swift_Cmlx.bundle build product, a dependency build artifact. No source or test edits were needed; no snapshots re-recorded (git status shows the same 8 thread-*/terminal-* PNGs as before).
    - next: review
  timestamp: 2026-10-27T15:05:56.666418+00:00
position_column: doing
position_ordinal: '8580'
title: 'AVK-8 status labels: draw the text of "Sent" and "Exit code" in a readable color, and keep the status color on the symbol (finding of ^8q34yt8)'
---
Found by the review gallery of ^8q34yt8 (2026-10-27).
- Screens: `sign-in`, `banners`, `scrolled` (the "Sent" label of each user message) and `thread`, `inspector` (the "Exit code 0" label of the terminal output). Variant: light. PNGs: `~/Library/Caches/AgentViewKit/screenshot-check/sign-in--light.png`, `banners--light.png`, `scrolled--light.png`, `thread--light.png`.
- Views: `UserMessageView.SendStateLabel` and `OutputExitLabel` (used by `TerminalView` and `CommandOutputView`).

What the image shows: the whole label, the caption text included, is drawn in `statusSucceeded`: RGB 34c759 on the light window background, a contrast of 2.2:1. That is far below the system secondary label color (RGB 808080, 3.9:1), which the kit uses for other secondary text. In dark the color is RGB 30d158, 8.2:1, so only the light variant is hard to read.

Files: `Sources/AgentViewKit/Items/UserMessageView.swift` (`SendStateLabel`), `Sources/AgentViewKit/Content/OutputChrome.swift` (`OutputExitLabel`).

What to change: put the status color on the symbol only, and draw the title in `.secondary`. Remove the cause in each of the two files: no `Label` that tints its text with a status role (`statusColor(for:)`).

Deterministic test: hosted tests render `SendStateLabel(state: .sent)` and the `OutputExitLabel` of exit code 0 with `ViewSnapshot.hostedPixels` in the light variant. In the accessibility frame of the text, with the frame of the symbol left out, no pixel is close to `statusSucceeded`; the frame of the symbol has such a pixel. No clock and no wait.
#avk-8