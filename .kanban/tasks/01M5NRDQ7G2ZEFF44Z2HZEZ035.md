---
assignees:
- claude-code
position_column: todo
position_ordinal: b680
title: 'AgentViewKitDemo: mirror the agent commands into the main menu bar (EditorMenuCommands)'
---
Found while doing ^5nyqhzc. The demo app installs no `.commands { EditorMenuCommands(...) }` and no `NSMenuMirror` (no `.commands`, `CommandMenu`, `CommandGroup` or `CommandSystem(` in Examples/AgentViewKitDemo). So the demo's menu bar shows none of the agent verbs: not the Session menu, not the View rows, and not the new Edit-menu Copy Message (⌃⇧⌘C). The kit side is done and covered by AgentMainMenuHostedTests (NSMenuMirror); the demo host never wires it.

## What to do
- [ ] Give the demo scene one `CommandSystem` shared by its windows and `.commands { EditorMenuCommands(system, menuPaths: [.file, .edit, .view, .session]) }`.
- [ ] A UI test (holding the shared UI-test lock) that opens Edit with a message focused and sees Copy Message enabled next to Copy, and Session with Approve/Reject while a request waits. #avk-8