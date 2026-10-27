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
- actor: claude-code
  id: 01m5yw1qrwbzgwreta9tf1dekx
  text: |-
    ### implement: findings (2026-10-27)
    EditorKit SHAs at start: ^tzh8q6d ca8dc21, ^wccq0y0 114592d. `swift package update EditorKit` resolved to 2906f93 (descends from 114592d). AVK builds and the bar tests pass on it with no source change, so the bump needs no fix.

    Measured with `.targetable(true)` added to `AgentControlScope` (exploration only, now reverted). `window.accessibilityHitTest` at the centre of each control's scope, in `ThreadBarControlJumpHostedTests`' host:
    - Wins: Dismiss and Reload (top bar), the editor, and the picker (it answers the middle segment, an `AXRadioButton`).
    - Loses: Send, Stop, Sign In, Sign Out, dictation, the suggestion chip and Remove Attachment all answer the `HostingScrollView` (AXScrollArea). Show Error answers `conversation-list`. The scroll pill answers a transcript row.
    - Effect: the EditorKit leaf read finds no control under those centres. So a landing on them only focuses and does not press, and a disabled Send still gets a jump label (`aJumpLabelShowsOnEachBarControl(send)` passes with empty text).
    - Also seen: with the change, `aJumpToEachBarControlLandsOnIt(send)` failed `jump.commit` in one run. In another run a disabled Send was a candidate. So the disabled read is not stable for this control.

    Cause, in part: AVK's own accessibility container. I removed `.accessibilityElement(children: .contain)` from `AgentThreadView.floatingControls` (exploration, reverted). After that Send, Stop, mic and the pill win the hit test. Sign In, Sign Out, Show Error, the suggestion chip and Remove Attachment still lose. Each of those sits in a further container or a nested scroll view (AgentAuthView, StatusBar `.contain`, SuggestionsView, AttachmentChips). EditorKit's docs already say a leaf in a container keeps the container's place in VoiceOver order, so it loses to the scroll view.

    The plain repro does NOT trigger it. All of these win: ScrollView+LazyVStack with a `.safeAreaBar(edge: .bottom)` holding a Button `.commandScope(...).targetable(true)` bare, in an HStack, in a VStack+HStack with `.accessibilityElement(children: .contain)`, in a GlassEffectContainer, or under a nested inner safeAreaBar. The smallest trigger found so far is AVK's real `floatingControls` (FloatingGlassContainer, then VStack with `.overlay`, then `.padding`, `.accessibilityElement(children: .contain)` and `.accessibilityIdentifier`). It has not been cut down further.

    Other blockers:
    - EditorTestSupport is a plain `.target` in EditorKit's Package.swift, not a `.library` product. AVK cannot import `accessibilityHitTest(at:window:)`, `accessibilityHitTest(atCenterOfScopeAt:in:window:)` or `expectLeafControlWinsTheHitTest`. Coordinator rule: no AVK-local hit-test helpers.
    - Permission-mode picker: the hit test answers the middle segment, which is the current mode ("default"). A landing presses it and nothing changes. No action to assert, and it is unclear what a landing on a segmented Picker should do.

    Request deck buttons: the card does not name them, so no note is needed.
  timestamp: 2026-10-27T14:25:54.460032+00:00
- actor: claude-code
  id: 01m5yw1zh3z4nw723r3z7kaya9
  text: |-
    ### implement — stuck
    - evidence: `swift package update EditorKit` resolved to 2906f93 (contains 114592d) with no build break. `swift test --filter 'ThreadBarControlJumpHostedTests|ThreadBarInsetHostedTests|ThreadBarBannerOverlapHostedTests'` ran 11 tests in 3 suites, all passed. The source tree is unchanged: the `.targetable(true)` exploration and the test probes were reverted. Package.resolved (git-ignored) now points at 2906f93.
    - blocked: (1) A landing does not press most bottom-bar controls, and `window.accessibilityHitTest` answers the scroll view or a row for Send, Stop, Sign In/Out, Show Error, dictation, suggestion, Remove Attachment and the pill. The cause is the leaf priority versus AVK accessibility containers (see the findings comment). Whether the fix belongs in EditorKit (lift the leaf priority through enclosing containers) or in AVK (change the `.contain` containers) is a design decision for a human. (2) EditorTestSupport is not an EditorKit product, so the required hit-test helpers cannot be imported. (3) No defined landing action for the segmented permission-mode picker.
    - not run: demo UI test `testASendOfHelloShowsTheReplyOfTheAgent`. It depends on the hit test, and no change is in the tree, so it would only measure the old state.
    - next: EditorKit vends EditorTestSupport (or the hit-test helpers) as a library product. Decide where the container fix goes. Decide what a landing on the segmented picker does. Then re-run /implement ^j4vnh1r.
  timestamp: 2026-10-27T14:26:02.403188+00:00
- actor: claude-code
  id: 01m5yw32wcapd0n3r654znj918
  text: |-
    ### finish iteration 2 — stuck
    - implement: stuck — no source change. EditorKit resolved to 2906f93 (includes 114592d), and the 11 bar tests pass.
    - blockers, all sent to editorkit-a9 on 2026-10-27:
      1. The leaf accessibility priority does not get through AVK's `.accessibilityElement(children: .contain)` containers, nested containers or nested scroll views. Send, Stop, Sign In/Out, dictation, the chip, Remove Attachment, Show Error and the pill lose `window.accessibilityHitTest`. The user wants the fix in EditorKit: same family as ^sfnvvpn, with AVK as the repro.
      2. EditorTestSupport is not an EditorKit library product, so AVK can't import its hit-test helpers. Asked for it as the first step of EditorKit ^1b4z2mv.
      3. A disabled Send still gets a jump label.
      4. Segmented picker: proposed that a landing focuses it and does not press, since there is no meaningful press target.
    - next: pick this up again when EditorKit sends the SHAs.
  timestamp: 2026-10-27T14:26:38.604478+00:00
depends_on:
- 01M5SXEQEEADHVWS3A40XGGX44
position_column: doing
position_ordinal: '8380'
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