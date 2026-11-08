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
- actor: claude-code
  id: 01m6y4es6as22jzky9hxp2hn35
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD; 2 findings (2 confirmed, 0 refuted) — IntegrationTests/Tests/IntegrationTests/Helpers/FocusLookBed.swift:128, IntegrationTests/Tests/IntegrationTests/Helpers/FocusLookBed.swift:136
    - next: implement the 2 reuse/reuse findings (one generic depth-first helper for the layer walk and the view walk), then review again.
  timestamp: 2026-11-08T17:49:17.898161+00:00
- actor: claude-code
  id: 01m6y4fa89naq2gdbzetjbj9ey
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 5 files
    - test: green — swift test 1075+50; IntegrationTests 1041 (5 known); ScreenshotTests 33
    - commit: 7afe4a27
    - review: findings — IntegrationTests/Tests/IntegrationTests/Helpers/FocusLookBed.swift:128, IntegrationTests/Tests/IntegrationTests/Helpers/FocusLookBed.swift:136
  timestamp: 2026-11-08T17:49:35.369529+00:00
- actor: claude-code
  id: 01m6y4qa40h8gdzf64a2e6bket
  text: |-
    The two reuse findings are fixed. A new shared helper `DepthFirstWalk.nodes(from:children:)` is in IntegrationTests/Tests/IntegrationTests/Helpers/DepthFirstWalk.swift. It is a static func on an enum namespace, because the swift immutability rule does not permit a top-level func. FocusLookBed.layers(in:) uses it with `{ $0.sublayers ?? [] }`. FocusLookBed.holdsSystemFocusRing(in:) uses it with `\.subviews`. StatusBarReduceMotionHostedTests.layerClasses uses it and maps the layers to class names. The functions sublayers(of:), views(below:) and classNames(in:) are removed. A test of the order of the walk is in TestSupport/DepthFirstWalkTests.swift (RED: the type was missing; GREEN after the helper).

    Search: no other recursive sublayers/subviews walk is in IntegrationTests. ScreenshotTests is a different package and cannot reach the helper; it has no such walk. Sources/AgentViewKit/Input/PromptCaretProbe.swift has a lazy search for the first text view, which is production code and not a full walk, so it stays.
  timestamp: 2026-11-08T17:53:57.376145+00:00
- actor: claude-code
  id: 01m6y4qcjaxxvt119089dftvy5
  text: |-
    ### implement — changed
    - evidence: 4 files — IntegrationTests/Tests/IntegrationTests/Helpers/DepthFirstWalk.swift (new), IntegrationTests/Tests/IntegrationTests/TestSupport/DepthFirstWalkTests.swift (new), IntegrationTests/Tests/IntegrationTests/Helpers/FocusLookBed.swift, IntegrationTests/Tests/IntegrationTests/Style/StatusBarReduceMotionHostedTests.swift. `swift test --package-path IntegrationTests`: 1042 tests in 146 suites passed, 5 known issues (FontRoleExpectationsTests, deliberate).
    - next: review
  timestamp: 2026-11-08T17:53:59.882961+00:00
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

## Review Findings (2026-11-08 11:47)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 5 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file

- [x] `IntegrationTests/Tests/IntegrationTests/Helpers/FocusLookBed.swift:128` `reuse/reuse` — The new sublayers(of:) reimplements a depth-first walk of CALayer.sublayers that already exists in StatusBarReduceMotionHostedTests.classNames(in:). Both functions have the same recursive shape: the layer, then its sublayers flatMapped depth first. A second copy can drift from the first. Make one generic depth-first helper, for example func depthFirst<T>(_ root: T, children: (T) -> [T]) -> [T]. Use it for sublayers(of:) here and for classNames(in:) in StatusBarReduceMotionHostedTests, or move the helper to a shared test support file. Keep layers(in:) as the caller that passes CALayer.sublayers.
- [x] `IntegrationTests/Tests/IntegrationTests/Helpers/FocusLookBed.swift:136` `reuse/reuse` — The new views(below:) is a second depth-first walk, this time over NSView.subviews. It has the same shape as sublayers(of:) at line 128 in the same file. Two copies of one traversal pattern in one file duplicate the capability instead of extending one generic helper. Replace both with one generic depth-first helper that takes the child accessor, for example children: { $0.sublayers ?? [] } for layers and { $0.subviews } for views. The helper can be shared with the StatusBarReduceMotionHostedTests walk noted above.
