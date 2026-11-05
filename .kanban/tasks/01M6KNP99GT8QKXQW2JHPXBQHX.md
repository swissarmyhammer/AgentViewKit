---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6m9dd6tvx870hfj9thj9ygg
  text: |-
    Picked up (agent worktree branch worktree-agent-a40ae330ccd695e8b, base 0c32b23f). The "Blocked" line is obsolete: EK ^b6cqtr6 is on EK origin at 502db2be (EK main is now 51d9d7c7).

    Research:
    - EK `PathChip(path, kind:, line:, counts: PathChip.LineCounts?, action:)` in EditorSwiftUI; label = name (+counts via `EditorSwiftUIStrings.pathChipLabel`), value = path, help = path, fill radius = medium. No selection, no accessibility identifier: hosts add both.
    - Inspector `Field` with `Value == URL` is `.path` (read-only `PathChip`, folder symbol when `hasDirectoryPath`); `.opening` adds the action. No list-of-URL kind exists.
    - Grep of origin mains (KVK a87351a, SVK, Testudo; non-.kanban, tests included, no truncation):
      - KVK: only `ChipFlowLayout` (BoardTagRow). Testudo: nothing.
      - SVK: `DiffFileChip(file:hasPatch:isSelected:select:)` + `DiffFileChip.radius` (CheckpointFileSlot, ScreenshotTests SharedStyle), `DiffFileChip.symbolName(for:)` (Tests CheckpointFileContentTests), `DiffFileLabel(operation:path:counts:)` + `DiffFileLabel.Counts` (CheckpointFileRow, CheckpointFileContent, CheckpointFileContentTests), `ToolCallLocationChips(locations:)` + `.Location(path:line:identifier:)` (ScreenshotTests SharedStyle).
      - SVK `CheckpointFileDiff` / `CheckpointFileDiffContent` use neither DiffFileChip nor DiffFileLabel (only DiffContentView and EditorSymbol).
    - So DiffFileChip.swift and DiffFileLabel.swift cannot be deleted yet: they stay public, unchanged in shape, and AVK no longer shows them. `ToolCallLocationChip` (the single chip) is used by no other kit and is deleted.
  timestamp: 2026-11-04T22:03:31.418813+00:00
position_column: doing
position_ordinal: '8880'
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