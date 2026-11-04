---
assignees:
- claude-code
position_column: doing
position_ordinal: '8580'
title: Adopt EditorKit number, date and duration (^d2fa1j4) for AVK's timing fields
---
**Blocked** on EK card ^d2fa1j4 (on EK origin at 2524005e). It lands EK's number, date/time and duration fields. editorkit-b5 sends the SHA. Don't start before then.

Boundary (user, 2026-11-04): single-value controls are EK's; compound views stay in AVK.

## What
- `swift package update` (all dependencies together) once the SHA lands.
- Survey AVK's timing fields (tool call timing such as start and duration, turn and session times, and any number or date formatting AVK does for one value). Replace each with EK's number, date/time or duration field. Delete AVK's own formatting and controls for them.

## Acceptance Criteria
- [ ] No AVK copy of a single number, date or duration control or formatter is left.
- [ ] Timing shows through EK's fields, with EK's theming.
- [ ] The review gallery shows the timing users, light and dark.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.
- [ ] Timing tests move onto EK's API, or are dropped where EK covers them. Each dropped check is written on the card.