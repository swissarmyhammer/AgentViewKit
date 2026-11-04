---
assignees:
- claude-code
position_column: todo
position_ordinal: '8780'
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