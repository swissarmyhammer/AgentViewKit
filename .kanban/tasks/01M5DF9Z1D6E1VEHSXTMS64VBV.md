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
- actor: claude-code
  id: 01m5dwfxyrt58z52jh1ba4ngpb
  text: |-
    ### research
    - Send and Stop are already EditorKit commands: `AgentCommandVerb.send` (`agent.send`) and `AgentCommandVerb.cancel` (`agent.cancel`) in `Sources/AgentViewKit/Commands/AgentCommands.swift`. The palette is `registry.eligible(path:).filter(\.isVisible)`. This card adds no new control, so D108 and D109 need no new command. A new test makes sure that the palette shows the two commands while the agent runs.
    - A render cannot show a glass button style (the window cache shows no glass). Thus the style comes from a testable internal value, and a source scan makes sure that each button uses that value.

    ### implementation
    - `DefaultPromptAccessory` has the internal types `Action` (`send`, `stop`) and `ActionStyle` (`glass`, `glassProminent`), and `static func style(of:for:)`. Stop is prominent while `SessionModel.isRunning` is true. At other times Send is prominent. The other action is `.glass`.
    - A `fileprivate` `View.actionStyle(_:)` helper applies `.buttonStyle(.glass)` or `.buttonStyle(.glassProminent)`. Each button calls `.actionStyle(Self.style(of: ..., for: session))`. Border shape, help text and identifiers did not change.
    - The DocC comment of `DefaultPromptAccessory` tells the two states in STE.
    - New tests: `Tests/AgentViewKitTests/Input/ComposerProminentActionTests.swift` (7 tests: running, idle, idle with a pending permission, no session, two source scans, the palette).
    - Note: the switch in `actionStyle(_:)` gives the button a new view identity when the agent starts or stops. The hosted tests of the buttons still pass.
  timestamp: 2026-10-21T00:06:34.200847+00:00
- actor: claude-code
  id: 01m5dwg03kq38w8fsw8jpz80t8
  text: |-
    ### implement — changed
    - evidence: 2 files — Sources/AgentViewKit/Input/DefaultPromptAccessory.swift, Tests/AgentViewKitTests/Input/ComposerProminentActionTests.swift (new). `swift test --filter ComposerProminentActionTests`: 7 tests passed. Full `swift test`: 1420 tests in 173 suites passed with 2 known issues (they existed before), plus 141 tests in 20 suites passed; only the mlx bundle warning (it existed before).
    - next: /review
  timestamp: 2026-10-21T00:06:36.403796+00:00
- actor: claude-code
  id: 01m5dwmbpt4qcxbzhxgszkazjw
  text: |-
    ### test - green
    - evidence: swift test - 1420 tests in 173 suites passed, 0 failed, 0 skipped, 2 known issues (before this change). The only warning is the mlx bundle build warning (before this change). No new warning.
    - next: review
  timestamp: 2026-10-21T00:08:59.354809+00:00
depends_on:
- 01M5DF9SKZ4BRGBD6BFG5XY664
position_column: doing
position_ordinal: '80'
title: 'AVK-8j Composer: make Send the one .glassProminent action'
---
## Why

D110 (c): `.glassProminent` is for one primary action of an area. Today the composer has two: Send (`DefaultPromptAccessory.swift` line 91) and Stop (line 107). Both show at the same time while the agent runs and the user can cancel.

## Files

- `Sources/AgentViewKit/Input/DefaultPromptAccessory.swift` line 107: Stop uses `.buttonStyle(.glassProminent)`.
- Keep line 91: Send keeps `.buttonStyle(.glassProminent)`.
- Update the DocC comment at line 8, which names the submit button style.

## What to do

- [x] Change the Stop button to `.buttonStyle(.glass)`. Keep `.buttonBorderShape(.circle)`, the help text and the identifier `prompt-stop`. (Changed by the decision of testudoapp-4c: Stop is `.glass` only while the agent is idle. While the agent runs, Stop is `.glassProminent` and Send is `.glass`.)
- [x] Update the DocC comment of `DefaultPromptAccessory` in STE: Send is the one prominent action. (Changed by the same decision: the comment tells the two states.)
- [x] A test shows the two states (decision of testudoapp-4c).

## Acceptance

- `DefaultPromptAccessory.swift` has exactly one `.buttonStyle(.glassProminent)`, on the submit button. (Changed by the decision: the one `.buttonStyle(.glassProminent)` and the one `.buttonStyle(.glass)` are in the `actionStyle(_:)` helper, which each button calls with `style(of:for:)`.)
- All tests in `Tests/AgentViewKitTests/Input/` pass. The tests that find `prompt-stop` and `prompt-submit` still find them.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest.

## Open question

While the agent runs, is Stop the primary action and not Send? If yes, the rule is "one prominent action at a time": Stop is prominent while it shows, and Send is not. This card uses the rule of the peer request: Send is always the one prominent action. (Answered by testudoapp-4c: one prominent action at a time. See the comments.) #avk-8