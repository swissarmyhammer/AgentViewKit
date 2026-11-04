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
position_column: doing
position_ordinal: '8680'
title: 'Adopt EditorKit one-value preview (^jn3qmmy): delete AVK''s single diff preview'
---
**Blocked** on EK card ^jn3qmmy (on EK origin at 2524005e). It lands EK's one-value preview kind (diff, file, image, code), harvested from AVK. editorkit-b5 sends the SHA. Don't start before then.

Boundary (user, 2026-11-04): the diff preview belongs to EK. The compound `DiffView` stays in AVK.

## What
- `swift package update` (all dependencies together) once the SHA lands.
- Delete AVK's `DiffContentView` and `EditorKitDiffRenderer` (Sources/AgentViewKitStyle/Diff/) where they are a single preview. Adopt EK's preview.
- Rebuild the compound `DiffView` in AVK on EK's preview.
- Update the docc pages.

## Acceptance Criteria
- [ ] No AVK copy of the single diff preview is left.
- [ ] `DiffView` and the attachment preview use EK's preview, with EK's theming.
- [ ] The review gallery shows the diff and attachment previews, light and dark.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.
- [ ] Diff preview tests move onto EK's API, or are dropped where EK covers them. Each dropped check is written on the card.