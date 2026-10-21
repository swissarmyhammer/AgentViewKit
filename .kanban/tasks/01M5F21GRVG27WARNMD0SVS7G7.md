---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5f25kpadh9e29sj859ne25v
  text: |-
    ### decision (testudoapp-4c) — the API shape is accepted
    - Use the environment modifier `.agentAttachmentInspector(.builtIn | .host($selection))`. `.builtIn` is the default.
    - An init parameter on AgentThreadView is not necessary.
    - The app applies the modifier one time at the root of each window, so each thread view in that window gets it. Thus more than one thread view can share one host selection binding; make sure this works (the selection belongs to the thread that the user pressed).
  timestamp: 2026-10-21T11:05:01.898309+00:00
position_column: todo
position_ordinal: b480
title: AVK-10 Let a host with its own inspector use AgentThreadView with no attachment inspector
---
Source: testudoapp-4c, TestudoApp card ^xt3ght2 (blocker). Rule D40 (the app has its own `.inspector`).

Problem: `AgentThreadView` always applies `.attachmentInspector(selection:)`, which is a SwiftUI `.inspector`. The TestudoApp layout is a NavigationSplitView with its own `.inspector`. The doc comment of the kit already warns against this combination. When a second tab opens, the app stops with NSGenericException "more Update Constraints in Window passes than there are views in the window". Three runs show the cause: with `AgentThreadView` the second-tab tests crash; with the same thread parts and no inspector they pass; with only `.attachmentInspector` added back they crash again.

Do:
- Add a public way for a host to turn off the built-in attachment inspector of `AgentThreadView`, and to get the attachment selection, so the host can show it in its own inspector (the app File inspector, APP-7). Recommended shape: one public modifier or environment value, for example `.agentAttachmentInspector(.builtIn)` (the default, the current behavior) and `.agentAttachmentInspector(.host($selection))`, where the host gets the selected attachment through the binding and the kit applies no `.inspector`.
- Keep the default behavior the same, so current hosts compile and behave as before.
- Keep the attachment commands (open, reveal, close) working in both modes; each control stays an EditorKit command (D108, D109).
- Update the README, the DocC of `AgentThreadView` and `attachmentInspector`, and plan.md.

Acceptance:
- A hosted test: with `.host($selection)`, a thread view in a host that applies its own `.inspector` has no kit inspector, and a press on an attachment sets `selection`.
- A hosted test: the default still shows the kit inspector, as before.
- A hosted test (or the demo app) with a NavigationSplitView that has its own `.inspector` and two thread views (two tabs) does not stop with the NSGenericException.
- No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-10