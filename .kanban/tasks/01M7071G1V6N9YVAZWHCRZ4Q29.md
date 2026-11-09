---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m70cfftpx3nr3g1k9d6t6mke
  text: 'Check of the card against commits 5c84b3f0, 5b658782 and de013324. Each "What to do" item is in the code of StateGalleryFixtures.swift. The ten views, the three columns with captions, light and dark, the not-key image, the real focus landing with requestFocus(at:), and the notes for a missing look are all there. SelectionGalleryFixtures.swift and the item-focus-* images are gone. The run writes 40 states-* images in ~/Library/Caches/AgentViewKit/screenshot-check/generated/HostedSnapshotTests/. In states-message-light.png the focus ring goes around the whole row, with the send state. No code change was necessary. Note: `swift test` shows one SwiftPM build-graph warning, "missing creator for mutated node" for mlx-swift_Cmlx.bundle. It is not a compiler warning of this package.'
  timestamp: 2026-11-09T14:47:58.550783+00:00
- actor: claude-code
  id: 01m70cfj4jvb0pqyjj787zhnf6
  text: |-
    ### implement — no-change
    - evidence: no source change; description updated. swift test: 1075 tests in 124 suites and 50 tests in 10 suites pass. swift test --package-path IntegrationTests: 1046 tests in 147 suites pass with the 5 known issues of FontRoleExpectationsTests. swift test --package-path ScreenshotTests: 33 tests in 4 suites pass, and they write 40 states-* images.
    - next: /review
  timestamp: 2026-11-09T14:48:00.914705+00:00
position_column: doing
position_ordinal: '80'
title: 'Gallery: normal, selected and focused states of each selectable view'
---
The user asks for normal, selected and focused images of each AVK view that has a selection look or a focus look (request from editorkit-9f, 2026-11-09).

## What was done
- `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift` writes one gallery image for each view. The image has the title of the view, and the columns Normal, Selected and Focused side by side, each with its caption.
- Each view has an image in light and in dark, and a second image (`-not-key`) for a window that is not key (`\.appearsActive` is `false`).
- Each column has its own command system. The settle step lands the focus with `system.geometry.requestFocus(at:)`, as a `nav.*` move does. There is no fake flag.
- The views are: message row, tool call card, permission card, attachment chip, attachment view, path chip, elicitation tab chip, DiffView chips, AgentRowList row and a bar control (scroll pill).
- A column of a view with no selection look or no focus look shows a note that tells why.
- `SelectionGalleryFixtures.swift` and its `item-focus-*` images are removed. The test `theNormalTheSelectedAndTheFocusedStateOfEachView` in `HostedSnapshotTests.swift` writes the `states-*` images.
- `AgentItemScope` uses `.targetable(_:asksForLeafLanding:)` with `false`, so the ring of a focused item is the thin band of an item, not the band of a control.
- `TranscriptMessageView` has an accessory below the message inside the item scope. `UserMessageView` puts its send state there, so the focus ring goes around the whole row.
- Commits: 5c84b3f0, 5b658782, de013324.

## Acceptance
- [x] `swift test --package-path ScreenshotTests` passes and writes the `states-*` images.
- [x] Unit and integration suites pass.
