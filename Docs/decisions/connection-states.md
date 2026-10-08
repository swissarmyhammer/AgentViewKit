# Connection states and the connections list

status: accepted
date: 2026-09-16, changed 2026-10-08 (task ^g95wwbs)
plan: plan.md §3.4, §12

## Question

The kit shows two kinds of connection: the connection to the ACP agent, and
the connection of the agent to each MCP server of a session. Which states
does each kind have, and which view shows them?

## Decision

The kit keeps no connection state of its own. Both kinds of state are in the
client models of FoundationModelsACPClient, and the views read them directly
(`Docs/decisions/acp-client-kit.md`, section "Binding rule").

### The agent connection

The agent connection states are `ConnectionModel.state`, a
`ConnectionState`:

| State | Meaning | `AgentConnectionBanner` |
|---|---|---|
| `.disconnected` | The start value, and the value after the connection closes. | A banner tells that no connection to the agent is open. |
| `.connecting` | `connect(over:logger:bufferLimits:client:)` runs. | No banner. |
| `.connected` | The connection is open. | No banner. |
| `.failed` | The connection failed, with the error. | A banner tells that the connection failed, with the text of the error. |

- The model changes the state. The kit does not set it and has no table of
  allowed edges.
- When the connection closes, the model closes each open `SessionModel`
  (each one gets `isClosed`, and its pending requests are cancelled).
  `SessionStreamBanner` then shows the closed state of the session.
- The model never connects again on its own. Thus the banner has no button.
  The host connects again with a new transport. After a terminal sign-in,
  the host gives the `agentReconnect` hook (`acp-client-kit.md`, section
  "Host hooks").
- The text of each banner has its own accessibility identifier:
  `agent-connection-disconnected` and `agent-connection-failed`.

### The MCP servers of a session

The status of each MCP server is the `status` of an `MCPServerItem` in
`SessionModel.mcpServers`, an `MCPServerStatus`:

| Status | Label | Dot color of `AgentTheme.statusColors` |
|---|---|---|
| `.notReported` | Not reported | `pending` |
| `.connecting` | Connecting | `running` |
| `.connected` | Connected | `completed` |
| `.failed` | Failed, with the reason as the value and the help tag | `failed` |
| `.closed` | Closed | `cancelled` |

- `ConnectionsView` reads `SessionModel.mcpServers` of the `sessionModel`
  environment value in its body. It shows one `ConnectionRow` for each
  server, in the order of the list. It shows an empty state when the
  environment has no session model or the list is empty.
- `ConnectionRow` shows the `name` and the `transport` of the server
  (`stdio` or `HTTP`) and a `ConnectionStatusChip` with its `status`.
- The status chip has the static text trait. An element with no role does
  not give its accessibility value, and the value of a failed chip is the
  reason.
- `ToolCallView` shows a `ConnectionStatusChip` for a tool call that waits
  for a server, when the host gives `toolCallConnectionState`. ACP does not
  link a tool call to a server, so only the host can give that link.

## Removed

The earlier decision of 2026-09-16 described a kit `ConnectionStore` with six
states, an edge table, Connect and Disconnect buttons, tool toggles and an
in-thread `AuthorizationView` card. No ACP producer feeds these values, and a
store of the kit is parallel state. The ACP client kit removed them. The MCP
authorization of a server is the work of the agent. The kit shows the status
that the agent reports.
