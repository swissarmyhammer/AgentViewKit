---
assignees:
- claude-code
depends_on:
- 01M5DF892NSFBA3B087C5MVVT4
position_column: todo
position_ordinal: 8a80
title: 'AVK-8c PermissionView: change the card from glass to the content surface'
---
## Why

D110 (b). A permission request card is content in the transcript (it shows in `RequestDeck`). Content has no glass. Only its action buttons can use the glass button styles.

## Files

- `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift` line 170: `.glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))`.
- Keep lines 321, 323, 325, 344 and 364: the option buttons, the comment Send button and the "switch to auto" button keep `.glassProminent` and `.glass`.

## What to do

- [ ] Replace line 170 with `agentContentSurface()` (AVK-8b).
- [ ] Do not change the button styles. "Allow once" stays the one `.glassProminent` action of the card.
- [ ] Do not change the focus, the Esc action or the accessibility identifiers.

## Acceptance

- `PermissionView.swift` has no `.glassEffect`.
- A test renders `PermissionView` with a code-built request over a backdrop of one unique color with `RenderedPixels`. No pixel of the backdrop color shows inside the card.
- All tests in `Tests/AgentViewKitTests/HumanInTheLoop/` pass.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event.

## Note

`RequestDeck.swift` has changes in the work tree from AVK-7d (^56y8q6a). This card does not change `RequestDeck.swift`. #avk-8