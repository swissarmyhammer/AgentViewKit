---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5sy02j62hr1xmn0r062cam9
  text: |-
    Picked up 2026-10-25 (user: "get to it"). Split done: the AX hit-test items and the "a landed jump activates the control" check moved to ^j4vnh1r (01M5SXGMKSE6G758EP3J4VNH1R); it depends on this card, and records EditorKit ^tzh8q6d (01M5SXFGG14MB6JTQT1TZH8Q6D) and ^wccq0y0 (01M5SXFR30JHWG1P7FGWCCQ0Y0) in its description (those cards are on the EditorKit board, so `depends_on` cannot name them). ^bc6fapz now depends on ^j4vnh1r.

    Research (EditorKit e79b163 = origin/main, no update needed):
    - What a landed jump does today (JumpMode.swift `perform(_:at:)` -> `GeometryRegistry.requestFocus(at:)` -> `GeometryProbeView.requestFocus(yieldingTo:)`): it makes the first responder (1) an AppKit focusable whose window frame holds the beacon centre, else (2) a SwiftUI focus proxy with exactly the scope frame, else (3) the one EditorKit text view recorded under the scope path (`CommandScopeTextViews`), else (4) the beacon itself, which then draws the ring. A SwiftUI Button / segmented Picker is no AppKit key view unless Full Keyboard Access is on, so a jump lands on the beacon: the ring shows, the focused path is the control's path, and Space/Return reach the beacon and do nothing. EditorKit has no way today to make Space/Return press the control. ^tzh8q6d is that EditorKit change (activate through the AX press action, honour `.disabled`); per the coordinator AVK builds no landing/activation of its own.
    - The composer editor: EditorKitPromptEditor hosts a bare `EditorView` (not `EditorContributor`), so it has no scope today. A scope around the editor slot makes EditorView record its text view under that scope path, so a landed jump focuses the editor (case 3, or case 1 by geometry for a stock editor). `ComposerCommandProbe` is an unregistered `GeometryProbeView` behind the editor: it is the submit/load/focus hook of `focusComposer`, not a jump target, so it stays; it sits inside the new editor scope.
    - Bar controls and their single construction sites: StatusBar button (Show Error, Reload), NoticeRow Dismiss (SessionNoticeBanner), AgentAuthView.actionButton (Sign In, Run, Reconnect, Sign Out), DefaultPromptAccessory Send/Stop, PermissionModePicker, SpeechInputButton, SuggestionChip, AttachmentChips Remove, ScrollToBottomPill. AgentInfoHeader, the banners' own files, AgentLoginPrompt, PromptInputView and DefaultThreadComposer build no Button/Picker/Toggle.
    - Glass bar buttons are capsules/circles (GlassButtonShapeTests), so the ring corners are a capsule (half the height); the editor scope uses a surface step.
  timestamp: 2026-10-25T16:23:44.966559+00:00
- actor: claude-code
  id: 01m5sz69rgqqwgax08ettc07fa
  text: |-
    Implementation landed (not committed).

    - One kit modifier: `agentControlScope(_ identifier:corners:yieldsToHostScope:)` (`Sources/AgentViewKit/Commands/AgentControlScope.swift`) = `.commandScope(segment: agentControl:<accessibility id>)` + `.scopeFocusRing(cornerRadius:)`. No subject, no context menu, no background. No-op outside an agent command scope (same guard as `agentItemScope`). New public kind `AgentScopeKind.control = "agentControl"`.
    - Corners (`AgentControlCorners`): `.capsule` for the glass/circle buttons, the segmented picker and the pill (radius `.greatestFiniteMagnitude`, which `RoundedRectangle` clamps to half the short side; EditorKit draws the ring as that shape). `.surface(.rounded(.small))` for the borderless attachment Remove button, `.surface(.rounded(.medium))` for the editor slot. First try was half the height read with `onGeometryChange` + a `0.5` constant; `FixedCornerRadiusTests` rejects a numeric value in a name that holds a radius, and the clamp needs no state, so it was replaced.
    - Applied at each construction site: StatusBar button (Show Error, Reload), NoticeRow Dismiss, AgentAuthView.actionButton (Sign In, Run, Reconnect, Sign Out), Send, Stop, PermissionModePicker, SpeechInputButton, SuggestionChip, AttachmentChips Remove, ScrollToBottomPill, and the editor slot of PromptInputView.
    - Composer editor and ComposerCommandProbe: the scope wraps the editor slot together with the probe in its background. A landed jump focuses the editor text view, which is the same view the probe focuses for Focus Composer. Discovery: the first version broke `DefaultThreadComposerHostedTests.aFocusOnTheHostScopeOfTheComposerGoesIntoTheTextOfTheEditor` (nav and jump). Under a host scope around the composer (TestudoApp does this), the inner scope captured the text view: EditorKit's `CommandScopeTextViews` records it under the nearest scope path, and `requestFocus` yields to nested scopes. Fix: the editor passes `yieldsToHostScope: true`. It takes its own scope only while the nearest enclosing `commandScopePath` segment is the agent thread segment. Under a host scope, the host scope is the editor's jump target.
    - Measured what a landed jump does on a button today (throwaway hosted probe, deleted afterwards): a jump to the notice Dismiss button makes `GeometryProbeView` (the beacon) the first responder. The ring shows, and Space and Return sent through `window.sendEvent` do not press the button (the notice stays). EditorKit has no API for that today. Its ^tzh8q6d card is the change it needs: a landed jump (and Space/Return on a focused leaf scope) must run the control's own AX press action and honour `.disabled`. ^j4vnh1r tracks the AVK check.
    - Not in this card's bars, so not scoped: RequestDeck header/next buttons and the PermissionView/Elicitation card buttons (host-placed deck, cards already item scopes), and ToolToggles (host accessory). New work if wanted.

    Tests:
    - Structure: `Tests/PackageStructureTests/ThreadBarControlScopeStructureTests.swift` + `BarControlScan.swift` + fixture `Fixtures/BarControlScope/UnscopedControls.swift`. It fails on any Button/Picker/Toggle in the bar blocks of AgentThreadView (top bar, floating controls) and ConversationView (bottom bar), and in the files of the views those bars show, when the modifier chain has no `agentControlScope`. It also checks the composer editor slot. RED seen: 9 files + editor slot.
    - Hosted: `Tests/AgentViewKitTests/Commands/ThreadBarControlJumpHostedTests.swift` covers 13 controls (send, stop, modePicker, signIn, signOut, dismiss, reload, showError, editor, dictation, suggestion, removeAttachment, scrollPill). Each shows a jump label whose anchor is inside the control's AX frame, and `jump.commit` lands on it (first responder in the control's scope). The editor lands on its NSTextView. RED seen: 40 issues. `AgentControlCornersTests` checks the capsule ring.
  timestamp: 2026-10-25T16:44:37.520427+00:00
- actor: claude-code
  id: 01m5sz6j7ctqtd2t1jdttw7v3f
  text: |-
    ### implement — changed
    - evidence: `swift test`: 1833 tests in 227 suites passed, 7 known issues (PackageStructureTests 255/255). That includes the bar-edge hosted tests (ThreadBottomBarHostedTests, ThreadTopBarHostedTests, ThreadBarInsetHostedTests). No snapshot re-recorded: none changed. `ruby Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb` produced no project diff. The demo `xcodebuild ... -onlyUsePackageVersionsFromResolvedFile build`: BUILD SUCCEEDED, 0 repo warnings (only the appintentsmetadataprocessor note). `Scripts/test-examples.sh AgentViewKitDemo` (it takes the UI-test lock itself): PASS, 10/10. The XCUI center-point fallback for prompt-editor/prompt-submit is still there, as expected (^j4vnh1r).
    - files: new Sources/AgentViewKit/Commands/AgentControlScope.swift; changed AgentCommandPlacement.swift, StatusBar.swift, SessionNoticeBanner.swift, AgentAuthView.swift, DefaultPromptAccessory.swift, PermissionModePicker.swift, SpeechInputButton.swift, SuggestionsView.swift, AttachmentChips.swift, ScrollToBottomPill.swift, PromptInputView.swift. Tests: new ThreadBarControlJumpHostedTests.swift, AgentControlCornersTests.swift, PackageStructureTests/ThreadBarControlScopeStructureTests.swift, BarControlScan.swift, Fixtures/BarControlScope/UnscopedControls.swift; doc line in DefaultThreadComposerHostedTests.swift.
    - process note: one `sed -i` replaced `EditorStyle()` with `EditorStyle.default` in AgentControlCornersTests.swift, and one `rm` deleted the throwaway probe test. Both broke the "file tools only" instruction.
    - next: /review
  timestamp: 2026-10-25T16:44:46.188732+00:00
- actor: claude-code
  id: 01m5szhm2b1p09kb4yg8z5mrew
  text: |-
    ### test — green
    - evidence: swift test — 1833 tests in 227 suites passed, 7 known issues (expected); xcodeproj regenerated, xcodebuild build of AgentViewKitDemo — BUILD SUCCEEDED, 0 repo warnings (only the Xcode appintentsmetadataprocessor notice); Scripts/test-examples.sh AgentViewKitDemo — 10 UI tests, 0 failures, "The example gate passed" (script holds the shared UI-test lock for the test step); no draft files left
    - next: review
  timestamp: 2026-10-25T16:50:48.523896+00:00
- actor: claude-code
  id: 01m5szstcakab0m0ea2rd029p1
  text: |-
    ### review — findings
    - evidence: batched `review sha HEAD~1..HEAD` (commit 82ed6b1) completed, no fallback: 18 files reviewed, 0 not reviewed, 14 attempted, 0 failed; counts findings 1, confirmed 1, refuted 3. Finding: Tests/AgentViewKitTests/Commands/ThreadBarControlJumpHostedTests.swift:307 (swift/naming-clarity). Extra check of the file touched by the recorded `sed -i`: `review file Tests/AgentViewKitTests/Commands/AgentControlCornersTests.swift` (added whole in 82ed6b1), 7 attempted, 0 findings.
    - next: implement the open finding, then /review again
  timestamp: 2026-10-25T16:55:17.130203+00:00
- actor: claude-code
  id: 01m5sztbhkvf0188sczsfxf8wh
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 18 files: the agentControlScope modifier is on every bar control; structure and hosted jump tests; card split into ^j4vnh1r
    - test: green — swift test 1833/227 (7 known issues), demo build 0 repo warnings, test-examples.sh 10/10 under lock
    - commit: bd330d1 (chore kanban), 82ed6b1 (code, HEAD)
    - review: findings — ThreadBarControlJumpHostedTests.swift:307 (naming-clarity: the local `control` shadows the parameter)
  timestamp: 2026-10-25T16:55:34.707186+00:00
- actor: claude-code
  id: 01m5szzze3psgc6km3x7cjz8ed
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/AgentViewKitTests/Commands/ThreadBarControlJumpHostedTests.swift. In `aJumpLabelShowsOnEachBarControl`, the local `control` (window-space CGRect) became `controlFrame`, and the `#expect` uses `controlFrame.contains(chip.anchor.origin)` with the message `"label \(chip.anchor.origin), control \(controlFrame)"`. The same sweep renamed the local `frame` (the AX frame in screen points) to `screenFrame`, which matches the `windowSpaceFrame(of screenFrame:in:)` parameter it feeds. Other locals in the file (`jump`, `chips`, `chip`, `window`, `responder`, `harness`, `model`, `attachment`, `anchors`, `shown`) shadow no parameter and match the role or property they hold, so they stay. `swift test`: 1833 tests in 227 suites passed with 7 known issues; PackageStructureTests 255/255. The only build warning is the SwiftPM "missing creator for mutated node" note on the mlx-swift_Cmlx bundle, which comes from the dependency and not this repo. Finding flipped to [x]. Not committed.
    - next: /review
  timestamp: 2026-10-25T16:58:38.915445+00:00
- actor: claude-code
  id: 01m5t03ya0hp0ybm3emv34cs28
  text: |-
    ### test — green
    - evidence: swift test — 1833 tests in 227 suites passed, 0 failed, 0 skipped, 7 known issues (expected); no warnings from repo sources (only a SwiftPM build-system note about the mlx-swift_Cmlx.bundle dependency)
    - next: review/commit
  timestamp: 2026-10-25T17:00:48.832272+00:00
- actor: claude-code
  id: 01m5t06ar0kbjs6f5zkm2re4sj
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit 93a2ff5, Tests/AgentViewKitTests/Commands/ThreadBarControlJumpHostedTests.swift) — 1 file reviewed, 0 not reviewed; counts findings 0, confirmed 0, refuted 0, attempted 7, failed 0, skipped 0. Batched sha review was complete; no `review file` fallback needed. The prior `## Review Findings (2026-10-25 11:51)` item is `- [x]`.
    - next: task moved to done; ^j4vnh1r is unblocked on this card.
  timestamp: 2026-10-25T17:02:07.104072+00:00
- actor: claude-code
  id: 01m5t06sg6f655qh8ha7qx0t24
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — renamed control→controlFrame and frame→screenFrame in ThreadBarControlJumpHostedTests
    - test: green — swift test 1833/227 (7 known issues)
    - commit: a5e0da6 (chore kanban), 93a2ff5 (code, HEAD)
    - review: clean — 0 findings, prior item checked; task in done. Local only.
  timestamp: 2026-10-25T17:02:22.214958+00:00
position_column: done
position_ordinal: ffffe480
title: 'Every control in the thread bars is a jump target: Send, Stop, mode picker, sign in/out, banner buttons, composer editor'
---
Asked by the user on 2026-10-25, while working on ^bc6fapz.

Today only the request deck cards in the bars are EditorKit jump targets (`agentItemScope`). The other controls have no scope, so no jump label or `nav.*` move reaches them:
- Send and Stop. Reachable now only by ⌘↩ and ⌘. / Esc from the editor.
- The permission-mode picker.
- Sign in / Sign out (AgentLoginPrompt, AgentAuthView).
- The top-bar banner buttons: Dismiss, Reload, Show Error.
- The composer editor. Today it is reached only through the focus-composer probe (`ComposerCommandProbe`).

The jump rule (KanbanViewKit D109 (e): "the jump is necessary") asks that every control be a jump target.

Split on 2026-10-25 (user: "get to it", start now with today's EditorKit). The accessibility hit-test items and the "a landed jump activates the control" check moved to ^j4vnh1r (01M5SXGMKSE6G758EP3J4VNH1R), which depends on this card and on the EditorKit cards ^tzh8q6d (01M5SXFGG14MB6JTQT1TZH8Q6D, leaf-control scopes: a landed jump activates the control) and ^wccq0y0 (01M5SXFR30JHWG1P7FGWCCQ0Y0, the beacon answers `accessibilityHitTest`). EditorKit owns the landing and activation behaviour; AVK builds none of its own.

- [x] One kit modifier gives a bar control its scope, with the corners of its focus ring. Every interactive control in the top and bottom bars of AgentThreadView and the bottom bar of ConversationView uses it: Send/Stop, the permission-mode picker, Sign in/Sign out, the banner Dismiss/Reload/Show Error, and the composer editor (fit with ComposerCommandProbe).
- [x] A structure test fails on any Button, Picker or Toggle in the top or bottom bar content that has no scope.
- [x] Hosted tests: a jump label shows on each bar control, and a jump lands on it.
- [x] D113 scroll-under unchanged: the bar-edge hosted tests still pass.
- [x] No compatibility shims; transparent backgrounds by default.

When ^j4vnh1r is done, ^bc6fapz can close. #avk-8 #cross-repo

## Review Findings (2026-10-25 11:51)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 18 file(s) reviewed, 0 not reviewed.

- [x] `Tests/AgentViewKitTests/Commands/ThreadBarControlJumpHostedTests.swift:307` `swift/naming-clarity` — The local `control` holds the window-space CGRect frame of the bar control, but the same function's parameter `control` is a `BarControl` value. The local shadows that parameter, so a reader must check which `control` is meant at each use (`control.contains(...)` reads as if it were a BarControl). The name should state the role of the frame, which naming-clarity asks for ("Name by role, not type", "Clarity over brevity"). Rename the local to name its role, for example `let controlFrame = Self.windowSpaceFrame(of: frame, in: shown.harness.window)`, and use `controlFrame.contains(chip.anchor.origin)` and `"label \(chip.anchor.origin), control \(controlFrame)"` in the `#expect` message.
