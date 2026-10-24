---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5pk11djd4m0hwy72zz8n0zp
  text: 'Correction to the description: plan.md now gives the decision in the first sentences of "Button styles first" and "Tint and accent", and in "Three actions, always available". The rest of the "Button styles first" item and of the "Tint and accent" item still gives the earlier prominent styles. When this card changes the code, also change that text so that plan.md and the code agree.'
  timestamp: 2026-10-24T09:14:18.930537+00:00
position_column: todo
position_ordinal: a080
title: Use plain glass and bordered styles for Send, Stop, Submit and the request actions (accent only for selection and focus)
---
User decision (2026-10-24, relayed by kanbanviewkit-84), shared style rule 2, strict: the accent is only for the selection and the focus. A prominent button style gives the accent tint, so the kit uses no prominent button style.

To do:
- Send and Stop of the composer use `.glass`, not `.glassProminent` (`DefaultPromptAccessory.style(of:for:)`).
- `RequestDeckPlace.style(of:)` and `requestActionStyle(_:)`: the primary action uses `.glass` in content and in a bar with no glass, and `.bordered` on the deck glass in a bar. No `.glassProminent` and no `.borderedProminent`.
- The Submit action of an elicitation card uses the same place style (plan.md "Three actions, always available").
- Keep the primary action clear without a tint: it is the default action (`.keyboardShortcut(.defaultAction)` where it is the default today), and it keeps its order in the row.
- Update `GlassPlacementTests` (no `.glassProminent` line in `Input/`), `RequestDeckSurfaceTests` (the style of each action in each place), and add to `ThemeInjectionTests` a form that forbids `.glassProminent` and `.borderedProminent` in the kit, the demo support and the demo.
- plan.md "Button styles first" and "Tint and accent" already state the decision; keep the text and the code the same.

Acceptance:
- No `.glassProminent` and no `.borderedProminent` in Sources/ or the demo; a structure test checks it.
- `swift test` is green, and the demo builds.
- Re-record only the snapshots whose look changes (for example `bottom-bar-buttons-*.png`), listed by name with their PNG paths. #avk-8