---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: AgentRowList takes Return and Escape from a text field in a row (rename, D197 b)
---
Bug report from testudoapp-9a (2026-11-19, TestudoApp UI test run; result bundles /Users/wballard/github/swissarmyhammer/TestudoApp/.build/app/OpenTestudo-sel2.xcresult and OpenTestudo-dbg.xcresult).

Now: the rows of `AgentRowList` can take the keyboard focus. `AgentRowListKeys` (Sources/AgentViewKit/.../AgentRowListCommands.swift:339-353) sends each key to the command registry before a text field in the row gets it. Return runs `agentRowList.open`, and Escape runs `nav.drillOut`. Thus the borderless EditorKit rename field of the app in a row never commits or cancels.

Do:
- The list must not take keys while a text field in a row is in edit (the first responder is a text view or field in the row, or an EditorKit field). Return, Escape, the arrows and the type-to-select keys then go to the field.
- When the edit ends, the list takes its keys again.
- TDD unit test (no window if possible): with a field in edit in a row, Return and Escape do not run `agentRowList.open` or `nav.drillOut`; with no field in edit they run as now.
- A hosted test of a rename in a row: compile only, do not run.

Run `swift test`. Push, and send the sha to testudoapp-9a.