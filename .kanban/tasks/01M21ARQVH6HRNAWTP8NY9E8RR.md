---
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
position_column: todo
position_ordinal: ad80
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