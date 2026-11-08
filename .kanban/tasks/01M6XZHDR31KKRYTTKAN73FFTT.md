---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6y42xg2epammmec8vr9kzxk
  text: |-
    Research and implementation notes:
    - The hosted bed shows the defect too. In a list that opens on a double click, `requestFocus(at:)` on the row path gives the first responder to the SwiftUI `KeyViewProxy` of the row. In a list that opens on a click (`.focusable(interactions: .activate)`), the beacon `GeometryProbeView` holds the first responder, so that row already showed the focused fill.
    - The system focus ring is visible in a window that is not key: SwiftUI adds one `_FocusRingView` subview for each focusable view whose focus effect is on. AppKit draws the ring only in a key window, but the view is there. `String(describing: type(of:))` gives `_FocusRingView`. `NSStringFromClass` gives `SwiftUI._FocusRingView`, so a compare with the short name fails with that call.
    - Fix: `AgentRowListRow` has `@FocusState isFocused`. `.focusEffectDisabled()` and `.focused($isFocused)` now stand after `AgentRowClicks` (around the `.focusable()`). The surface uses `.selectableSurface(isSelected, isFocused: isFocused, corners: .rounded(AgentRowListLayout.radius))`.
    - New shared test helper `IntegrationTests/.../Helpers/FocusLookBed.swift` (accent, reference fill, fill count, content layer count, system ring view, item focus check). `PermissionCardFocusLookHostedTests` now uses it, so the layer reads are not copied.
    - RED on old code: fill count 1 (expected 2); `_FocusRingView` present. GREEN after the fix.
    - ARCHITECTURE.md: the row is now named with the permission card as an item that takes the focus itself.
  timestamp: 2026-11-08T17:42:49.090972+00:00
- actor: claude-code
  id: 01m6y430w787w6xdavzepbgpb0
  text: |-
    ### implement — changed
    - evidence: Sources/AgentViewKit/Lists/AgentRowList.swift, IntegrationTests/Tests/IntegrationTests/Lists/AgentRowListFocusLookHostedTests.swift (new, 2 tests), IntegrationTests/Tests/IntegrationTests/Helpers/FocusLookBed.swift (new), IntegrationTests/Tests/IntegrationTests/HumanInTheLoop/PermissionCardFocusLookHostedTests.swift, ARCHITECTURE.md. `swift test`: 1075 + 50 tests pass. `swift test --package-path IntegrationTests`: 1041 tests pass, 5 known issues (FontRoleExpectationsTests). `swift test --package-path ScreenshotTests`: 33 tests pass. item-focus-row-{light,dark}.png: "Drafts" shows the stronger accent fill, no ring; "Inbox" the soft fill. item-focus-row-not-key-{light,dark}.png: "Drafts" and "Inbox" show the inactive grey, no ring.
    - next: /review
  timestamp: 2026-11-08T17:42:52.551955+00:00
position_column: doing
position_ordinal: '80'
title: 'AgentRowList: a focused row shows the system focus ring, not the focused fill'
---
Found during ^r3sm8nh (snapshot item-focus-row-light.png / -dark.png in ~/Library/Caches/AgentViewKit/screenshot-check/snapshots/HostedSnapshotTests/).

In a key window, a focused row of `AgentRowList` shows an outline (the system focus ring) and no fill. style.md "Selection and focus" says: an item with a surface shows the focused fill and never an outline.

Cause (checked in the settle of the snapshot): `AgentRowClicks` applies `.focusable()` (`.doubleClick`) or `.focusable(interactions: .activate)` (`.click`) to the row. `requestFocus(at:)` on the row path gives the first responder to the SwiftUI `KeyViewProxy` of the row, not to the beacon of the row scope. Thus the beacon `focusIndicator.holdsFocus` is false, `.selectableSurface` shows no focused fill, and SwiftUI draws its system focus ring: `.focusEffectDisabled()` stands inside `AgentRowClicks`, so it does not cover the `.focusable()`. The hosted tests did not see this: the harness window is never key, so no ring draws there, and `aFocusedRowShowsNoScopeRing` reads only the scope ring.

Same cause as the permission card (^ekc1mpb). EK card ^tmwpx2x adds a public `.selectableItem(isSelected:isFocused:radius:)`, which takes the focus of a focusable view.

To do:
- [x] After EK ^tmwpx2x is on main and pinned, give the row surface the focus of its focusable view (`@FocusState`), so the focused row shows the focused fill.
- [x] Hide the system focus ring of the row (`.focusEffectDisabled()` around the `.focusable()`).
- [x] Hosted test: a focused row shows the focused fill and no system focus ring.
- [x] Run ScreenshotTests and check item-focus-row and item-focus-row-not-key: the focused row "Drafts" shows the stronger accent fill (grey when not key).
