---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6kqq7e1cd5z8wtdp4h3aw22
  text: 'Sequencing (snapshotviewkit-45, 2026-11-04): SVK''s ChangesInspector imports AgentViewKitStyle for `SharedSymbol.changes` in its empty state. Before this card removes the SharedSymbol mapping, SVK has to move to EK''s symbols. Ask snapshotviewkit-45 for that SHA and push the removal only after it (no shims).'
  timestamp: 2026-11-04T16:54:18.817953+00:00
position_column: todo
position_ordinal: '8480'
title: 'Adopt EditorKit symbols (^j0562t1): delete AVK''s Symbols copies'
---
**Blocked** on EK card ^j0562t1 (on EK origin at 2524005e). It lands EK's harvest of the shared symbols. editorkit-b5 sends the SHA. Don't start before then.

Boundary (user, 2026-11-04): tag, file, symbols and status are generic atoms and belong in EK. EK holds single-value controls; compound views stay in AVK.

## What
- `swift package update` (all dependencies together) once the SHA lands.
- Delete AVK's copies in Sources/AgentViewKitStyle/Symbols/: `StatusSymbolImage.swift`, `LiveSymbolEffect.swift` and the tool/file symbol mapping in `SharedSymbol.swift`. Adopt EK's at every call site in AVK, the demo, IntegrationTests and ScreenshotTests.
- Update the docc pages that link the old symbols.

## Acceptance Criteria
- [ ] No AVK copy of the harvested symbol code is left.
- [ ] Every user in AVK uses EK's symbols, with EK's theming.
- [ ] The review gallery shows the symbol users, light and dark.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.
- [ ] Tests that checked AVK's symbol mapping move onto EK's API or are dropped where EK's own tests cover them. Each dropped check is written on the card.