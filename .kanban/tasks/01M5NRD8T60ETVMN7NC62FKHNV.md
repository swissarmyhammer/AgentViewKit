---
assignees:
- claude-code
position_column: todo
position_ordinal: b580
title: 'AgentKeymap: move the agent keys to the D137 kit key rule (StandardChords)'
---
Found while doing ^5nyqhzc. TestudoApp D137 (features/decisions.md) and EditorKit `StandardChords` (3bc9d3e) say each kit command uses Control-Command, and name the keys: Copy Thread ⌃⌘C, Jump to Previous/Next ⌃⌘↑/⌃⌘↓, previous/next Request ⌃⌘[/⌃⌘]. EditorKit's header says "`AgentKeymap` (AgentViewKit) and `BoardKeymap` (KanbanViewKit) use these constants and have no chord text of their own."

AgentKeymap at HEAD still binds the pre-D137 keys: Copy Thread ⇧⌘C, Next/Previous Prompt ⌥↓/⌥↑, Next/Previous Request ⇧⌘}/⇧⌘{. ^5nyqhzc gave Copy Message ⌃⇧⌘C (Control-Command plus Shift, so it stays clear of the ⌃⌘C that D137 gives Copy Thread).

## What to do
- [ ] Ask the user/Testudo to confirm the D137 move for AVK before changing keys (it changes shipped defaults).
- [ ] Make `AgentKeymap.defaultChords` read the `StandardChords` constants (copyItemAsText / previousItem / nextItem / previousWaiting / nextWaiting) and drop its own chord literals where a constant exists.
- [ ] Re-check Copy Message ⌃⇧⌘C against the new table.
- [ ] Update AgentKeymapKeyEventTests, AgentCommandsTests keymap table, and the AgentKeymap doc table. #avk-8