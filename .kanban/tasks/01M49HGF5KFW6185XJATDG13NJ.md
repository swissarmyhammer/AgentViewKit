---
assignees:
- claude-code
position_column: todo
position_ordinal: b580
title: The host InitializeRequest gives only the capabilities that the kit supports
---
## What
Rule: the agent streams to FoundationModelsACPClient over ACP. The client keeps an observable state. The kit views bind directly to that state and keep no state or logic of their own.

ACP v2 tells a client to advertise only the capabilities that it supports. At this time each host makes its own `InitializeRequest`:
- `Sources/DemoSupport/ACPDemoSession.swift:110` (`initializeRequest`) sends `ACPClient.advertisedCapabilities`.
- `Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift:21` sends `ACPClient.advertisedCapabilities`.
- `Sources/AgentViewKitTestSupport/ScriptedSession.swift:134` sends no capabilities.
- The in-process helper does not exist yet. Task ^96pte46 adds it. That helper must use the request of this task.

`ACPClient.advertisedCapabilities` tells what the client models can do. It does not tell what the kit shows. The kit shows the form mode in `ElicitationView` and the URL mode in `ElicitationURLConsentView`. The kit has no terminal runner yet, so it must not send `auth.terminal`.

Subtasks:
- [ ] Add `Sources/AgentViewKit/ACP/KitInitializeRequest.swift`. Add `ClientCapabilities.agentViewKit` and `InitializeRequest.agentViewKit(info:)`. The request sets `info`, `protocolVersion: ACPClient.supportedProtocolVersion` and `capabilities: .agentViewKit`.
- [ ] In `ClientCapabilities.agentViewKit`, set `elicitation.form` because `ElicitationView` shows the form mode. Set `elicitation.url` because `ElicitationURLConsentView` shows the URL mode. In the doc comment, write the view that each value needs.
- [ ] Do not set `auth`. Task ^83200vg and its host task add `auth.terminal` with the terminal runner.
- [ ] Use `InitializeRequest.agentViewKit(info:)` in `ACPDemoSession.initializeRequest`, in `ACPQuickStart.swift` and in `ScriptedSession.open`. Run `Scripts/extract-readme-snippets.sh`.

Size: 4 source files: `KitInitializeRequest.swift` (new), `ACPDemoSession.swift`, `ACPQuickStart.swift`, `ScriptedSession.swift`.

## Acceptance Criteria
- [ ] No file in `Sources/` or `Examples/` uses `ACPClient.advertisedCapabilities`.
- [ ] The demo, the README snippet and the test helper make their `InitializeRequest` with `InitializeRequest.agentViewKit(info:)`.
- [ ] The `initialize` frame on the wire has `params.info`, `params.capabilities.elicitation.form` and `params.capabilities.elicitation.url`. It has no `params.capabilities.auth`.

## Tests
- [ ] Add `Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift`:
  - Open a `ScriptedSession`. Read the frame with `agent.messages(method: "initialize")`. Check `params.info.name`, `params.capabilities.elicitation.form == {}` and `params.capabilities.elicitation.url == {}`. Check that `params.capabilities.auth` is absent.
  - Check that `ACPDemoSession.initializeRequest` is equal to `InitializeRequest.agentViewKit(info:)` with the `info` of the demo.
- [ ] Command: `swift test --filter KitInitializeRequestTests`. Then `swift test` and `Scripts/check-readme.sh` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.