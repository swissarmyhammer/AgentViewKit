---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: The row container of AgentRowList has the label of the row (Testudo)
---
Request from testudoapp-9a (2026-11-20), proven with a hosted accessibility snapshot in Testudo.

Now: the row element of `AgentRowList` (`agent-row-<list>/<id>`) is an AXGroup container (`children: .contain`, `AgentRowClicks`) with no label. The name of the row is only on its child element, for example "Idle, Session …, other · 1 hits". A label that the app sets with `wrappingRows` stays on the child. VoiceOver and XCUITest read the row as unnamed. The Testudo search and import UI tests read `row.label`.

Do:
- Give the row container the label of the row: the label that the app sets, or else the text of its content.
- Add a unit test, and a hosted test (compile only; the hosted suites are not run locally).
- Push when `swift test` passes, and send the sha to testudoapp-9a.