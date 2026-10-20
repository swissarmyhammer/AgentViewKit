---
assignees:
- claude-code
position_column: todo
position_ordinal: '9980'
title: AVK-9 Hide the commands that are not available in the item context menus
---
Source: testudoapp-4c, TestudoApp card ^tt5k0r6. Rules D41, D109 and D44.

Rule: a command that is not available for the focus is disabled in the main menu. It does not show in a context menu.

Problem: `AgentItemScope` (Commands/AgentItemScope.swift) uses EditorKit `.commandContextMenu`. That modifier, and `contextMenuMirror(at:)`, show a row that is not available as a disabled (grey) row. Thus Next Prompt and Previous Prompt show grey in the context menu of a message row or a request card when they are not available.

Dependency: EditorKit must first get an option of `.commandContextMenu` (and of `contextMenuMirror(at:)`) that hides the rows that are not available. This change is in the EditorKit repo, not in this repo. Do not start this card before that option is on EditorKit main.

Do:
- Update the EditorKit pin to the commit that has the option.
- Use the option in `AgentItemScope`.

Acceptance:
- A headless test: at a message path where Next Prompt is not available, `contextMenuMirror(at:)` with the option does not contain Next Prompt.
- The same test: the main menu still shows Next Prompt as disabled.
- The AgentCommandPlacementTests still pass.
- No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-9