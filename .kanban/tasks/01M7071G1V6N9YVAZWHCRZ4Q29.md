---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: 'Gallery: normal, selected and focused states of each selectable view'
---
The user asks for normal, selected and focused images of each AVK view that has a selection look or a focus look (request from editorkit-9f, 2026-11-09).

## What to do
- For each view, write one gallery image. The image shows the columns Normal, Selected and Focused side by side, with the view name and the state as captions.
- Write each image in light and dark. Write a second image for a window that is not key.
- Use a real focus landing (`system.geometry.requestFocus(at:)`, as a `nav.*` move does). Do not use a fake flag.
- Views: message row, tool call card, permission card, attachment chip, attachment view, path chips, elicitation tab chips, DiffView chips, AgentRowList rows, a bar control (scroll pill).
- A view with no selection look or no focus look shows a caption that tells why.
- Replace the `item-focus-*` images of `SelectionGalleryFixtures`.

## Acceptance
- [ ] `swift test --package-path ScreenshotTests` passes and writes the `states-*` images.
- [ ] Unit and integration suites pass.