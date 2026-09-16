# Connection states and the connections list

status: accepted
date: 2026-09-16
plan: plan.md §12

## Question

plan.md §12 names six connection states. It does not give each allowed
edge. Which transitions does `ConnectionStore.transition(_:to:)` accept, and
what does the list show for each state?

## Decision

The store accepts only the edges in this table. Each other edge does not
change the store and writes an error entry to the `AgentViewKit` log, category
`ConnectionStore`.

| From | To |
|---|---|
| `disconnected` | `connected`, `needs-auth`, `error` |
| `connected` | `needs-auth`, `expired`, `error`, `disconnected` |
| `needs-auth` | `authenticating`, `error`, `disconnected` |
| `authenticating` | `connected`, `needs-auth`, `error`, `disconnected` |
| `expired` | `authenticating`, `needs-auth`, `error`, `disconnected` |
| `error` | `connected`, `needs-auth`, `error`, `disconnected` |

The reasons for the edges:

- A connect from `disconnected` gets a success, a `401`, or a different
  failure.
- A `401` or a `403 insufficient_scope` reply on a connected server gives
  `needs-auth`. This is the step-up case. A refresh failure gives `expired`.
- The Connect action on `needs-auth` or `expired` opens the browser, so the
  state goes to `authenticating`. A cancelled browser session goes back to
  `needs-auth`. A successful retry goes to `connected`.
- The Disconnect action goes to `disconnected` from each state that is not
  `disconnected`. An `error` can go to `error` with a new text.

## Other choices

- `ConnectionState` has no `unknown` case. The host makes the state; the kit
  does not read it from a wire string. `ThreadState` uses the same rule.
- When a `ConnectionActions` call throws, the store moves the connection to
  `error` with the text of the error.
- The accessibility identifier of a tool toggle is
  `connection-tool-<connection id>-<tool id>`. Two MCP servers can have a tool
  with the same name, so the tool identifier alone is not unique.
- The Connect button shows for `disconnected`, `needs-auth`, `expired`, and
  `error`. The Disconnect button shows for `connected` and `authenticating`.
- A tool toggle uses the stock toggle style, a check box. On macOS 27 the
  switch style gives no accessibility label for the switch.
- The status chip has the static text trait. An element with no role does
  not give its accessibility value, and the value of an `error` chip is the
  error text.
