---
comments:
- actor: claude-code
  id: 01m2nz1r99pnyatmjwrcprc5yt
  text: 'Note from ^a9ptv4s (SessionListView): the sidebar must make `ACPSessionList(connection:cwd:)` from the ACP connection and give it to `SessionListView(provider:onSelect:onNewSession:onDelete:)`. Give `onDelete: provider.delete` only when the agent sends the `session.delete` capability. `onSelect` must load the selected session (session/load or session/resume) and bind ACPThreadSource to it. The in-memory agent must answer `session/list`, or the sidebar shows the failure message.'
  timestamp: 2026-09-16T20:38:05.353672+00:00
- actor: claude-code
  id: 01m2p34mvv60ppz5hpx0va8hfd
  text: 'Requirement from ^8xcmw7e (done): the settings sheet must show `ConfigOptionsView(options: thread.configOptions, style: .form)`, and the toolbar can show `ConfigOptionsView(options: thread.configOptions)` (menu style). Both views take the options list; read the thread in the host view so that the views update when the source replaces the list.'
  timestamp: 2026-09-16T21:49:34.459615+00:00
- actor: claude-code
  id: 01m2q1390s5jx1g627005f4wy7
  text: |-
    ### finish iteration 1 — stuck

    - implement: done on the branch `wip/ny9e8rr` (commit 95117cc). `Sources/DemoSupport` (non-product target) holds `ScriptedWireAgent` (moved from the ACP tests; the time limit `bounded(_:)` stays in the tests), `InMemoryDemoAgent`, `ACPDemoSession`, and `DemoLaunchOptions`. `SessionUpdateMapping.authMethod(_:)` is new. `Examples/AgentViewKitDemo` has the app, the ACP tab (sidebar, thread, status views, composer, config menu), the settings sheet (`ConnectionsView`, `AgentAuthView`, form `ConfigOptionsView`), and `Tests/ACPTabEndToEndTests.swift`. `Examples/Scripts/xcodeproj_generator.rb` and `Scripts/test-examples.sh` are new.
    - test: `timeout 1500 swift test` passes: AgentViewKitTests 1137, AgentViewKitACPTests 120 (was 102), AgentViewKitRouterTests 71, PackageStructureTests 23, AgentViewKitFoundationModelsTests 44. `xcodebuild -scheme AgentViewKitDemo build` and `build-for-testing` pass. The app starts with `--in-memory-agent`. The UI tests do not start: "The test runner failed to initialize for UI testing. (Underlying Error: Authentication canceled. System authentication is running.)". `automationmodetool` says: "Automation Mode is disabled. This device requires user authentication to enable Automation Mode."
    - commit: 95117cc on `wip/ny9e8rr`, not on main.
    - review: not run, because the test step is red.

    Blocker: ^3w1hxha. A person must turn on UI Automation Mode (`sudo automationmodetool enable-automationmode-without-authentication`, or approve the prompt one time). Then run `timeout 900 Scripts/test-examples.sh` on `wip/ny9e8rr`, merge the branch, and continue with the review.
  timestamp: 2026-09-17T06:33:06.841260+00:00
- actor: claude-code
  id: 01m2x22dw8egb9yeekxypq680w
  text: |-
    ### note — breaking changes on main since the branch
    When you merge `wip/ny9e8rr`, change these in the demo:
    - `AgentThreadView(thread:)` no longer exists. Use `AgentThreadView(thread:actions:)` (^33tg6p6, Docs/decisions/required-thread-actions.md). The `threadActions` environment default is `nil`.
    - EditorKit is pinned at 235cbb7, and code blocks use the TextMate grammars (^3t64xef). Call `GrammarBundle.register()` at launch if the demo must not wait on the first code block.
    - The README task ^3swhtbj must say that the kit speaks ACP v2 only and that the demo uses the in-memory agent.
  timestamp: 2026-09-19T14:45:34.216713+00:00
depends_on:
- 01M21AGCKBQJRDAVFZD6Q9P7JZ
- 01M21AH4QCEFEBPTZ8GR061H51
- 01M21AF2MV082PZY3Q6H0M4YCM
- 01M21AK7DBCBMDHK82JY5RA063
- 01M21AKJEX1RNADX8WD5A3WMGC
- 01M21AMHZJF4YSR0ZFYVV6B45Q
- 01M21AMS98JY4Y4QVS9CZF33YZ
- 01M21AFDM0RPN9SPB5D35Y2FDR
- 01M21AP2GPQ4HC9W00WHNN42RG
- 01M21AJH0W89P9G5YCCHWPNT7D
- 01M21APWYC29JSXC8HEA9PTV4S
- 01M21AJZC6XH6BVT0A38XCMW7E
- 01M2Q1262EB4YH609KZ3W1HXHA
position_column: todo
position_ordinal: c680
title: 'Demo app: ACP tab, sidebar, settings sheet, and the in-memory agent end-to-end test (plan §1, §9)'
---
## What
Create `Examples/AgentViewKitDemo/`, a macOS app with an `xcodeproj` generated the same way as `../EditorKit/Examples/Scripts/xcodeproj_generator.rb`. The FoundationModels tab and the README come in their own tasks.

- The "ACP" tab: spawns an ACP agent through `AgentProcess` from a configurable command (default: the `acp-agent` binary from `../FoundationModelsACPAgent`), binds `ACPThreadSource` and `ACPThreadActions`, and shows `AgentThreadView`, `PromptInputView` with `ConfigOptionsView` and `PermissionModePicker`, `ContextUsageView`, `TaskListView`, `StateBanner`, and `SessionListView` in a sidebar.
- A settings sheet with `ConnectionsView` and `AgentAuthView`.
- Launch argument `--in-memory-agent`: the app binds the scripted in-memory agent from the ACP test target (moved into a shared `DemoSupport` module) so the end-to-end test needs no external binary.
- `Scripts/test-examples.sh`: generates the project, builds, and runs the UI tests.

## Acceptance Criteria
- [ ] The app builds with `xcodebuild -scheme AgentViewKitDemo build`.
- [ ] With `--in-memory-agent`, a send of "hello" produces an assistant message element in the thread.
- [ ] The settings sheet mounts `ConnectionsView` and `AgentAuthView`.

## Tests
- [ ] `Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift`: the send-and-receive flow and the settings sheet through `XCUIApplication`.
- [ ] `Scripts/test-examples.sh` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.