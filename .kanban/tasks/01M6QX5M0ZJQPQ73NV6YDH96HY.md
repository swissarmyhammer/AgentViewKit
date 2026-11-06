---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6qy2dsnac3xcnerhnc3qnxy
  text: |-
    Diagnosis (hosted harness, AX frames read through the AX tree, AgentThreadView mounted in EK HostedViewHarness, EK aa469f7):

    - Repro: mount the thread in a NARROW window (120 pt), render, then setContentSize to 640 pt and render twice. The `agent-info-header` container keeps its first-layout size (96 x 272, the crumb wrapped at 120 pt) while every child moves to its wide frame (agent name 97.5 wide, breadcrumb 109.5 wide, outside the container). With no auth methods (no login prompt), `thread-floating-controls` does the same: 96 x 89.5 around a 576-wide `prompt-field-surface` - the 89.5 height matches Testudo's (1102, 988, 79.5, 89.5) exactly; 79.5 = Testudo's first pane width minus the 2 x 12 bar inset. With the login prompt in the bar the controls re-evaluate on resize and update, which is why the plain harness at a fixed width never showed it.
    - Steady-state (mounted at the final width) frames are correct for both containers. Only a resize after the first layout leaves the container stale.
    - NOT caused by 145c5cfd: with AgentInfoHeader.swift / SessionBreadcrumb.swift / BreadcrumbCollapse.swift checked out at 145c5cfd~1, the header container is also stale after a resize (96 x 45, only its origin moves). 145c5cfd changed the stale shape (the wrapped crumb makes it tall; the maxWidth frame pins the origin left) but not the defect. thread-floating-controls was untouched and is stale on both.
    - Minimal repro, plain SwiftUI, no AVK, no EK: `HStack { Text("Alpha"); Text("Beta gamma delta") }.padding(8).glassEffect(.regular, in: .rect(cornerRadius: 8)).accessibilityElement(children: .contain).accessibilityLabel("L")` in a 60 pt window, widen to 640: container stays 60 x 128 while the texts are 34.5 and 109.5 wide on one line. Same with the container INSIDE the glass content (the header's placement), with GlassEffectContainer + glassEffect, and with EK FloatingGlassContainer + floatingGlass(). NOT stale: the same row with no glass, with GlassEffectContainer alone (no glassEffect), with `.background(.regularMaterial)`. A glass in a `.background { Color.clear.glassEffect(...) }` updates the width but still keeps the first height (160 x 112).
    - So the 79.5-wide view is the SwiftUI `.glassEffect(_:in:)` layer: an accessibility container that holds (or is held by) a glassEffect keeps the size of its first layout. In EK that is `FloatingGlass.body` in Sources/EditorStyle/FloatingGlass.swift (`content.glassEffect(.regular, in: EditorSurface.shape(radius: style.radii.l))`), which both AVK bars use via `.floatingGlass()` (header in AgentThreadView.content; composer/PromptInputView in the floating controls). Not an EK focus ring, measuring view or scope modifier, and not AVK's maxWidth frame.
  timestamp: 2026-11-06T08:02:14.965653+00:00
- actor: claude-code
  id: 01m6qznhj2qwxw2zdjre4wmf4v
  text: |-
    ### implement — changed
    - evidence: a23af010 on worktree-agent-a61eadbd67fa43956, 1 file: IntegrationTests/Tests/IntegrationTests/Thread/ThreadBarAccessibilityFrameHostedTests.swift (2 tests: header and floating-controls AX frames contain each descendant element after a 120 -> 640 pt widen; AX-only, no mouse). RED on EK aa469f7 (both fail), GREEN on EK 6d95a74e. No AVK source change: the cause was EK FloatingGlass (^bavw691). An in-process AX hit test resolves correctly even with the stale frame, so the frame-containment form is the one that catches it.
    - root swift test: 1070 + 50 passed. ScreenshotTests build: ok. No AVK warnings.
    - IntegrationTests swift test: 1028 tests, 1 failure + 5 known issues. The failure is an EK REGRESSION from 1fe50719 (^bavw691): ThreadBarControlJumpHostedTests.theHitTestAtTheCenterOfEachBarControlAnswersTheControl(scrollPill) now answers the transcript row "assistant-message-...". It passes with EK pinned to aa469f7 and fails on 6d95a74e, both run alone. Likely cause: `.contentShape(.accessibility, Rectangle())` that 1fe50719 put on FloatingGlassContainer's content in Sources/EditorStyle/FloatingGlass.swift limits AX hit testing to the container's rectangle, and AVK's ConversationPill is an `.overlay(alignment: .top)` pushed above the stack by an alignment guide (AgentThreadView.floatingControls), outside that rectangle.
    - next: EK fixes the pill hit test; then re-run IntegrationTests.
  timestamp: 2026-11-06T08:30:09.986238+00:00
- actor: claude-code
  id: 01m6qzp78yc72jnn27k9jssv85
  text: |-
    The cause is EK's FloatingGlass, fixed as EK ^bavw691 in 6d95a74e. AVK needs no source change. The regression test is a23af010 on worktree-agent-a61eadbd67fa43956, and it passes on 6d95a74e.

    This card is blocked: EK 1fe50719's `.contentShape(.accessibility)` breaks the AVK hit test `ThreadBarControlJumpHostedTests…(scrollPill)`, because the pill overlay overflows the container. That's reported to editorkit-b5. Merge the test once EK fixes it.
  timestamp: 2026-11-06T08:30:32.222832+00:00
position_column: done
position_ordinal: ffffffc080
title: 'AgentInfoHeader and thread floating controls: the accessibility frame doesn''t contain its row'
---
Reported by Testudo against AVK 9c4b392, since 145c5cfd (^dax7gt3). Three Testudo UI tests fail, and VoiceOver's rectangle is wrong.

XCUI frames:
- `agent-info-header` group: (1102, 350, 79.5, 112). Its children are the agent name at (1138, 358, 125, 16), the version at (1271, 359, 72, 15) and `session-breadcrumb` at (1366.5, 358, 46, 16).
- Expected: the frame wraps the one-line row, about x 1102–1424 and y 350–382.
- `thread-floating-controls` shows the same 79.5-wide frame (1102, 988, 79.5, 89.5) around a 516-wide `prompt-field-surface`. So the cause is probably shared: EK's floating glass container, a hidden measuring row, or the `.frame(maxWidth: .infinity, alignment: .leading)` that 145c5cfd added to the header row.

Testudo is also telling editorkit-b5. Work out whose fix it is. If EK's, ask EK and pick up their SHA.

- [ ] Find the cause: AVK, or EK's floating glass container
- [ ] Fix it, so the AX frame of each container contains its children
- [ ] Hosted test: an accessibility hit test at the centre of the row's children finds an element inside the header container, or the container's AX frame contains each child's AX frame. This is a hit test, through AX only
- [ ] Send Testudo (testudoapp-bf) the SHA