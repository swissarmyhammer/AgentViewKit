---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: 'AgentRowList: a focused row shows the system focus ring, not the focused fill'
---
Found during ^r3sm8nh (snapshot item-focus-row-light.png / -dark.png in ~/Library/Caches/AgentViewKit/screenshot-check/snapshots/HostedSnapshotTests/).

In a key window, a focused row of `AgentRowList` shows an outline (the system focus ring) and no fill. style.md "Selection and focus" says: an item with a surface shows the focused fill and never an outline.

Cause (checked in the settle of the snapshot): `AgentRowClicks` applies `.focusable()` (`.doubleClick`) or `.focusable(interactions: .activate)` (`.click`) to the row. `requestFocus(at:)` on the row path gives the first responder to the SwiftUI `KeyViewProxy` of the row, not to the beacon of the row scope. Thus the beacon `focusIndicator.holdsFocus` is false, `.selectableSurface` shows no focused fill, and SwiftUI draws its system focus ring: `.focusEffectDisabled()` stands inside `AgentRowClicks`, so it does not cover the `.focusable()`. The hosted tests did not see this: the harness window is never key, so no ring draws there, and `aFocusedRowShowsNoScopeRing` reads only the scope ring.

Same cause as the permission card (^ekc1mpb). EK card ^tmwpx2x adds a public `.selectableItem(isSelected:isFocused:radius:)`, which takes the focus of a focusable view.

To do:
- [ ] After EK ^tmwpx2x is on main and pinned, give the row surface the focus of its focusable view (`@FocusState`), so the focused row shows the focused fill.
- [ ] Hide the system focus ring of the row (`.focusEffectDisabled()` around the `.focusable()`).
- [ ] Hosted test: a focused row shows the focused fill and no system focus ring.
- [ ] Run ScreenshotTests and check item-focus-row and item-focus-row-not-key: the focused row "Drafts" shows the stronger accent fill (grey when not key).