---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dfdzkz0g4e5nkq4sw76t22
  text: |-
    ### decision (testudoapp-4c, AVK-8 "Decisions for the plan") — this changes the card
    - Only one action is prominent at a time. While the agent runs, Stop is `.glassProminent` and Send is `.glass`. When the agent is idle, Send is `.glassProminent`.
    - Acceptance: a test shows the two states.
    - D108 and D109: each new control is an EditorKit command that the palette shows.
  timestamp: 2026-10-20T20:18:18.879042+00:00
depends_on:
- 01M5DF9SKZ4BRGBD6BFG5XY664
position_column: todo
position_ordinal: '9180'
title: 'AVK-8j Composer: make Send the one .glassProminent action'
---
## Why

D110 (c): `.glassProminent` is for one primary action of an area. Today the composer has two: Send (`DefaultPromptAccessory.swift` line 91) and Stop (line 107). Both show at the same time while the agent runs and the user can cancel.

## Files

- `Sources/AgentViewKit/Input/DefaultPromptAccessory.swift` line 107: Stop uses `.buttonStyle(.glassProminent)`.
- Keep line 91: Send keeps `.buttonStyle(.glassProminent)`.
- Update the DocC comment at line 8, which names the submit button style.

## What to do

- [ ] Change the Stop button to `.buttonStyle(.glass)`. Keep `.buttonBorderShape(.circle)`, the help text and the identifier `prompt-stop`.
- [ ] Update the DocC comment of `DefaultPromptAccessory` in STE: Send is the one prominent action.

## Acceptance

- `DefaultPromptAccessory.swift` has exactly one `.buttonStyle(.glassProminent)`, on the submit button.
- All tests in `Tests/AgentViewKitTests/Input/` pass. The tests that find `prompt-stop` and `prompt-submit` still find them.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest.

## Open question

While the agent runs, is Stop the primary action and not Send? If yes, the rule is "one prominent action at a time": Stop is prominent while it shows, and Send is not. This card uses the rule of the peer request: Send is always the one prominent action. #avk-8