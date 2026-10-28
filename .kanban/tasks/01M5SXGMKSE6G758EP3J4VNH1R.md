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
- actor: claude-code
  id: 01m5zngnrks7ezv6zjbg99m3v3
  text: |-
    ### implement: research (2026-10-27, pass 3)
    - `swift package update EditorKit` resolved to ec7a011 (^sfnvvpn done). EditorTestSupport is a library product now and already sits in `editorKitTestSupportProducts` of Package.swift, so AVK can import `accessibilityHitTest(atCenterOfScopeAt:in:window:)` and `accessibilityIdentifier(of:)`.
    - EK leaf landing (JumpMode `press(at:)`): `.enabled` focuses then presses through the AX press action; `.disabled` does nothing and the scope gets no jump label; `.segmented` (the permission-mode picker) only focuses, then Left/Right/Space change the segment. So for the picker "activates" now means "focuses, no press".
    - Observables for a landed press, all synchronous in the press: Send -> host `onSubmit` count (needs non-empty text, so the host needs a real text binding); Stop -> `requestStartReport` gets `session/cancel`; Reload -> `session/resume`; Sign In / Sign Out -> the button disables while its call runs (hold `auth/login` / `auth/logout` so the call never ends); Dismiss -> `session.notices` empty; Show Error -> `anchors.anchorID` is the error row key; dictation -> `speechInputPhaseReport` gets `.recording`; suggestion -> the composer text becomes the suggestion; Remove -> the attachment leaves the binding; pill -> `anchors.isPinnedToBottom`.
    - The current host uses `.constant` bindings for text and attachments, so suggestion and Remove presses change nothing observable, and Send is disabled (empty text). The host gets an observable draft.
    - With `.targetable(true)` a disabled Send gets no jump label, so `aJumpLabelShowsOnEachBarControl(send)` needs text in the composer; a separate test covers the disabled Send.
  timestamp: 2026-10-27T21:50:58.323873+00:00
- actor: claude-code
  id: 01m5zqpc6t790m5td3sh98ajwz
  text: |-
    ### implement: findings (2026-10-27, pass 3)
    - Landed: `.targetable(true)` in `AgentControlScope`. TDD: RED had 23 issues in `ThreadBarControlJumpHostedTests` (no press for any of the 11 buttons, a disabled Send still got a label, 10 hit tests answered a scroll view or a row). GREEN: the suite passes (13 + 11 + 2 + 1 + 13 + 1 cases).
    - New tests: `aJumpToEachBarButtonPressesIt` (Send, Stop, Sign In, Sign Out, Dismiss, Reload, Show Error, dictation, suggestion, Remove, pill), `aJumpToEachFocusOnlyBarControlFocusesIt` (editor, picker), `aDisabledSendIsNoJumpTarget`, `theHitTestAtTheCenterOfEachBarControlAnswersTheControl` (all 13, through EditorTestSupport `accessibilityHitTest(atCenterOfScopeAt:in:window:)`). The host now binds an observable draft (text, attachments, submit count) and records `requestStartReport` and `speechInputPhaseReport`; Sign In / Sign Out hold `auth/login` and `auth/logout`, so no sign-in or sign-out ever completes in a test.
    - Picker: the window hit test answers the segment under the point (`permission-mode-value-default`), as VoiceOver reads a segmented control; the test accepts a segment of the picker. A landing only focuses it (EK `.segmented`).
    - EK first-read gap (for EditorKit): right after mount, the FIRST `accessibilityHitTest(atCenterOfScopeAt:)` over the suggestion chip and over Remove (each in a nested horizontal ScrollView) answers `HostingScrollView`; the second read answers the control. The test reads the tree once first (`harness.frame(identifier:)`, the precondition that the control shows), with a comment. A real AX client has read the tree already, so it is likely only the helper's build-for-one-read tree, but EditorKit should confirm in `LeafControlHitTestOverrideTests` with a first read straight after mount.
    - Breaks from the EK range, fixed minimally (no tile adoption): `EditorStyle.tile` is now ambiguous between EK's stored `Tile` and AVK's internal `ContentTileSpacing` extension in the test module, so `ContentTileInsetHostedTests` and `DiffViewHostedTests` annotate the type `ContentTileSpacing`. `ViewValueLayoutTests.theStyleHasNoPaddingByte` failed (40 uncovered bytes = EK's new `tile` and `chip` fields); it now lists both, and two new tests cover `EditorStyle.Tile` and `EditorStyle.Chip`. The sort-priority removal broke no AVK test (ThreadTopBarHostedTests reading-order tests pass).
    - Demo UI test (`Scripts/test-examples.sh`, which takes the shared UI-test lock; it waited on an EditorKit holder once): `submit.isHittable` is now true and XCUI logs no "Falling back to element center point" for Send. `editor.isHittable` is FALSE, before and after typing, and XCUI logs "Falling back to element center point: {670, 840}" for `editor.click()`. The XCUI tree shows the `prompt-editor` TextView with a sibling Group of the identical frame inside `prompt-field-surface`; in a hosted copy of that shape the sibling is `EditorSwiftUI.PlaceholderHostingView` (EditorKit's placeholder overlay). The in-process `window.accessibilityHitTest` answers the text view, but XCUI does not. The editor is no leaf control, so the ^sfnvvpn override does not cover it.
  timestamp: 2026-10-27T22:29:02.298711+00:00
- actor: claude-code
  id: 01m5zqpqgd33zvcf97xhvdv0y4
  text: |-
    ### implement — stuck
    - evidence: EditorKit resolved to ec7a011. 9 files: Sources/AgentViewKit/Commands/AgentControlScope.swift; Tests/AgentViewKitTests/Commands/ThreadBarControlJumpHostedTests.swift; Tests/AgentViewKitTests/Input/PromptInputViewHostedTests.swift (draft holds attachments); Tests/AgentViewKitTests/Theme/ContentTileInsetHostedTests.swift, Tests/AgentViewKitTests/Diff/DiffViewHostedTests.swift, Tests/AgentViewKitTests/Infrastructure/ViewValueLayoutTests.swift (EK-range breaks); Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift. Full `swift test` before the last fix: 1878 tests in 233 suites, 1 failure (ViewValueLayoutTests, now fixed and re-run: 11/11 pass) and 7 intentional known issues, plus 260 and 1 tests passed; the touched suites re-ran green (48 tests in 5 suites). Only build warning: the known mlx-swift "missing creator" SwiftPM notice. Bar-edge suites ThreadBarInsetHostedTests and ThreadBarBannerOverlapHostedTests pass.
    - gap: card item "Demo UI test asserts `editor.isHittable` and `submit.isHittable`, and no 'Falling back to element center point'". Send passes; `editor.isHittable` fails (Scripts/test-examples.sh: AgentViewKitDemo FAIL at ACPTabEndToEndTests.swift `editor.isHittable`), and XCUI falls back to the centre point for the editor click. The editor is EditorKit's text view, not a leaf control, and the XCUI tree shows EditorSwiftUI's PlaceholderHostingView as a same-frame sibling of the text view. The fix is in EditorKit (the ^sfnvvpn family: a targetable scope whose content is a text view, or the placeholder overlay taking the XCUI hit). The assertion stays in the demo test so the gap is visible.
    - next: EditorKit makes the composer text view XCUI-hittable (and confirms the first-read nested-ScrollView hit test), then re-run Scripts/test-examples.sh and /test for ^j4vnh1r. Then ^bc6fapz can close.
  timestamp: 2026-10-27T22:29:13.869557+00:00
- actor: claude-code
  id: 01m5zres3g8d622h6ff0yp4kvm
  text: |-
    ### test — red
    - evidence: `swift test` (taken under the shared UI test lock via Scripts/ui-test-lock.sh) exit 0. 1880 tests in 233 suites passed, 0 failed, 0 skipped. The 7 known issues are the intentional `withKnownIssue` cases in SnapshotStoreTests, HostedLayoutExpectationsTests and FontRoleExpectationsTests, which prove the check helpers fail on bad input. No compiler warnings in AVK code. One warning is present and reproducible on every build: `warning: missing creator for mutated node: ('.build/out/Products/Debug/mlx-swift_Cmlx.bundle/Contents/MacOS')`. It comes from SwiftPM packaging the mlx-swift dependency's resource bundle. I deleted the stale generated bundle (git-ignored .build output) and rebuilt, and the warning came back, so it is not AVK code and not a stale-cache problem.
    - no AVK code or test edits were needed. Scripts/test-examples.sh was not run (known editor.isHittable failure, left untouched). Nothing committed.
    - next: a person decides whether the mlx-swift SwiftPM warning is accepted or fixed upstream (mlx-swift pin). All ^j4vnh1r tests are otherwise passing.
  timestamp: 2026-10-27T22:42:21.936282+00:00
- actor: claude-code
  id: 01m5zrk4w4zj6k040z2mpcm8jv
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (54efbe4): 7 files reviewed, 0 not reviewed; counts findings 0, confirmed 0, refuted 1, failed 0, skipped 0. No findings to record.
    - next: card stays in `review`, not `done`. Acceptance item "Demo UI test: `testASendOfHelloShowsTheReplyOfTheAgent` asserts `editor.isHittable`..." is still unchecked, blocked on EditorKit ^yb2p8xe reaching main. Close the card once that item is checked.
  timestamp: 2026-10-27T22:44:45.060831+00:00
- actor: claude-code
  id: 01m5zrkpa9s2a5bb9nk9vc3a8q
  text: |-
    ### finish iteration 3 — clean
    - implement: changed. 7 files; EditorKit at ec7a011 (^sfnvvpn); `.targetable(true)` in AgentControlScope.
    - test: swift test passed 1880 tests, 0 failed, 0 skipped. The only warning is SwiftPM's mlx-swift_Cmlx bundle "missing creator for mutated node", which appears on every build in this session. Scripts/test-examples.sh still fails on `editor.isHittable`, as expected.
    - commit: 3984994 (kanban), 54efbe4 (code)
    - review: clean. 0 findings across 7 files.
    - held in review: the `editor.isHittable` acceptance item waits on EditorKit ^yb2p8xe (placeholder overlay hidden from accessibility; cold hit test). ^bc6fapz closes after this card.
  timestamp: 2026-10-27T22:45:02.921716+00:00
- actor: claude-code
  id: 01m617h1bbd5g1mts40xrh0agq
  text: |-
    ### implement: findings (2026-10-28, pass 4)
    - `swift package update EditorKit` resolved to f588cb5, which descends from a044349 and cf8cc84 (^yb2p8xe). The demo's own Package.resolved (git-ignored .xcodeproj) also pins f588cb5. AVK builds on it with no source change.
    - Removed the tree pre-read and its comment from `ThreadBarControlJumpHostedTests.theHitTestAtTheCenterOfEachBarControlAnswersTheControl`. On a cold hit test the suite passes: 6 tests, with all 13 hit-test cases.
    - `Scripts/test-examples.sh` still FAILS: `ACPTabEndToEndTests.swift` `editor.isHittable`, "The composer editor is not hittable". The other 8 UI tests pass.
    - ^yb2p8xe did remove the placeholder sibling: the XCUI tree no longer shows a Group with the same frame next to `prompt-editor`. So the cause is now a different one.
    - What I measured with temporary probes (all reverted; the demo files match HEAD again):
      - **Remote AX hit test.** Calling XCTest's own `XCAXClient_iOS -hitTestElement:withPoint:error:` at the editor's centre (670,840) answers the AXScrollArea of `conversation-empty-state`. That is the transcript under the bar: AXScrollArea → `conversation-empty-state` → `agentThread demo-session` → … → window. At Send's centre the same call answers `prompt-submit`. The XCUI snapshot's own `hitPoint:` says hittable YES at (670,840). So it is only the AX hit test that loses.
      - **In-process hit test.** Inside the demo app, at the same moment, `window.accessibilityHitTest`, `NSApp.accessibilityHitTest` and `contentView.accessibilityHitTest` at the editor's centre all answer `EditorInputTextView` (`prompt-editor`). The parent chain is right: `prompt-field-surface` (label `agentControl prompt-editor`) → `thread-floating-controls` → `agentThread`. With AXEnhancedUserInterface set the answer is the same. So the in-process read, which EditorTestSupport and AVK's hosted test use, answers the text view. The read an out-of-process client makes (XCUI, and VoiceOver or Hover Text the same way) answers the scroll view behind the bar.
      - The same split shows on other elements. XCUI reports not hittable for `prompt-field-surface`, `agent-auth`, `agent-auth-title`, `thread-floating-controls` and the picker segments. The remote hit at a segment answers the whole `permission-mode-picker` RadioGroup. Leaf buttons (Send, Sign In, Sign Out) and the picker as a whole are hittable.
      - Ruled out: the disabled state, since `session-list-search` is "Disabled" too and is hittable. Also ruled out: the child window `NSCampoLightweightUIHostWindow` (100,804 280x168). It does not cover (670,840), and the picker, which it does cover, is hittable.
    - Conclusion: the leaf override answers remote clients for leaf controls. The editor scope is no leaf control, so a remote hit at its centre still falls through to SwiftUI, which answers the ScrollView under the floating bar. EditorKit owns the hit test (card: "Do not build landing or activation behaviour in AVK"), so the fix belongs there. The repro is AVK `Scripts/test-examples.sh`. An EditorKit test should hit-test through the remote AX path (an XCUI or AXUIElementCopyElementAtPosition test of an EditorView in a `.safeAreaBar` or overlay over a ScrollView), not only through `window.accessibilityHitTest` in process.
  timestamp: 2026-10-28T12:24:58.987894+00:00
- actor: claude-code
  id: 01m617h8bv0h007r5mq44sktn1
  text: |-
    ### implement — stuck
    - evidence: 1 file changed, Tests/AgentViewKitTests/Commands/ThreadBarControlJumpHostedTests.swift (tree pre-read and its comment removed). EditorKit resolved to f588cb5, which contains a044349 and cf8cc84. `swift test --filter ThreadBarControlJumpHostedTests`: 6 tests passed, all 13 hit-test cases on a cold hit test. Full `swift test`, run under the UI-test lock: 1889 tests in 235 suites passed, 0 failed, 0 skipped. The 7 known issues are the intentional `withKnownIssue` cases. The only warning is the existing mlx-swift_Cmlx "missing creator" notice. `Scripts/test-examples.sh`: AgentViewKitDemo FAIL, 1 of 9: ACPTabEndToEndTests `editor.isHittable` ("The composer editor is not hittable"). XCUI still falls back to the centre point for the editor click.
    - gap: acceptance item "Demo UI test: … asserts `editor.isHittable` … no 'Falling back to element center point'" stays unchecked. At the editor's centre, the remote AX hit test (XCTest `hitTestElement:withPoint:error:`) answers the `conversation-empty-state` AXScrollArea under the bar. The in-process `window.accessibilityHitTest` answers the text view. Details are in the findings comment. EditorKit owns the hit test.
    - next: EditorKit makes a remote (out-of-process) AX hit test at an EditorView's centre answer its text view when the editor sits in a bar over a ScrollView. Then pull EditorKit, re-run Scripts/test-examples.sh and check off the item. Nothing is committed; the card stays in doing.
  timestamp: 2026-10-28T12:25:06.171469+00:00
- actor: claude-code
  id: 01m617m7m26zt4k5hfzscbz13d
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (2071461) — 0 findings, 0 confirmed, 0 refuted; 7 validators attempted, 0 failed, 0 skipped; 1 file reviewed
    - next: card stays in review, not done. Open acceptance item: demo UI test `editor.isHittable`, blocked on EditorKit ^sva41w0 (out-of-process hit test). That item is not a finding for this diff.
  timestamp: 2026-10-28T12:26:43.714021+00:00
- actor: claude-code
  id: 01m617mqh3c7jh7wbxzbbgzsrb
  text: |-
    ### finish iteration 4 — clean, held
    - implement: stuck on the demo item only. EditorKit is at f588cb5; the tree pre-read is removed. The in-process hit test returns the text view, but the out-of-process one (XCUI) returns the conversation-empty-state ScrollView.
    - test: swift test passed 1889 tests, 0 failed. test-examples.sh passed 8 of 9; `editor.isHittable` fails.
    - commit: cad3615 (kanban), 2071461 (code)
    - review: clean. 0 findings.
    - Held in review for EditorKit ^sva41w0 (out-of-process hit test for EditorView, SingleLineField and the other bar elements).
  timestamp: 2026-10-28T12:27:00.003151+00:00
depends_on:
- 01M5SXEQEEADHVWS3A40XGGX44
position_column: done
position_ordinal: fffff980
title: The thread bar controls are accessibility-hittable, and a landed jump activates them (after EditorKit ^tzh8q6d and ^wccq0y0)
---
Split from ^0xggx44 on 2026-10-25 (user: "get to it"). ^0xggx44 gives every control in the thread bars an EditorKit scope through one kit modifier. This card holds the items that need EditorKit work first.

Depends on two EditorKit cards (EditorKit board, not this one, so they are recorded here and not as `depends_on` links):
- ^tzh8q6d (01M5SXFGG14MB6JTQT1TZH8Q6D): leaf-control scopes. `.commandScope` + `.targetable` go directly on a Button, Toggle, Picker or Menu. A jump that lands on one ACTIVATES it like a click, through its own AX press action, so it honours `.disabled`. Focus also moves to it. `nav.*` only focuses it.
- ^wccq0y0 (01M5SXFR30JHWG1P7FGWCCQ0Y0): the scope beacon's `accessibilityHitTest` returns the SwiftUI element under the point.
Do not start until both commits are on EditorKit main. Record the SHAs when you start. Do not build landing or activation behaviour in AVK: EditorKit owns it.

Background: SwiftUI's AX hit test returns the transcript row under any view layered over a ScrollView (`.safeAreaBar`, `.overlay`, `.safeAreaInset`, `ZStack`). Minimal repro and the full analysis are in the comments of ^bc6fapz.

- [x] Hosted tests: a landed jump on each bar control (Send, Stop, permission-mode picker, Sign in / Sign out, banner Dismiss / Reload / Show Error) activates it; a disabled control is not activated.
- [x] Hosted tests: `window.accessibilityHitTest` at the centre of each bar control returns the control, not the row under the bar.
- [x] Demo UI test: `testASendOfHelloShowsTheReplyOfTheAgent` asserts `editor.isHittable` and `submit.isHittable`, and the XCUI log has no "Falling back to element center point" for them.
- [x] D113 scroll-under unchanged: the bar-edge hosted tests still pass.
- [x] No compatibility shims; transparent backgrounds by default.

When this card is done, ^bc6fapz can close. #avk-8 #cross-repo