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
- actor: claude-code
  id: 01m5f2dkwhz47c8yx5ve5qnsm9
  text: |-
    ### research
    - `AgentThreadView.body` always applies `.attachmentInspector(selection:)` (Attachments/AttachmentInspector.swift), which is a SwiftUI `.inspector`. The selection is `InspectorSelection` from the environment, or the own `@State` selection of the view.
    - The press sources are `AttachmentView.select()` (synchronous, `selection?.select`) and `ImageView.select(data:)` (writes a file in a Task, then `selection.select`). `ArtifactView` uses `AttachmentView`.
    - The file actions Open, Reveal in Finder, Share, Save and Quick Look are in `AttachmentActions` (plain SwiftUI buttons in the content of `AttachmentInspector`). Close is the close of the inspector (a write of `false` to `isPresented` clears the selection). The kit has no attachment verb in `AgentCommandVerb`. D108 and D109 are TestudoApp decisions; they are not in this repo.
    - `SessionModel.sessionId` (`SessionId`, Hashable, Sendable) identifies the thread.
    - Plan: a public `AttachmentInspectorMode` (`.builtIn`, `.host(Binding<AgentAttachmentSelection?>)`), a public modifier `.agentAttachmentInspector(_:)`, and a public `AgentAttachmentSelection` (attachment + sessionId). In `.host` mode the thread view applies no `.inspector`; it puts an internal host target (binding + session id) in the environment, and `AttachmentView` and `ImageView` write to it.
  timestamp: 2026-10-21T11:09:24.241334+00:00
- actor: claude-code
  id: 01m5f2sz95wby8x711kt25v09r
  text: |-
    ### implementation and a check of the harness
    - New file `Sources/AgentViewKit/Attachments/AttachmentInspectorMode.swift`: public `AgentAttachmentSelection` (attachment + `sessionId`), public `AttachmentInspectorMode` (`.builtIn`, `.host(Binding<AgentAttachmentSelection?>)`), public modifier `.agentAttachmentInspector(_:)`. Internal: environment entry (default `.builtIn`), `HostAttachmentTarget`, `AttachmentSelectAction`, and the `ThreadAttachmentInspector` modifier that `AgentThreadView.body` applies.
    - `AttachmentView` and `ImageView` now select through `AttachmentSelectAction` (the host target first, then the `InspectorSelection`).
    - Discovery: `FoundationModelsACP` exports a type named `Content`, so a `ViewModifier` in a file that imports it must write `body(content: Self.Content)`. With a bare `Content`, the build fails with "does not conform to protocol 'ViewModifier'".
    - Check of the harness (one run, then reverted): the split-view tab test in `.builtIn` mode did NOT stop with the NSGenericException in the off-screen `HostedViewHarness`. It failed only on its checks: more than one inspector item, and the host selection stayed nil. Thus the test proves that the host mode leaves only the host inspector in the window (the cause that TestudoApp found in three runs) and that the selection carries the session of the pressed thread. It does not prove that the harness can show the exception. The test doc records this.
  timestamp: 2026-10-21T11:16:09.125148+00:00
- actor: claude-code
  id: 01m5f3jxgwmypas3wzyrm40k5q
  text: |-
    ### implement — changed
    - evidence: `swift test` 1487 tests in 187 suites passed, 2 known issues (existed before), only the mlx bundle warning (existed before). `Scripts/check-readme.sh` passed. The demo app did not change (it has no own inspector), so no xcodebuild.
    - files: Sources/AgentViewKit/Attachments/AttachmentInspectorMode.swift (new), Sources/AgentViewKit/Attachments/AttachmentInspector.swift (DocC), Sources/AgentViewKit/Attachments/AttachmentView.swift, Sources/AgentViewKit/Content/Blocks/ImageView.swift, Sources/AgentViewKit/Thread/AgentThreadView.swift, Tests/AgentViewKitTests/Attachments/AttachmentInspectorModeHostedTests.swift (new suite, 5 tests), Tests/AgentViewKitTests/Attachments/AttachmentInspectorHostedTests.swift (new helper `inspectorItems(in:)`), README.md (section "The attachment inspector" + snippet HostInspector), Examples/ReadmeSnippets/Snippets/HostInspector.swift (new, extracted), plan.md (§3.6).
    - public API added (additive, source compatible): `AgentAttachmentSelection`, `AttachmentInspectorMode`, `View.agentAttachmentInspector(_:)`. No init parameter. The default stays `.builtIn`.
    - discovery: a hosted test file must contain `.hostedSerially` as text (HostedSerialTraitTests). An extension of a suite in a new file fails that check, so the new tests are their own serialized suite that calls the helpers of `AttachmentInspectorHostedTests` through `typealias Shared`.
    - note for review: the file actions (Open, Reveal in Finder, Share, Save, Quick Look) are plain SwiftUI buttons in `AttachmentActions` today, not EditorKit commands. This card did not change them; they work in both modes because the host shows `AttachmentInspector`. Close in host mode is a write of `nil` to the host binding. If D108/D109 require EditorKit commands for these controls, that is separate work.
    - next: /review
  timestamp: 2026-10-21T11:29:46.524052+00:00
- actor: claude-code
  id: 01m5f6nwdh04z3k12eeedfvyay
  text: |-
    ### test — green
    - evidence: swift test, full suite, 1487 tests in 187 suites passed in 109.877 s, 2 known issues (the 2 that existed before), 0 failures, 0 skipped. PackageStructureTests ran (177 tests in 25 suites passed, 22.010 s). ReadmeSnippetsTests ran and passed. Scripts/check-readme.sh exit 0: "README gate passed". Only warning: the mlx bundle build warning that existed before. No new warning.
    - note: two earlier full runs stopped with no CPU use in RecordedSessionsAgentTests (a session resume that never returned). No file of AVK-10 is part of that test. The suite RecordedSessionsAgentTests alone passed (7 tests), and the third full run passed. No code changed during the runs. The stop happened while the machine was under high load.
    - next: review
  timestamp: 2026-10-21T12:23:49.425083+00:00
position_column: doing
position_ordinal: '80'
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