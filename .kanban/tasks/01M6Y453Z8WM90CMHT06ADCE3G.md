---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6y5bjasx8k1ar0h8qe4jybm
  text: |-
    Research (EK 4e673e2c):
    - `.editorButtonBorderShape(_:)` sets only the environment value `\.editorButtonBorderShape`. EditorButton reads it: it applies `.buttonBorderShape(shape.buttonBorderShape)` itself (not for `.automatic`) and reports the same bezel to its scope (`reportsBezel`). All three AVK call sites are EditorButtons, so `.editorButtonBorderShape` replaces `.buttonBorderShape`; we do not keep both.
    - An icon-alone action button (`.editorButtonCaptions(.hidden)`) is always a circle (`EditorIconFrame.borderShape`), so the circle buttons report a capsule ring already.
    - The ring of a scope is `requested ?? control ?? (leaf ? capsule : rectangle)`. `agentControlScope` always requests corners (`AgentControlCorners.capsule` = `.scopeFocusRing(cornerRadius: .greatestFiniteMagnitude)`), so the request hides the bezel the button reports. Result: the status bar buttons (Show Error, Reload, Dismiss) and the Sign In / Sign Out buttons show a capsule ring around a bezel with 6 pt continuous corners. Item 3 finding: this is the ring that does not follow the bezel.
    - Plan: `AgentControlCorners` gets a `control` case in place of `capsule`: the scope requests no corners, so the ring takes the shape the control reports (EK bezel), else the EK leaf default (capsule) for a control that reports none (the segmented PermissionModePicker). `.surface` keeps its request (composer editor, attachment Remove button).
    - Attachment Remove button: a bare EditorToolbarButton (no bezel; EK reports toolbar glass = capsule). AVK requests `.surface(.rounded(.small))` on purpose. No change.
    - Item 4: InlineCitation pill is drawn by Textual in a canvas, with no command scope and no focus; PendingRequestCountBadge is a display in a session row. Neither is selectable or focusable. No change.
    - Hosted test plan: focus the scope of a bar control (`geometry.requestFocus(at:)`, no press), read the ring band layer (`ScopeFocusRingBandView`, a CAShapeLayer path, no pixels) and the corners the control reports.
  timestamp: 2026-11-08T18:05:01.145325+00:00
- actor: claude-code
  id: 01m6y658aqd89gfeeb8bx6zq88
  text: |-
    Implementation landed (not committed):
    - Items 1, 2: FloatingGlassAction uses `.editorButtonBorderShape(.capsule)` (with `import EditorSwiftUI`); DefaultPromptAccessory and SpeechInputButton use `.editorButtonBorderShape(.circle)`. No `.buttonBorderShape` stays in Sources.
    - Item 3: `AgentControlCorners.capsule` is replaced by `.control`, the default of `agentControlScope`. The scope then asks for no corners, so the ring takes the bezel that the EditorKit button reports (status bar buttons, Sign In / Sign Out: 6 pt continuous corners; floating glass actions: capsule; round buttons: circle). The segmented PermissionModePicker reports no shape and keeps the EK leaf default, a capsule. `.surface` corners (composer editor, attachment Remove button) keep their request.
    - Item 4: no change (InlineCitation and PendingRequestCountBadge are not selectable or focusable).
    - Item 5: new IntegrationTests/Tests/IntegrationTests/Commands/BarButtonFocusRingHostedTests.swift. It focuses the scope with `geometry.requestFocus(at:)` (no press) and reads state: `focusIndicator.controlCorners` and the CGPath of the `ScopeFocusRingBandView` layer. BarControlThreadHost now sets `\.appearsActive` true so the band draws in a window that is not key.
    - RED seen: band test failed for 10 of 10 bar buttons with the CGPath compare (before the AgentControlScope change, 6 failed: the capsule request hid the 6 pt bezel); floating glass test failed 2 of 2 until `.editorButtonBorderShape(.capsule)`.
    - Dead end: comparing `Path(cgPath) == Path` fails for equal shapes (SwiftUI Path storage differs); compare CGPath to CGPath.
    - Item 6: ScreenshotTests recorded again. Changed PNGs show no visible change (no shot focuses a bar button): snapshots/HostedSnapshotTests/item-focus-message-{light,dark}.png, generated/HostedSnapshotTests/item-focus-message-{light,dark}.png, screens/gallery-light.png; new files generated/GlassSnapshotTests/thread-header-{light,dark}.png.
  timestamp: 2026-11-08T18:19:02.871758+00:00
- actor: claude-code
  id: 01m6y65bcze3k4htmn2wpvt9d0
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKit/Commands/AgentControlScope.swift, Sources/AgentViewKit/Theme/FloatingGlassAction.swift, Sources/AgentViewKit/Input/DefaultPromptAccessory.swift, Sources/AgentViewKit/Input/SpeechInputButton.swift, Tests/AgentViewKitTests/Commands/AgentControlCornersTests.swift, IntegrationTests/Tests/IntegrationTests/Commands/ThreadBarControlJumpHostedTests.swift, new IntegrationTests/Tests/IntegrationTests/Commands/BarButtonFocusRingHostedTests.swift. `swift test`: 1075 + 50 passed. `swift test --package-path IntegrationTests`: 1045 passed, 5 known issues (FontRoleExpectationsTests). `swift test --package-path ScreenshotTests`: 33 passed.
    - next: /review
  timestamp: 2026-11-08T18:19:06.015129+00:00
- actor: claude-code
  id: 01m6y6g8kvb2px5vhrmsq228j1
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (22d0ba27); 1 finding (1 confirmed, 0 refuted) — Sources/AgentViewKit/Input/SpeechInputButton.swift:71 `reuse/reuse`
    - next: implement the finding in the dated Review Findings section, then review again
  timestamp: 2026-11-08T18:25:03.611009+00:00
- actor: claude-code
  id: 01m6y6gr6hrzgffzhtkfre4nn8
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 7 files
    - test: green — swift test 1075+50; IntegrationTests 1045 (5 known); ScreenshotTests 33
    - commit: 22d0ba27
    - review: findings — Sources/AgentViewKit/Input/SpeechInputButton.swift:71
  timestamp: 2026-11-08T18:25:19.569504+00:00
- actor: claude-code
  id: 01m6y6wq910zaf4fqaxd2g88xh
  text: |-
    Finding `reuse/reuse` (SpeechInputButton.swift:71) is fixed:
    - New `View.circleAction(identifier:)` in Sources/AgentViewKit/Theme/CircleAction.swift, next to the `floatingGlassAction(glassID:identifier:)` analog. It applies `.editorButtonCaptions(.hidden)`, `.editorButtonBorderShape(.circle)`, `.accessibilityIdentifier(identifier)` and `.agentControlScope(identifier)`.
    - `DefaultPromptAccessory.circleActionButton` and `SpeechInputButton.body` call it. The parts for each button (title, symbol, variable value, action, `.accessibilityValue`, `.onDisappear`) stay at the call sites. `.accessibilityValue` stays before the helper, on the button, as before.
    - Search of the whole Sources tree: `.editorButtonBorderShape(.circle)` occurs only at these two sites. The other `.editorButtonCaptions(.hidden)` sites are EditorToolbarButtons or containers (RequestDeck, SessionListView, MessageActions, CodeBlockView, CommandOutputView, ReasoningView, AttachmentChips) with no circle bezel, so they are not copies of this chain.
    - No behavior change: the existing BarButtonFocusRingHostedTests (Send, Stop and Dictation report a circle) are the guard, and they pass. No PNG changed.
  timestamp: 2026-11-08T18:31:51.841948+00:00
- actor: claude-code
  id: 01m6y6wsgwwkdhg6xhda1pjmje
  text: |-
    ### implement — changed
    - evidence: 3 files — new Sources/AgentViewKit/Theme/CircleAction.swift, Sources/AgentViewKit/Input/DefaultPromptAccessory.swift, Sources/AgentViewKit/Input/SpeechInputButton.swift. `swift test`: 1075 + 50 passed. `swift test --package-path IntegrationTests`: 1045 tests passed, 5 known issues (FontRoleExpectationsTests); BarButtonFocusRingHostedTests passed. `swift test --package-path ScreenshotTests`: 33 passed, no PNG changed.
    - next: /review
  timestamp: 2026-11-08T18:31:54.140163+00:00
- actor: claude-code
  id: 01m6y75vhbrdfjv8vwsbfvempg
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (c80966e9): 0 findings, 0 confirmed, 0 refuted; 7 pairs attempted, 0 failed. All prior findings are checked.
    - next: none. The task is in done.
  timestamp: 2026-11-08T18:36:51.115723+00:00
- actor: claude-code
  id: 01m6y765nja37dk6jjbtwjt5wj
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — 3 files (1 finding fixed)
    - test: green — swift test 1075+50; IntegrationTests 1045 (5 known); ScreenshotTests 33
    - commit: c80966e9
    - review: clean — 0 findings; task in done
    - push: not done; the AVK user decides the push
  timestamp: 2026-11-08T18:37:01.490232+00:00
position_column: done
position_ordinal: ffffffcc80
title: 'Button focus ring follows the bezel: use EK .editorButtonBorderShape (EK ^zw631dd)'
---
EK ^zw631dd is on EditorKit main 4e673e2c. The ring of a landed EditorButton now follows the real bezel of its style. SwiftUI cannot read a host `.buttonBorderShape(_:)`, so a kit must tell EditorKit the shape with `.editorButtonBorderShape(_:)` (EditorSwiftUI, Sources/EditorSwiftUI/EditorButtonBezel.swift; cases include `.capsule` and `.circle`). Otherwise the ring is a 6 pt rounded rectangle around a capsule or circle bezel.

Other EK changes in ^zw631dd: `.selectableCapsule(isSelected:)` and `.selectableCapsule(isSelected:isFocused:)` for a capsule item; an infinite radius is also a capsule; a click on a button with `.focusesScopeOnClick()` focuses the leaf scope of the button.

## Changes in AgentViewKit
Step 0: Update the EditorKit pin to 4e673e2c or later in the root package, IntegrationTests and ScreenshotTests (`swift package --package-path <p> update EditorKit`). Package.resolved is git-ignored.
1. Sources/AgentViewKit/Theme/FloatingGlassAction.swift:24: use `.editorButtonBorderShape(.capsule)` in place of `.buttonBorderShape(.capsule)`, if `.editorButtonBorderShape` also sets the SwiftUI bezel shape; else keep both. Read the EK source to decide.
2. Sources/AgentViewKit/Input/DefaultPromptAccessory.swift:131 and Sources/AgentViewKit/Input/SpeechInputButton.swift:71: the same for `.buttonBorderShape(.circle)` → `.editorButtonBorderShape(.circle)`.
3. Find other buttons in a scope whose bezel is not the default (for example `.agentControlScope` users) and check their ring shape.
4. Check if a capsule item of AVK (for example PendingRequestCountBadge, InlineCitation) is selectable or focusable. If yes, use `.selectableCapsule`. If no, no change.
5. Hosted test: the ring of a landed FloatingGlassAction is a capsule, and the ring of the speech button is a circle (read the ring shape from the scope, no pixels).
6. Record all screenshots again (`swift test --package-path ScreenshotTests`), check them, and give the changed PNG paths to the user.

Test rules: no clock/sleep/poll/retry/timeLimit/XCUITest; tests never show a window or take focus. No magic numbers, no duplicated code.

Commit only. Do not push: the user of AVK decides the push.

## Review Findings (2026-11-08 12:23)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 7 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Sources/AgentViewKit/Input/SpeechInputButton.swift:71` `reuse/reuse` — The new `.editorButtonBorderShape(.circle)` line repeats the round-button modifier chain of `DefaultPromptAccessory.circleActionButton`. The chain is `EditorButton` with the action look, `.editorButtonCaptions(.hidden)`, `.editorButtonBorderShape(.circle)`, `.accessibilityIdentifier`, and `.agentControlScope`. Two copies of this chain must change together when the round-button look changes. Move the shared round-button chain into one helper or modifier, for example a `View` extension that applies `.editorButtonCaptions(.hidden)`, `.editorButtonBorderShape(.circle)`, and the scope. Call it from both `circleActionButton` and `SpeechInputButton.body`. Keep the per-button parts (title, symbol, action, identifier, and the `SpeechInputButton` value and disappear handling) at the call sites.
