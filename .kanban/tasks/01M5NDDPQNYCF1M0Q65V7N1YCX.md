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
position_column: doing
position_ordinal: '8380'
title: 'Snapshots: add AttachmentInspector images in Dark and Light'
---
Found while working ^bkhgxs5. That card asks to "re-record the AttachmentInspector snapshots in Dark and Light", but `Tests/AgentViewKitTests/Snapshots/__Snapshots__` has no AttachmentInspector images: `GlassSnapshotTests` and `HostedSnapshotTests` cover the thread, composer, bars, cards, code block, terminal and elicitation form only. ^bkhgxs5 kept to "re-record only the ones that change", so it recorded none.

## What to do
- [x] Decide whether the inspector should have snapshot coverage at all. Its preview is a live `QLPreviewView` (an out-of-process QuickLook view), so check whether its pixels are deterministic in `ViewSnapshot` before adding images.
- [x] If they are: add an `AttachmentInspector` case to `HostedSnapshotTests` over the four `SnapshotVariant`s (or Dark and Light only, as the requester asked), and list each new image by name.

#avk-8