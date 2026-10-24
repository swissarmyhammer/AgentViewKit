---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5npq97n4jr3s5h245j9y65g
  text: |-
    Research and decision on the QuickLook preview:
    - The live `QLPreviewView` is NOT deterministic in `ViewSnapshot.hostedPixels`. Measured with a throwaway probe (inspector of `answer.swift`, 320x440 pt, light): a read right after the two render passes shows no preview, but with a settle that sleeps 1 s, 3 s or 6 s QuickLook has drawn an opaque preview with the file text, and 249,579 of 563,200 pixels differ (bbox x 60-579, y 229-708 px = the preview frame). QuickLook draws out of process and no event says when, so the zero-wait image is a race, and waiting on a timer is forbidden by `ViewSnapshot` ("Do not wait for a time").
    - No existing seam covers the inspector preview: `AttachmentPreviewLoader` (`\.attachmentPreviewLoader`) feeds `AttachmentPreview`, not the inspector, and `QuickLookPreview` is private with no injection point.
    - Smallest test-only seam chosen: `ViewSnapshot.hostedPixels(of:size:variant:hiding:settle:)` takes `hiding: [NSView.Type] = []` and hides every AppKit view of those classes right before the cache read, next to the existing `ScrollPocketProbe.hidePockets(in:)` step. No production code changes. `HostedSnapshotTests.verify` forwards `hiding:`. The inspector test passes `hiding: [QLPreviewView.self]`, so the preview row keeps its fixed 240 pt place and shows the backdrop through the row.
    - Proof of the stand-in: with the hide, the images after 0 s, 1 s and 3 s settles are byte-identical to the recorded references in light and dark (0 changed pixels, max delta 0).
    - Backdrop: `GlassSnapshotTests.overText` already filled images with text; I pulled that text into `GlassSnapshotTests.backdrop` (overText now uses it; the Glass images are unchanged and pass) and the inspector test puts the inspector in a ZStack over it, so the backdrop shows in the form margins, between sections, and through the translucent row fill.
    - Variants: Dark and Light only, as the title asks (`SnapshotFixtures.colorSchemeVariants`).
  timestamp: 2026-10-24T00:59:39.125581+00:00
- actor: claude-code
  id: 01m5npqh6c5r4gz9v08cwe697m
  text: |-
    Implementation landed (not committed). New reference images in Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/:
    - attachment-inspector-light.png (640x880 px, 320x440 pt @2x): light appearance. Text backdrop (GlassSnapshotTests.backdrop paragraphs) fills the image on the white window background. The grouped form has its system margins: first section holds the headline file name "answer.swift" and the row of five icon-only borderless actions (Open, Reveal in Finder, Share, Save, Quick Look); the second section is the 240 pt preview row with the QLPreviewView hidden, so the backdrop text shows through the translucent light-gray row fill. Backdrop text is visible in the margins, the gap between the sections, and below the form.
    - attachment-inspector-dark.png: the same layout in dark appearance (dark window background, dark row fill, light text).
    Determinism: recorded with AVK_SNAPSHOT_RECORD=1, then `swift test --filter HostedSnapshotTests/theAttachmentInspector` passed 3 runs in a row (both cases each run); a probe also showed 0 changed pixels after 0/1/3 s settles with the hide. Full `swift test` run twice: 1768 tests in 216 suites pass (7 known issues are the existing withKnownIssue meta-tests in SnapshotStoreTests, HostedLayoutExpectationsTests and FontRoleExpectationsTests) plus 229 tests in 31 suites. The only build warning is the existing SwiftPM "missing creator for mutated node ... mlx-swift_Cmlx.bundle" note from the mlx dependency.
    New unit test: ViewSnapshotHostedTests.theHostedImageShowsNoViewOfAHiddenType (failed to compile before the `hiding:` parameter existed, passes now).
  timestamp: 2026-10-24T00:59:47.276191+00:00
- actor: claude-code
  id: 01m5npqm0x3x98kmah4b99dc4z
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKitTestSupport/ViewSnapshot.swift, Tests/AgentViewKitTests/Snapshots/HostedSnapshotTests.swift, Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift, Tests/AgentViewKitTests/Snapshots/GlassSnapshotTests.swift, Tests/AgentViewKitTests/TestSupport/ViewSnapshotTests.swift, __Snapshots__/HostedSnapshotTests/attachment-inspector-light.png, __Snapshots__/HostedSnapshotTests/attachment-inspector-dark.png; `swift test` green (1768 + 229 tests); new snapshot test passed 3 consecutive runs after recording
    - next: /review
  timestamp: 2026-10-24T00:59:50.173656+00:00
- actor: claude-code
  id: 01m5nq25zb44k9gdmjxz0e4fm3
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (0294f92) — 1 finding (1 confirmed, 0 refuted): Sources/AgentViewKitTestSupport/ViewSnapshot.swift:81 reuse/reuse
    - next: implement the finding (fold hideViews and ScrollPocketProbe.hidePockets into one hide-by-class helper), then re-run review
  timestamp: 2026-10-24T01:05:36.235055+00:00
- actor: claude-code
  id: 01m5nq2m6y7j69qm33dsb8pw5p
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — attachment-inspector-{light,dark} snapshots; test-only `hiding:` on ViewSnapshot.hostedPixels; shared GlassSnapshotTests.backdrop; 7 files
    - test: green — swift test, 1768 tests in 216 suites passed, 0 failed, 0 skipped; HostedSnapshotTests 12/12 on 2 more runs
    - commit: 0294f92 (+ 4cae0c7, a kanban chore)
    - review: findings — Sources/AgentViewKitTestSupport/ViewSnapshot.swift:81 (reuse)
  timestamp: 2026-10-24T01:05:50.814575+00:00
- actor: claude-code
  id: 01m5nq5fpfh3313rdkfv90xrag
  text: |-
    Picked up the reuse finding (ViewSnapshot.swift `hideViews`). Research:
    - Both copies use the same match rule: `isKind(of:)` (exact class or subclass). `ViewSnapshot.hideViews` takes `[NSView.Type]`; `ScrollPocketProbe.pockets(in:)` takes the private class from `NSClassFromString("NSScrollPocket")` (an `AnyClass?`) and matches nothing when AppKit has no such class. So the shared helper takes `[AnyClass]`, and the probe passes an empty list when the class is missing - same effect.
    - `ScrollPocketProbe.pockets(in:)` is also used by `styles(of:)` over `scrollView.subviews` (direct children, not descendants), so the class-match predicate is shared too, not only the hide.
    - Rest of the module: every NSView walk already goes through `NSView.descendants` (HostedViewHarness+TextViews `firstEditableTextView`, `views(withAccessibilityIdentifier:)`, `views(of:)`). `HostedViewHarness.descendants(of:reading:)` walks the accessibility tree (NSObject children, depth-capped), a different tree, so it is not a copy. `views(of:)` is a typed `as? Found` filter that returns `[Found]`, not a hide. No other hide-by-class.
    - The swift `immutability` rule forbids top-level funcs ("A function belongs to a type"), and the module has none, so the helper is an internal NSView extension method in NSView+Descendants.swift rather than a free `hideViews(of:in:)`.
  timestamp: 2026-10-24T01:07:24.495412+00:00
- actor: claude-code
  id: 01m5nqd3p9z2ea1x1hq9mvmjkd
  text: |-
    Reuse finding fixed (not committed).
    - One shared helper in Sources/AgentViewKitTestSupport/NSView+Descendants.swift, internal to the module: `NSView.hideDescendants(of: [AnyClass])` (walks `descendants`, hides each match) on top of `NSView.isKind(ofAny: [AnyClass])` (the one class-match rule: `isKind(of:)`, exact class or subclass; empty list matches nothing). Named as an NSView method rather than a free `hideViews(of:in:)` because the swift `immutability` rule bans top-level funcs and the module has none.
    - `ViewSnapshot.hostedPixels` drops its private `hideViews` and calls `harness.hostingView.hideDescendants(of: hiddenTypes)` (`[NSView.Type]` upcasts to `[AnyClass]`).
    - `ScrollPocketProbe.hidePockets(in:)` is now `root.hideDescendants(of: pocketClasses)`; `pockets(in:)` (still used by `styles(of:)` over direct subviews) filters with `isKind(ofAny: pocketClasses)`. New `pocketClasses` gives `[NSClassFromString("NSScrollPocket")]` or `[]` when AppKit lacks the class, so the old "no class, no match" effect holds.
    - Match rules were already identical (both `isKind(of:)`), so nothing to reconcile.
    - Module-wide search: no other hide-by-class; every other NSView walk already uses `descendants`; `HostedViewHarness.descendants(of:reading:)` walks the accessibility tree (different tree), not a copy.
    - TDD: 3 new tests in NSViewDescendantsTests (now `@testable import`): failed to compile before (no `isKind(ofAny:)`/`hideDescendants(of:)`), pass after.
  timestamp: 2026-10-24T01:11:34.345696+00:00
- actor: claude-code
  id: 01m5nqdat64t2jemj85cqynw87
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKitTestSupport/NSView+Descendants.swift, Sources/AgentViewKitTestSupport/ScrollPocketProbe.swift, Sources/AgentViewKitTestSupport/ViewSnapshot.swift, Tests/AgentViewKitTests/TestSupport/NSViewDescendantsTests.swift; `swift test` (EditorKit 3bc9d3e) green: 229 tests in 31 suites + 1771 tests in 216 suites passed (7 known issues = existing withKnownIssue meta-tests), 0 failed; only warning is the existing mlx-swift_Cmlx.bundle SwiftPM note; no file under __Snapshots__ changed (git status)
    - next: /review
  timestamp: 2026-10-24T01:11:41.638117+00:00
position_column: doing
position_ordinal: '8380'
title: 'Snapshots: add AttachmentInspector images in Dark and Light'
---
Found while working ^bkhgxs5. That card asks to "re-record the AttachmentInspector snapshots in Dark and Light", but `Tests/AgentViewKitTests/Snapshots/__Snapshots__` has no AttachmentInspector images: `GlassSnapshotTests` and `HostedSnapshotTests` cover the thread, composer, bars, cards, code block, terminal and elicitation form only. ^bkhgxs5 kept to "re-record only the ones that change", so it recorded none.

## What to do
- [x] Decide whether the inspector should have snapshot coverage at all. Its preview is a live `QLPreviewView` (an out-of-process QuickLook view), so check whether its pixels are deterministic in `ViewSnapshot` before adding images.
- [x] If they are: add an `AttachmentInspector` case to `HostedSnapshotTests` over the four `SnapshotVariant`s (or Dark and Light only, as the requester asked), and list each new image by name.

#avk-8

## Review Findings (2026-10-23 20:04)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 4 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 2 file(s) not reviewed — the file holds no text to review:
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/attachment-inspector-dark.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/attachment-inspector-light.png` — not UTF-8 text, so there is nothing to review

- [x] `Sources/AgentViewKitTestSupport/ViewSnapshot.swift:81` `reuse/reuse` — `hideViews` reimplements the walk that `ScrollPocketProbe.hidePockets` already does: take `root.descendants`, keep the views whose class matches, and set `isHidden = true`. The new function is a generalization of that near-match, but it was written as a parallel copy instead of extending the existing one. Two copies of the same hide-by-class loop will drift apart, for example in how they handle the class lookup or the subclass check. Move the generic hide into one shared helper (`hideViews(of:in:)`, internal to the module) and have `ScrollPocketProbe.hidePockets(in:)` call it with the pocket class, or express `hidePockets` as `hideViews` over the pocket class. Keep the parameterized form as the single implementation.
