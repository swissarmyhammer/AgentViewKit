---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6m0hdrp27p5fx7mmr795fx6
  text: |-
    Picked up (base 3b896707 cherry-picked as 33d8142a; packages updated in root, IntegrationTests, ScreenshotTests, then again for EK 0cbc4834 per coordinator). The Blocked line is obsolete: EK ^jn3qmmy is on origin at 8b13a962.

    Research:
    - SVK origin/main still uses AgentViewKitStyle's `DiffContentView` (CheckpointFileDiff), `EditorKitDiffRenderer` (the view in its ScreenshotTests, and `diff(of:file:)` / `line(of:)` in CheckpointFileDiffContent) and `.diffLayout(.inline)`. So DiffContentView, EditorKitDiffRenderer, DiffLayout and `\.diffLayout` STAY in AgentViewKitStyle, with no shim, and are listed for later removal. KVK uses none of them.
    - TestudoApp origin/main: InspectorAreaView shows `AttachmentInspector(attachment)` (host mode); TestudoUITestSupport/InspectorScreen.swift hard-codes "inspector-name" and "inspector-form". On EK's InspectorView the name row carries EK's scheme id (`inspection:<view>/object:<id>/name`), so Testudo's UI test needs the new id afterwards.
    - EK's `PreviewField` draws its diff with EK DiffView at default (inline) layout: `diffLayout` there is a copy modifier on DiffView, not an environment value, and PreviewValue.diff has no layout. So a DiffView built on PreviewField cannot show side by side. EK's preview is a fixed `previewHeight` (240) scrolling frame, so a diff in a tool call becomes 240 pt tall and scrolls.
    - EK InspectorView needs `AnyObject & Observable` objects; Attachment is a struct, so the inspector folds small @Observable Identifiable wrappers (the ToolToggleList pattern). Several objects with different `.file(url)` previews read Mixed.
  timestamp: 2026-11-04T19:28:25.878492+00:00
- actor: claude-code
  id: 01m6m2dzg0c42sfmbkbw5zdrw4
  text: |-
    ### implement — stuck
    - evidence: branch worktree-agent-af0599b4bf942a9b5, merged local main daa111f4 (merge 718845c8), EK 0cbc4834 in all three packages. Work is in the working tree, NOT committed: the commit condition (root `swift test` and IntegrationTests green) is not met.
      - `swift test --package-path IntegrationTests`: 942 tests in 124 suites passed (5 known issues), zero AVK warnings.
      - root `swift test`: 1 failure, `ViewValueLayoutTests.theStyleHasNoPaddingByte` — EK 8b13a962 added `EditorStyle.previewHeight` after the 1-byte `density`, so EditorStyle has 7 padding bytes (size 136). EK must reorder the field; this card may not edit EK. Every AVK branch on EK main hits it. All other root tests pass (949 + 68).
      - `swift test --package-path ScreenshotTests` (run once): failed in `HostedSnapshotTests.theThread` at `SnapshotFixtures.codeBlockModel` (`cache.contains(id)`), the first image of `recordSnapshots`, so no later image was written (attachment, diff and inspector images included). The thread fixture has no diff; the likely cause is main's thread-pin change af251ae6 (^6y6ydyb), not this card. Not rerun (one capture per batch).
    - files: Sources/AgentViewKitStyle/Diff/{UnreadablePatch.swift (new), EditorKitDiffRenderer.swift}, Sources/AgentViewKitStyle/AgentViewKitStyle.docc/AgentViewKitStyle.md; Sources/AgentViewKit/{Diff/DiffView.swift, Diff/DiffRendererSlot.swift, Attachments/AttachmentInspector.swift, AgentViewKitModule.swift, Resources/Localizable.xcstrings}; ARCHITECTURE.md, README.md; Tests/AgentViewKitStyleTests/DiffStyleTests.swift, Tests/AgentViewKitTests/{Diff/DiffPreviewSourceTests.swift, Attachments/AttachmentInspectionTests.swift, Infrastructure/ViewValueLayoutTests.swift}; IntegrationTests Attachments/{AttachmentInspectorRowsHostedTests.swift (new), AttachmentInspectorHostedTests, AttachmentInspectorFormHostedTests, AttachmentInspectorModeHostedTests, AttachmentCommandsHostedTests, AttachmentFocusHostedTests}, Diff/DiffRendererDefaultHostedTests; ScreenshotTests {InspectorGallery, SnapshotFixtures, HostedSnapshotTests, ReviewGalleryScreenTests}.
    - next: EK fixes the EditorStyle padding; someone checks the theThread gallery failure on clean main; then commit this tree, run the capture once, and review. Dropped/changed checks, kept types and follow-ups are in the description.
  timestamp: 2026-11-04T20:01:30.112587+00:00
- actor: claude-code
  id: 01m6m43w4wmrjzg5bdke4vmgrc
  text: |-
    ### implement — changed
    - evidence: branch worktree-agent-af0599b4bf942a9b5 at 90a51911 (41d506ab feat, acf691a5 merge of local main ffab978f, 90a51911 gallery fix). Deps: EK 4767505c, foundationmodelscodecontext pinned to ffa5a6652b417b7f4971248fe31bab5318beb2c5 in the three Package.resolved files. My ViewValueLayoutTests edit was dropped for main's identical-intent ffab978f. `swift test` 948 + 68 passed, zero AVK warnings. `swift test --package-path IntegrationTests` 943 tests in 124 suites passed (5 known issues). `swift test --package-path ScreenshotTests` 23 tests passed; it wrote diff, diff-unreadable and inspector-attachment-host-{narrow,wide}-{one,mixed} in Light and Dark.
    - gallery: `HostedSnapshotTests.theThread` passed on a throwaway worktree of clean main ffab978f (now removed). On this branch the failing step was the gallery's thread SCREEN: its diff edit came after the code-block reply, and the 240 pt preview pushed the code block out of the rows the pinned thread draws. The cause was this card; 90a51911 moves the edit above the reply.
    - next: /review. Not pushed or merged.
  timestamp: 2026-11-04T20:30:56.156151+00:00
- actor: claude-code
  id: 01m6nqz08zpqaeat09nvjts459
  text: 'User decision (2026-11-05): diffs are one-column unified. DiffView drops side-by-side, since it''s shown in inspectors that are generally too narrow for two columns. No EK request for a PreviewField layout setting.'
  timestamp: 2026-11-05T11:37:02.495396+00:00
- actor: claude-code
  id: 01m6nr0rnzyg0ddrysdbm3hxps
  text: 'User decision (2026-11-05): no fixed 240 pt diff box. Previews grow to their full content height and the inspector or thread scrolls: "scrolling in a little field is ass compared to scrolling the whole inspector." EK''s PreviewField always applies `.previewFrame()` (PreviewField.swift:71), so I''ve asked editorkit-b5 for intrinsic sizing on PreviewField, for diff and code/text and the inspector''s `.preview` row. This card holds until that SHA lands, then: update, use the intrinsic sizing in DiffView, tool calls and AttachmentInspector, re-capture, and drop any test that pinned the 240 pt height. Testudo waits on this card''s origin SHA for the AttachmentInspector id change.'
  timestamp: 2026-11-05T11:38:00.255481+00:00
- actor: claude-code
  id: 01m6ntvqsxcrspsat6y6m2ankk
  text: 'Waiting on EK ^sjjykvg''s origin SHA (coordinator, 2026-11-05). The user approved dropping side-by-side, and decided there is no fixed-height preview: diffs, code and text grow to their full content height and the thread or inspector scrolls. When the SHA lands: merge AVK origin main (symbols, status, path chip, SharedSymbol and ChipFlowLayout are gone; DiffFileLabel is on FileDiff.Operation); seed .build from the main checkout; `swift package update`, keeping the codecontext pin at ffa5a66 if it is still needed; drop the 240 pt assumptions (the DiffView, DiffRendererSlot and ARCHITECTURE docs say "at the preview height", SnapshotFixtures.diffHeight, and the reason given for 90a51911''s thread-screen reorder); add a hosted test that a diff in a tool call and in the inspector has no inner vertical scroll view (`scrollsAsOne`) and grows when its content grows; capture the gallery again; then commit. The AttachmentInspector QuickLook row keeps EK''s previewHeight. AVK has no `.inspectorPreviewFrame()` call left, because PreviewField frames the `.file` value itself.'
  timestamp: 2026-11-05T12:27:41.245486+00:00
- actor: claude-code
  id: 01m6p0wr9dwqgz1fd47wq0whmt
  text: |-
    ### implement — changed
    - evidence: branch worktree-agent-af0599b4bf942a9b5 at 8e852778 (864e4e83 merges AVK origin main a1fe3d0d). EK fca868d4 (^sjjykvg) in all three packages, no pins (codecontext resolves to 0bc7bddc). `swift test`: 980 + 54 passed, zero AVK warnings. `swift test --package-path IntegrationTests`: 951 tests in 125 suites passed (5 known issues), no AVK warnings. ScreenshotTests: 27 passed, run once; the gallery shows the content-sized diff in the thread and in `diff-*`, and the attachment one/Mixed images. The nested .build folders are deleted.
    - Content-sized diff: the docs no longer say "preview height" (DiffView, DiffRendererSlot, ARCHITECTURE, SnapshotFixtures.diffHeight, and the reason for the thread-screen order). New `DiffGrowthHostedTests`: a diff in a tool call (FrameRecorder) and in an inspector preview row (`InspectorDriver.frame(of:)`) scrolls as one with its host (`scrollsAsOne`) and grows while it shows when the model's patch grows. No mouse and no focus. Checked RED: with `.frame(height: 120)` on the preview, all three tool-call checks fail.
    - Deleted, after re-grepping KVK fa69244, SVK 2f84cf5 and TestudoApp 8dffa20 origin mains (no use): `DiffContentView`, `EditorKitDiffRenderer` (with `unreadablePatchIdentifier`), `DiffLayout`, `\.diffLayout`, `.diffLayout(_:)`, their docc entries and previews, `StylePreviewFixtures.unreadablePatch`, IntegrationTests `DiffContentViewTests`, and the style/hosted layout and renderer tests. The file-filter and parse-line checks moved to `DiffPreviewSourceTests` on `DiffView.diff(of:file:)`. `UnreadablePatch` moved into AgentViewKit (internal) together with its catalog string. No shims. Docs/decisions/diff-renderer.md is marked superseded in part.
    - Kept, because AVK uses them: `DiffSummary.parse(gitPatch:)` (`DiffView(patch:)` and the `DiffFileChip` preview) and the `diffRenderer` slot.
    - Noticed: the content-sized EK diff shows a text caret at the start of its first line in the captures (EK's read-only diff view).
    - next: /review.
  timestamp: 2026-11-05T14:13:05.965129+00:00
position_column: done
position_ordinal: ffffffa680
title: 'Adopt EditorKit one-value preview (^jn3qmmy): delete AVK''s single diff preview'
---
**Unblocked:** EK ^jn3qmmy (8b13a962) and ^sjjykvg (content-sized previews) are on EK origin. AVK builds on EK fca868d4.

Boundary (user, 2026-11-04): the diff preview belongs to EK. The compound `DiffView` stays in AVK. User decision (2026-11-05): diffs are one unified column (side by side dropped), and there is no fixed-height preview box. Diffs, code and text grow to their full content height, and the thread or inspector scrolls.

## What
- `swift package update` (all dependencies together) once the SHA lands.
- Delete AVK's `DiffContentView` and `EditorKitDiffRenderer` (Sources/AgentViewKitStyle/Diff/) where they are a single preview. Adopt EK's preview.
- Rebuild the compound `DiffView` in AVK on EK's preview.
- Update the docc pages.
- Also the waiting item of ^e4857xj: AttachmentInspector on EK's `InspectorView`, with a `.preview` row and EK action rows, in every AttachmentInspectorMode; its hosted tests on InspectorDriver; the attachment gallery images, several files showing Mixed, Light and Dark, about 240 pt and wide.
- (2026-11-05) Content-sized diffs: drop the 240 pt assumptions; add a hosted test that a diff in a tool call and in an inspector has no inner vertical scroll and grows live. Then delete `DiffContentView`, `EditorKitDiffRenderer`, `DiffLayout` and `\.diffLayout`, which no kit uses any more.

## Deleted (no kit uses them: KVK fa69244, SVK 2f84cf5, TestudoApp 8dffa20)
`DiffContentView`, `EditorKitDiffRenderer` (and `unreadablePatchIdentifier`), `DiffLayout`, `\.diffLayout`, `.diffLayout(_:)`, with their docc entries, previews and tests; AttachmentInspector's private QuickLookPreview. The file filter is now `DiffView.diff(of:file:)`. `UnreadablePatch` moved into AgentViewKit along with its string.
Kept because AVK uses them: `DiffSummary.parse(gitPatch:)` (`DiffView(patch:)` and the `DiffFileChip` preview) and the `diffRenderer` slot.

## Acceptance Criteria
- [x] No AVK copy of the single diff preview is left.
- [x] `DiffView` and the attachment preview use EK's preview, with EK's theming.
- [x] The review gallery shows the diff and attachment previews, light and dark.

## Tests
- [x] The full AVK test suite is green, with zero warnings in AVK targets.
- [x] Diff preview tests move onto EK's API, or are dropped where EK covers them. Each dropped check is written on the card.

## Dropped or changed checks
- `DiffRendererDefaultHostedTests`: the side-by-side columns test, the layout-setting tests and the file-filter tests are dropped. Side by side is gone by the user's decision; the file-filter and parse-line checks now live as unit tests in `DiffPreviewSourceTests` on `DiffView.diff(of:file:)`. The unreadable patch is read through `InspectorDriver.previewFailure(of: DiffView.previewIdentifier)`. `theInlineLayoutHasNoColumns` becomes `theDiffIsOneUnifiedColumn`.
- `DiffStyleTests`: the renderer and layout tests are dropped along with their types. IntegrationTests `DiffContentViewTests` is deleted along with its type.
- `AttachmentInspectorFormHostedTests.theContentOfTheInspectorIsAScrollingForm`: `inspector-form` stands on the InspectorView's group, so the check finds the scroll area under it.
- `AttachmentFocusHostedTests.aFocusableViewOfTheInspectorTakesTheFocusOfItsScope` becomes an `.inspector` case of `theBeaconOfTheScopeHoldsTheFocus`: EK's `InspectorView` never takes the focus itself.
- The attachment suites read EK's name row by its value (`AttachmentInspector.nameIdentifier(of:)`), and press the actions through `InspectorDriver.pressAction`.
- Gallery: the thread screen's diff edit stands above the code-block reply, because the full-height diff below the reply pushed the code block out of the rows the pinned thread draws.

## Follow-ups
- TestudoApp: `TestudoUITestSupport/InspectorScreen.swift` hard-codes `inspector-name`; the name row now carries EK's scheme id (`AttachmentInspector.nameIdentifier(of:)`). `inspector-form` is kept. (The coordinator relays this.)
- EK: the content-sized diff shows a text caret at the start of its first line in the gallery captures.