---
assignees:
- claude-code
position_column: todo
position_ordinal: '8580'
title: 'Adopt EditorKit path/file chip (^b6cqtr6): delete AVK''s file chips'
---
**Blocked** on EK card ^b6cqtr6 (on EK origin at 2524005e). It lands EK's path/file chip, harvested from AVK. editorkit-b5 sends the SHA. Don't start before then.

Boundary (user, 2026-11-04): file and tag chips are generic atoms in EK; compound views stay in AVK.

## What
- `swift package update` (all dependencies together) once the SHA lands.
- Delete AVK's `DiffFileChip` and `DiffFileLabel` (Sources/AgentViewKitStyle/Diff/) and `ToolCallLocationChips` (Sources/AgentViewKitStyle/Chips/). Adopt EK's path/file chip at every call site.
- `AttachmentChips` (Sources/AgentViewKit/Input/AttachmentChips.swift): if EK's card took it as the same chip, delete it and adopt EK's; otherwise keep it as an AVK compound view built on EK's chip, and write the reason on the card.
- Update the docc pages.

## Acceptance Criteria
- [ ] No AVK copy of the harvested chips is left.
- [ ] Diff headers, tool call locations and attachments use EK's chip, with EK's theming.
- [ ] The review gallery shows each chip user, light and dark.

## Tests
- [ ] The full AVK test suite is green, with zero warnings in AVK targets.
- [ ] Chip tests move onto EK's API, or are dropped where EK covers them. Each dropped check is written on the card.