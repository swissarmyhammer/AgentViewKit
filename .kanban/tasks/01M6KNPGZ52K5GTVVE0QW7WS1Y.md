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
position_column: doing
position_ordinal: '8680'
title: 'Adopt EditorKit one-value preview (^jn3qmmy): delete AVK''s single diff preview'
---
**Unblocked:** the Blocked line is obsolete. EK ^jn3qmmy is on EK origin at 8b13a962. AVK builds on EK 4767505c (which also fixes the EditorStyle padding), with foundationmodelscodecontext pinned to ffa5a66 in the three gitignored Package.resolved files.

Boundary (user, 2026-11-04): the diff preview belongs to EK. The compound `DiffView` stays in AVK.

## What
- `swift package update` (all dependencies together) once the SHA lands.
- Delete AVK's `DiffContentView` and `EditorKitDiffRenderer` (Sources/AgentViewKitStyle/Diff/) where they are a single preview. Adopt EK's preview.
- Rebuild the compound `DiffView` in AVK on EK's preview.
- Update the docc pages.
- Also the waiting item of ^e4857xj: AttachmentInspector on EK's `InspectorView`, with a `.preview` row and EK action rows, in every AttachmentInspectorMode; its hosted tests on InspectorDriver; the attachment gallery images, several files showing Mixed, Light and Dark, about 240 pt and wide.

## Kept for later removal (a kit still uses them; no shim added)
SnapshotViewKit origin/main uses these, so they stay in AgentViewKitStyle until SVK moves to EK's `PreviewField`:
- `DiffContentView` — SVK `Sources/SnapshotViewKit/Files/CheckpointFileDiff.swift` (the diff and the note).
- `EditorKitDiffRenderer` — the view in SVK `ScreenshotTests/.../SnapshotViewKitReviewScreens+SharedStyle.swift`; `diff(of:file:)` and `line(of:)` in SVK `Sources/SnapshotViewKit/Files/CheckpointFileDiffContent.swift`.
- `DiffLayout`, `\.diffLayout`, `.diffLayout(_:)` — SVK's screenshot (`.diffLayout(.inline)`).
- AVK's own `DiffView` still calls `EditorKitDiffRenderer.diff(of:file:)` for the file filter; move that filter into `DiffView` when the type goes.
- AttachmentInspector's private QuickLookPreview is deleted (EK's `PreviewField` `.file` harvested it). KVK uses none of these.

## Acceptance Criteria
- [x] No AVK copy of the single diff preview is left in `DiffView` or the attachment inspector (the two kept Style types serve SVK only, listed above).
- [x] `DiffView` and the attachment preview use EK's preview, with EK's theming.
- [x] The review gallery shows the diff and attachment previews, light and dark.

## Tests
- [x] The full AVK test suite is green, with zero warnings in AVK targets.
- [x] Diff preview tests move onto EK's API, or are dropped where EK covers them. Each dropped check is written on the card.

## Dropped or changed checks
- `DiffRendererDefaultHostedTests.theSideBySideLayoutShowsTheEditorKitColumns` dropped: EK's `PreviewField` draws its diff inline only (`PreviewValue.diff` has no layout, and EK's `diffLayout` is a copy modifier on its DiffView, not an environment value), so `DiffView` no longer follows `\.diffLayout`. Follow-up below.
- `DiffRendererDefaultHostedTests.anUnreadablePatchShowsTheLineOfTheParseError` reads the preview failure through `InspectorDriver.previewFailure(of: DiffView.previewIdentifier)` instead of the `diff-patch-unreadable` note.
- `AttachmentInspectorFormHostedTests.theContentOfTheInspectorIsAScrollingForm`: `inspector-form` now stands on the InspectorView's group, so the check finds the scroll area under it instead of on it.
- `AttachmentFocusHostedTests.aFocusableViewOfTheInspectorTakesTheFocusOfItsScope` replaced by an `.inspector` case of `theBeaconOfTheScopeHoldsTheFocus`: EK's `InspectorView` never takes the focus itself, so the beacon of the attachment scope holds it.
- The name checks of the attachment suites read EK's name row (`AttachmentInspector.nameIdentifier(of:)`, the scheme id) by its value; the action presses go through `InspectorDriver.pressAction`.
- Gallery: the thread screen's diff edit now stands above the code-block reply. The 240 pt preview below the reply pushed the code block out of the rows the pinned thread draws (`SnapshotFixtures.codeBlockModel`, `cache.contains(id)`).

## Follow-ups
- EK: a layout for the diff of `PreviewField` (inline / side by side), so `DiffView` can follow `\.diffLayout` again.
- TestudoApp: `TestudoUITestSupport/InspectorScreen.swift` hard-codes `inspector-name`; the name row now carries EK's scheme id (`AttachmentInspector.nameIdentifier(of:)`). `inspector-form` is kept.