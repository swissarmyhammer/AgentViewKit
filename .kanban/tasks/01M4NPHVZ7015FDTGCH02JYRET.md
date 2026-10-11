---
assignees:
- claude-code
depends_on:
- 01M4NPHNFGP5JDZS02XHHE6BE3
position_column: todo
position_ordinal: '8280'
title: 'SF Symbols: add icons to the text-only action buttons'
---
## What
An audit on 2026-10-11 found action buttons with text only. Use `Label(_:systemImage:)` with the symbol table of the kit. Paths are below `Sources/AgentViewKit/`.

## Work
- [ ] Permission options: an icon from `option.kind` (for example a checkmark for allow, an xmark for reject) (`HumanInTheLoop/PermissionView.swift:301`). Also "Show Terminal" (`:236`).
- [ ] Diff hunk Accept and Reject (`Diff/DiffView.swift:345`, `:352`).
- [ ] Banner actions such as Retry and Reconnect (`Status/StatusBar.swift:51`).
- [ ] "Load More" (`Sessions/SessionListView.swift:202`), "Show all" (`Content/OutputChrome.swift:27`), the sign-in method buttons (`Connections/AgentAuthView.swift`), and the suggestion chips (`Input/SuggestionsView.swift:46`) where an icon helps.
- [ ] Hosted tests that find each button and its label.