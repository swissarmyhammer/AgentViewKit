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
- actor: claude-code
  id: 01m70cm3bxd73v8qqqpp2z9dfj
  text: |-
    ### review — findings
    - evidence: review sha 24139759..HEAD; 12 findings, 12 confirmed, 0 refuted. All are code-hygiene/magic-numbers-swift in ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:126, :133, :140, :147, :154, :161, :168, :175, :182, :189, :238, :391.
    - next: /implement to replace the magic numbers in StateGalleryFixtures.swift with named constants, then /review.

    ```
    step: review
    outcome: findings
    evidence: 12 findings — ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:126, :133, :140, :147, :154, :161, :168, :175, :182, :189, :238, :391
    task: ^crz4q29
    ```
  timestamp: 2026-11-09T14:50:29.629339+00:00
- actor: claude-code
  id: 01m70cmfyyqwc7vm2fzakagn8p
  text: |-
    ### finish iteration 1 — findings
    - implement: no-change — the card was checked against commits 5c84b3f0, 5b658782 and de013324
    - test: green — swift test 1075+50 pass; IntegrationTests 1046 pass (5 known issues); ScreenshotTests 33 pass
    - commit: a579d36b (card only)
    - review: findings — ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:126, :133, :140, :147, :154, :161, :168, :175, :182, :189, :238, :391 (code-hygiene/magic-numbers-swift)
  timestamp: 2026-11-09T14:50:42.526165+00:00
- actor: claude-code
  id: 01m70cq9nq8jq10jt9735d2v31
  text: 'Picked up the 12 code-hygiene/magic-numbers-swift findings. A local run of swiftlint no_magic_numbers (allowed_numbers [0, 1, -1, 100], as the rule states) on StateGalleryFixtures.swift gave exactly the 12 findings and no other literal: the `height:` literals of the ten subjects, `margin * 2` in the size of the image, and `ScrollToBottomPill(newItemCount: 3)`. The literals 340, 64 and 12 already have names as `static let`, so the rule does not report them. Fix: named, documented constants messageHeight, toolCallHeight, permissionHeight, oneLineHeight (the six subjects of one line share 60), diffHeight and verticalMarginCount in StateGalleryFixtures, and newItemCount in StateGalleryItems (the same name as in GlassSnapshotTests). The values do not change, so the images do not change. swiftlint now reports 0 findings on the file.'
  timestamp: 2026-11-09T14:52:14.391939+00:00
- actor: claude-code
  id: 01m70cyr7we5whj0gk3tsqqj3x
  text: |-
    ### implement — changed
    - evidence: 1 source file, ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift (7 named, documented constants; the values do not change). The 12 magic-numbers-swift findings are `- [x]`. swiftlint no_magic_numbers: 0 findings on the file. `swift test`: 1075 tests in 124 suites and 50 tests in 10 suites pass. `swift test --package-path IntegrationTests`: 1046 tests in 147 suites pass, with the 5 deliberate known issues of FontRoleExpectationsTests. `swift test --package-path ScreenshotTests`: 33 tests in 4 suites pass, and the run writes 40 states-* images. The only warning is the SwiftPM build-graph warning for mlx-swift_Cmlx.bundle.
    - next: /review
  timestamp: 2026-11-09T14:56:18.684971+00:00
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

## Review Findings (2026-11-09 08:48)

> Scope: `review sha 24139759..HEAD` — reviewed the diffs only — lines this change added or modified. 9 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at ScreenshotTests/Tests/ScreenshotTests/SelectionGalleryFixtures.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at ScreenshotTests/Tests/ScreenshotTests/SelectionGalleryFixtures.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at ScreenshotTests/Tests/ScreenshotTests/SelectionGalleryFixtures.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at ScreenshotTests/Tests/ScreenshotTests/SelectionGalleryFixtures.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at ScreenshotTests/Tests/ScreenshotTests/SelectionGalleryFixtures.swift, so its declarations are unread

- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:126` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:133` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:140` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:147` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:154` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:161` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:168` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:175` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:182` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:189` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:238` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `ScreenshotTests/Tests/ScreenshotTests/StateGalleryFixtures.swift:391` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
