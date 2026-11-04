---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6kqq7e1cd5z8wtdp4h3aw22
  text: 'Sequencing (snapshotviewkit-45, 2026-11-04): SVK''s ChangesInspector imports AgentViewKitStyle for `SharedSymbol.changes` in its empty state. Before this card removes the SharedSymbol mapping, SVK has to move to EK''s symbols. Ask snapshotviewkit-45 for that SHA and push the removal only after it (no shims).'
  timestamp: 2026-11-04T16:54:18.817953+00:00
- actor: claude-code
  id: 01m6kvc39c51yd0df8pztcw4c0
  text: 'Bug in AVK''s copy, found by EK''s ^j0562t1 hosted test (editorkit-b5, 2026-11-04): under Reduce Motion, `LiveSymbolEffect` keeps animating on macOS 27 even with `.symbolEffectsRemoved`, because the symbol animates on its own drawing layer. EK''s version also turns the effect off. Adopting EK''s fixes it. Add a hosted check that the effect is off under Reduce Motion. ^j0562t1 is in review; editorkit-b5 sends its SHA.'
  timestamp: 2026-11-04T17:58:08.428894+00:00
- actor: claude-code
  id: 01m6kw633zv0nhh2rw9ht0ej9k
  text: |-
    Unblocked: EK ^j0562t1 is on origin at dccf5daf (editorkit-b5, 2026-11-04). `swift package update` all deps together. Everything is in EditorSwiftUI and colored from the theme's status and severity tokens.
    - `EditorSymbol`: 33 cases (11 tool kinds, 8 file kinds, 8 statuses, 6 checkpoint triggers), each with an SF Symbol and a tone. `ToolKind(toolNamed:)` applies the tool-name rule; there's a mapping from `ItemStatus`.
    - `EditorSymbolImage(_ symbol:)` draws in the theme token; a stateless symbol uses `\.placedSecondary`. Another initializer takes a symbol name and a tone.
    - `LiveSymbolEffect` turns its effect fully off under Reduce Motion, which fixes the bug in AVK's copy.
    Delete AgentViewKitStyle/Symbols (StatusSymbolImage, LiveSymbolEffect, the tool/file mapping in SharedSymbol) and adopt these.
    Push sequencing (no shims): grep KVK, SVK and Testudo origin mains for StatusSymbolImage, LiveSymbolEffect and SharedSymbol before pushing the removal. SVK's ChangesInspector uses `SharedSymbol.changes` (SVK card ^4pb2kay). Wait for every consumer's SHA.
    Order: runs after the inspector card ^e4857xj's current iteration (finish is one task at a time).
  timestamp: 2026-11-04T18:12:20.223783+00:00
- actor: claude-code
  id: 01m6kxyjgrpxa0d1tq21ft3msc
  text: |-
    LiveSymbolEffect was removed early, under ^e4857xj, because EK dccf5daf (^j0562t1) shipped its own `liveSymbolEffect(isActive:)` and the two clashed ("ambiguous use" in AgentViewKitStyle). The orchestrator checked KVK 701a93d, SVK be738d5 and TestudoApp d2841fc first, and none of them uses it.
    - Deleted `Sources/AgentViewKitStyle/Symbols/LiveSymbolEffect.swift` (the struct, the View modifier and its #Preview).
    - The callers now use EK's `EditorSwiftUI` `liveSymbolEffect(isActive:)`: ToolCallView statusGlyph, TaskListView and StatusBar. IntegrationTests Style/StatusBarTests imports EditorSwiftUI.
    - Updated the DocC page (AgentViewKitStyle.md), ARCHITECTURE.md and the doc comments in StatusBar and ToolCallView.
    - So the Reduce Motion fix is in: EK's effect turns off `isActive` under Reduce Motion as well as removing the effects.
    - StatusSymbolImage and SharedSymbol stay. The rest of this card is still open.
  timestamp: 2026-11-04T18:43:11.000763+00:00
position_column: doing
position_ordinal: '8280'
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