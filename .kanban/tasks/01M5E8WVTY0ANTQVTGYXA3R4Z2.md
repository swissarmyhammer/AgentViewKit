---
assignees:
- claude-code
depends_on:
- 01M5DFBC5CXFEGX6P4XB316BQV
position_column: todo
position_ordinal: ac80
title: 'AVK-8ai SpeechInputButton: remove .foregroundStyle(.tint) on the recording symbol (SpeechInputButton.swift:85) and use .primary (D113 answer 5)'
---
## Why

D113 answer 5 and `style.md` "Tint": "Only the primary action of an area has a tint (for example Send, with `.glassProminent`). Other controls use `.primary` or `.secondary`, and no `.foregroundStyle(.tint)`." The dictation button is not the primary action.

## Files and lines

- `Sources/AgentViewKit/Input/SpeechInputButton.swift:83-85` (the listening symbol with `.foregroundStyle(.tint)`).
- Tests of the button in `Tests/AgentViewKitTests/Input/`.

## What to do

- [ ] Replace `.foregroundStyle(.tint)` with `.foregroundStyle(.primary)`. The variable value of the symbol (`variableValue: level`) still shows that the button listens.
- [ ] If a person cannot see the listening state without the tint, record this in a comment on AVK-8u (^8q34yt8) for the screenshot check. Do not add a tint.
- [ ] Search `Sources/AgentViewKit` for each other `.foregroundStyle(.tint)` and `.tint` shape style. Change each one that is not on the primary action. Record the list in a comment on this card.

## Acceptance

- No `.foregroundStyle(.tint)` in `Sources/AgentViewKit` (a structure test of AVK-8t holds this later).
- A unit test reads the foreground style of the listening label if the view tree permits it; otherwise the AVK-8t structure test is the acceptance. Record which one in the commit.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8