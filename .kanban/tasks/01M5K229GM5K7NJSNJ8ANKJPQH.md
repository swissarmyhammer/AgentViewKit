---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5k7nv3vwafx6e946c6n48q7
  text: |-
    Research: AttachmentView chose its scope corners statically (chip renderer -> AttachmentChip.corners, else .square). LoadStateView `.failed` shows AttachmentChip, whose own agentAttachmentScope is a no-op inside the view's scope (same segment), and `.scopeFocusRing` only flows down, so the fallback chip's ring stayed square. AsyncImage failure is async and not observable, so the hosted test needs a signal to wait on.

    Implementation: the shown surface reports its corners. New `AttachmentSurfaceCornersKey` (PreferenceKey, `AgentSurfaceCorners?`, first reported wins) in AttachmentView.swift; AttachmentChip sets it to `Self.corners`; AttachmentView reads it with `.onPreferenceChange` into `@State shownCorners` and passes `registered ? .square : shownCorners ?? .square` to `agentAttachmentScope`. Only the value changes, so view identity and state are kept. `AgentSurfaceCorners` gained `Equatable` (synthesized works for the `KeyPath & Sendable` payload), needed by onPreferenceChange. Radii come from the theme via AttachmentChip.corners (`\.m`).

    Test: `AttachmentFocusRingHostedTests.theFocusRingOfAPreviewThatShowsTheChipHasTheCornersOfTheChip` writes non-image text to chart.png, observes the key through an @Observable probe and `harness.render(when:)`, lands nav focus, and checks `expectFocusRingMask(cornerRadius: radii.m)`. RED seen first (mask == expected false, ring square) with the key emitted but not consumed; GREEN after AttachmentView consumed it. Extracted `focusScope(of:in:system:)` from inspectFocusedScope so both share the focus landing.
  timestamp: 2026-10-23T01:58:14.395779+00:00
- actor: claude-code
  id: 01m5k7p3nwjvsc6kvngk7padzh
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/Attachments/AttachmentView.swift, Sources/AgentViewKit/Attachments/AttachmentChip.swift, Sources/AgentViewKit/Commands/AgentItemScope.swift, Tests/AgentViewKitTests/Attachments/AttachmentFocusRingHostedTests.swift. New test RED then GREEN; full `swift test`: 1679 tests in 206 suites passed (4 known issues are pre-existing withKnownIssue), exit 0.
    - next: /review
  timestamp: 2026-10-23T01:58:23.164922+00:00
- actor: claude-code
  id: 01m5kvzavzv90t8epx2g6t1rh3
  text: |-
    ### test — stuck (tooling, not code)
    - evidence: the sah MCP server dropped (CONNECT_TIMEOUT); the tester had no shell and ran no `swift test`. No counts.
    - next: rerun the test step unchanged now that sah has reconnected (2026-10-23).
  timestamp: 2026-10-23T07:52:56.959676+00:00
- actor: claude-code
  id: 01m5kw8tfrw2r4re6p6vcryjvv
  text: |-
    ### test — green
    - evidence: `swift test` run twice back to back (changed Sources files touched first, so AgentViewKit recompiled). Run 1: 1679 tests in 206 suites passed, 0 failures, 0 skipped, 4 known issues. Run 2: 1679 tests in 206 suites passed, 0 failures, 0 skipped, 4 known issues. The 4 known issues are the same expected ones (SnapshotStoreTests, HostedLayoutExpectationsTests, ThemeHeightExpectationsTests, ComposerWindowUndoHostedTests). AttachmentFocusRingHostedTests passed. Only warning: the known SwiftPM mlx-swift "missing creator" notice; no project-code warnings.
    - next: review
  timestamp: 2026-10-23T07:58:07.864527+00:00
position_column: doing
position_ordinal: '8480'
title: Give an AttachmentView preview that falls back to the chip the chip's ring corners
---
Found while working ^ars99rn. `AttachmentView` now passes `AttachmentChip.corners` (theme `radii.m`) to its attachment scope when its default renderer is the chip, and `.square` for a preview (image, pdf, text, code, audio, movie) or a registered view. A preview that cannot load its file (`LoadStateView` `.failed`) shows `AttachmentChip` in its place, but the scope is the outer `AttachmentView` scope (the inner chip makes no second scope, and `.scopeFocusRing` flows down the environment only), so the beacon ring of that fallback chip stays square while the chip draws rounded `radii.m` corners.

- [x] Make the corners follow the load state, for example by lifting the load state of the preview so `AttachmentView` knows when the chip shows, or another mechanism that lets the shown surface pick the ring corners.
- [x] Hosted test: an `AttachmentView` of an image file that does not decode lands nav focus on the beacon and its `drawFocusRingMask()` matches `RoundedRectangle(cornerRadius: radii.m)` (reuse `AttachmentFocusRingHostedTests` and `AgentItemFocusRingHostedTests.expectFocusRingMask(of:cornerRadius:)`).

#avk-7