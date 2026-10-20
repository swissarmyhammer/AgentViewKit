---
assignees:
- claude-code
position_column: todo
position_ordinal: 8f80
title: 'AVK-8h Remove the glass button style from buttons in content: Load Earlier, message actions, attachment actions'
---
## Why

D110 (b), (c). Glass is only for floating controls and for the action buttons of request cards. These buttons are in content rows or in the inspector, which is system glass. A glass button in the inspector is glass on glass.

## Files

- `Sources/AgentViewKit/Thread/ConversationView.swift` line 296: the Load Earlier row uses `.buttonStyle(.glass)`.
- `Sources/AgentViewKit/Items/MessageActions.swift` line 153: the action row of a message uses `.buttonStyle(.glass)`.
- `Sources/AgentViewKit/Attachments/AttachmentActions.swift` line 77: the attachment actions use `.buttonStyle(.glass)`. Users: `Attachments/ArtifactView.swift:50` (content) and `Attachments/AttachmentInspector.swift:126` (inspector).

## What to do

- [ ] Load Earlier: use `.buttonStyle(.bordered)`.
- [ ] Message actions: use `.buttonStyle(.borderless)`. Keep `.foregroundStyle(.secondary)` (a vibrant style).
- [ ] Attachment actions: use `.buttonStyle(.borderless)`.
- [ ] Do not change labels, help text, identifiers or actions.

## Acceptance

- The three files have no `.buttonStyle(.glass)` and no `.buttonStyle(.glassProminent)`.
- All tests in `Tests/AgentViewKitTests/Thread/`, `Items/` and `Attachments/` pass. The tests that find these buttons by identifier still find them.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest.

## Open question

`comparison.md` line 365 and 732 describe a future floating glass hover bar for message actions. If a message action bar floats over the transcript later, it becomes a floating control and can use glass. This card covers only the row as it is today. #avk-8