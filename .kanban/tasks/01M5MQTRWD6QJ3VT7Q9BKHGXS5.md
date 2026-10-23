---
assignees:
- claude-code
position_column: todo
position_ordinal: af80
title: 'AttachmentInspector: system grouped Form layout (Xcode / Icon Composer inspector look)'
---
Requested by testudoapp-2c (2026-10-23) for Testudo card ^5pzcse2. The user said: "the inspector padding looks off to me, like inconsistent and too 'touching' the surrounding edge. the inspectors in xcode and icon composer look nice, use them for inspiration".

Today `AttachmentInspector` (Sources/AgentViewKit/Attachments/AttachmentInspector.swift:190, :200) uses a `VStack(spacing: theme.spacing.m)` padded with `theme.spacing.m` (12 pt). Testudo's PlaceholderInspector uses `.padding()`, and its pane header uses 4 pt, so the inspector column has three different insets. Testudo is moving PlaceholderInspector to a grouped Form and aligning its header to the same content edge.

## What to do
- [ ] The body becomes `Form { Section { name row, actions } … }` with `.formStyle(.grouped)`. It uses the system margins and has no hand-tuned padding: remove the `theme.spacing.m` padding and stack spacing.
- [ ] The QuickLook preview sits inside the form, with the same leading and trailing inset as the section content.
- [ ] Keep `nameIdentifier` and the action accessibility identifiers unchanged, so the Testudo UI tests still pass.
- [ ] One view, no host glue: hosts change nothing.
- [ ] Check the safe-area padding behavior described in the doc comment at AttachmentInspector.swift:65–88 still holds, or update that comment.

## Tests
- Hosted test: the inspector's content is a grouped Form; the preview's leading and trailing edges match the section rows.
- The identifiers resolve: `nameIdentifier` and each action.
- Re-record the AttachmentInspector snapshots in Dark and Light, and list them by name.
- Full `swift test` green; the demo builds.

When it's done, send testudoapp-2c the card id and the SHA. #avk-8 #testudo-request