---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5yd6s911k1aqsyqefrs9jvz
  text: |-
    ### finish iteration 1 — stuck
    - implement: not run. The card's precondition isn't met yet.
    - blocker: EditorKit ^tzh8q6d is in `review`, with its work on local branch `wip/leaf-scopes`. EditorKit ^wccq0y0 is in `todo`. EditorKit origin/main is still at be01754, so neither card has landed on main.
    - next: run /finish ^j4vnh1r when EditorKit sends the main SHAs for both cards. Then close ^bc6fapz.
  timestamp: 2026-10-27T10:06:31.201251+00:00
- actor: claude-code
  id: 01m5ydad75srwyhakssdy9tyxs
  text: |-
    ### Notes for implement from EditorKit (editorkit-a9, 2026-10-27)
    - ^tzh8q6d lands on EditorKit main (no branch). It adds JumpAction.press: focus, then the accessibility press. A Button runs once, a Toggle flips, a Picker or Menu opens. Space/Return presses again after a jump. nav.* only focuses. Disabled controls get no label and nav skips them.
    - A press landing happens only with an explicit `.targetable(true)`. `AgentControlScope` (Sources/AgentViewKit/Commands/AgentControlScope.swift:59) calls only `.commandScope(segment:)`, so it must add `.targetable(true)` to each bar control.
    - `ThreadBarControlJumpHostedTests.aJumpToEachBarControlLandsOnIt` will now run each control's action. A landing on Dismiss removes its banner, so the test must check the action, not a frame that stays put. Send must not send a real prompt unless the test says it should. Sign Out must not leave the session in a broken state.
    - Menu-opening landings are tested in EditorKit's new EditorCommandsUIMenuHostedTests target.
    - ^wccq0y0 (beacon AX hit test) comes after ^tzh8q6d, also on main.
  timestamp: 2026-10-27T10:08:29.925909+00:00
depends_on:
- 01M5SXEQEEADHVWS3A40XGGX44
position_column: todo
position_ordinal: 9f80
title: The thread bar controls are accessibility-hittable, and a landed jump activates them (after EditorKit ^tzh8q6d and ^wccq0y0)
---
Split from ^0xggx44 on 2026-10-25 (user: "get to it"). ^0xggx44 gives every control in the thread bars an EditorKit scope through one kit modifier. This card holds the items that need EditorKit work first.

Depends on two EditorKit cards (EditorKit board, not this one, so they are recorded here and not as `depends_on` links):
- ^tzh8q6d (01M5SXFGG14MB6JTQT1TZH8Q6D): leaf-control scopes. `.commandScope` + `.targetable` go directly on a Button, Toggle, Picker or Menu. A jump that lands on one ACTIVATES it like a click, through its own AX press action, so it honours `.disabled`. Focus also moves to it. `nav.*` only focuses it.
- ^wccq0y0 (01M5SXFR30JHWG1P7FGWCCQ0Y0): the scope beacon's `accessibilityHitTest` returns the SwiftUI element under the point.
Do not start until both commits are on EditorKit main. Record the SHAs when you start. Do not build landing or activation behaviour in AVK: EditorKit owns it.

Background: SwiftUI's AX hit test returns the transcript row under any view layered over a ScrollView (`.safeAreaBar`, `.overlay`, `.safeAreaInset`, `ZStack`). Minimal repro and the full analysis are in the comments of ^bc6fapz.

- [ ] Hosted tests: a landed jump on each bar control (Send, Stop, permission-mode picker, Sign in / Sign out, banner Dismiss / Reload / Show Error) activates it; a disabled control is not activated.
- [ ] Hosted tests: `window.accessibilityHitTest` at the centre of each bar control returns the control, not the row under the bar.
- [ ] Demo UI test: `testASendOfHelloShowsTheReplyOfTheAgent` asserts `editor.isHittable` and `submit.isHittable`, and the XCUI log has no "Falling back to element center point" for them.
- [ ] D113 scroll-under unchanged: the bar-edge hosted tests still pass.
- [ ] No compatibility shims; transparent backgrounds by default.

When this card is done, ^bc6fapz can close. #avk-8 #cross-repo