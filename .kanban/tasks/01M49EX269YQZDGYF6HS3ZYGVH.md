---
assignees:
- claude-code
depends_on:
- 01M4BHMJNEVT7DQ6KHVZTXQXVH
position_column: todo
position_ordinal: b280
title: Show the MCP servers and their status from the client model
---
## What
Owner decision (2026-10-06): the UI must show the connected MCP servers and the status of each server. This data comes from the observable state of the ACP client (FoundationModelsACPClient). It does not come from a kit store. Source: ACP v2 initialization, MCP part (https://agentclientprotocol.com/protocol/v2/initialization#param-mcp). In FoundationModelsACP `fe0d82d`, this is `MCPCapabilities` (`http`, `stdio`) and `MCPServerHTTP` / `MCPServerStdio` in the session requests.

FoundationModelsACPClient task k8skz98 gives this client API:
- `SessionModel.mcpServers`: a list of `MCPServerItem`. Each item has `name`, `transport`, `origin`, `server: MCPServer?` and `status`.
- `MCPServerTransport`: `.stdio`, `.http`.
- `MCPServerOrigin`: `.client`, `.config`.
- `MCPServerStatus`: `.notReported`, `.connecting`, `.connected`, `.failed(reason: String?)`, `.closed`.

The client sets the status from the `_mcp_server_status` session updates of the agent (client task d8d4384). The kit reads `mcpServers` in the view body. The kit keeps no copy of the list.

The pin task ^ztxqxvh moves the pins; this task starts after it.

Note: the kit tests send `_mcp_server_status` from the scripted agent. Thus the agent tasks (for example cbqsngc) are not necessary for the kit work.

The kit must not build a status of its own. The kit must not keep a copy of the list. The views keep view state only (for example selection, open state and a per-button "call in progress" flag).

- [ ] Delete `Sources/AgentViewKit/Connections/ConnectionStore.swift`. This removes `ConnectionStore`, the kit `ConnectionState` enum and its state machine, `Connection`, `ConnectionID`, `ConnectionActions` and the `connectionStore` environment value.
- [ ] Change `Sources/AgentViewKit/Connections/ConnectionsView.swift`. Read `SessionModel.mcpServers` directly in the body. Make one row for each `MCPServerItem`, in the order of the list. Show the empty state when the list is empty.
- [ ] Change `Sources/AgentViewKit/Connections/ConnectionRow.swift` and `Sources/AgentViewKit/Connections/ConnectionStatusChip.swift`. The row takes one `MCPServerItem`. The row shows the `name` and the `transport`. The chip shows the `MCPServerStatus` value directly, and the `reason` of `.failed(reason:)` when it is not nil. Do not map the client status into a kit enum.
- [ ] Change `Sources/AgentViewKit/Input/ToolToggles.swift`. Remove the initializer that reads the ambient `ConnectionStore`. Keep the initializer for a host list of tools. Remove the `ConnectionStore` text from the doc comment of `Sources/AgentViewKit/Input/DefaultPromptAccessory.swift`.
- [ ] Delete `Tests/AgentViewKitTests/Connections/ConnectionStoreTests.swift`. Change `Tests/AgentViewKitTests/Connections/ConnectionsViewHostedTests.swift` and `Tests/AgentViewKitTests/Input/ToolTogglesHostedTests.swift` so that they do not use `ConnectionStore`.

Note: `Sources/DemoSupport/ACPDemoSession.swift` also uses `ConnectionStore`. Task ^r39tgz5 removes `ACPDemoSession`. If that file is still in `Sources/` when this task starts, remove its use of `ConnectionStore` in this task.

## Acceptance Criteria
- [ ] No file in `Sources/` contains `ConnectionStore`.
- [ ] A change of a server status in `SessionModel.mcpServers` shows in the row of that server, with no other step.
- [ ] The rows come from `SessionModel.mcpServers`: one row for each server, in the order of the list.

## Tests
- [ ] `Tests/AgentViewKitTests/Connections/MCPServersHostedTests.swift`: one hosted test for each acceptance criterion, with the scripted agent. The scripted agent sends `_mcp_server_status` session updates. Use this shape: `{"sessionUpdate":"_mcp_server_status","name":"files","transport":"stdio","origin":"client","status":"failed","reason":"..."}`. The scripted agent reports two MCP servers, then changes the status of one server.
  - [ ] Test 1: host `ConnectionsView` with only the client model in the environment. Set no kit store. The view shows the rows of the scripted servers.
  - [ ] Test 2: the scripted agent sends a `_mcp_server_status` update with `"status":"failed"` and a `reason` for the server `files`. The hosted test finds the row of `files` and checks that its chip shows the failed status and the reason.
  - [ ] Test 3: the scripted agent reports two servers. The view shows two rows with the names and the transports of the list, in the order of the list.
- [ ] `Tests/PackageStructureTests/RemovedVocabularyTests.swift`: add `ConnectionStore`, `ConnectionActions` and `ConnectionID` to the removed-names list. Do not add `ConnectionState`, because the client also has a type with that name. This test fails before the removal and passes after it.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.