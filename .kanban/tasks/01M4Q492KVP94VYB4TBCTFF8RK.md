---
assignees:
- claude-code
position_column: todo
position_ordinal: 8d80
title: Use editorFont for the code text of PermissionView and ElicitationURLConsentView
---
## What
Two kit views show code text in a fixed system monospaced font, not in the `editorFont` role of the EditorKit theme:
- `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift`: the command uses `.font(.body.monospaced())` and the working directory uses `.font(.caption.monospaced())`.
- `Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift`: the URL uses `.font(.callout.monospaced())`.

The owner decision (the EditorKit theme is the one theme of the kit) says that each font comes from the EditorKit theme. Other views (TerminalView, CommandOutputView, ErrorView, JSONDisclosure, EntryTimingView) already use `editorTheme.editorFont`.

Found during ^bg7j0hc.

## Work
- [ ] Decide the size rule: `editorFont` has one size (body). The caption and callout sizes need a decision, for example `editorFont` with no size change, or a rule in the decision record.
- [ ] Change the three fonts to come from `editorTheme.editorFont`.
- [ ] Hosted test with a theme whose `editorFont` is distinct (as in ProseFontHostedTests).
- [ ] Add a scan test, if useful, that no kit view uses `.monospaced()` for code text.