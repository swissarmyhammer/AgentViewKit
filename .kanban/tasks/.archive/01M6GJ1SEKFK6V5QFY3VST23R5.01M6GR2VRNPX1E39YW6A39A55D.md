---
comments:
- actor: wballard
  id: 01m6gp1y86qwjvnfsa482mtcdk
  text: |-
    DECISION (user, 2026-11-03): the agent is a session AND a tool, so it has the behaviors of both. ACP does not link the tool call to the child session, so we add a link in `_meta`, using the SAH extension pattern of the wire package (FoundationModelsACP `SAH/SAHMeta.swift`: payload types under `_meta.sah`). Card for the payload type: see the FoundationModelsACP board, "SAH meta payload that links an agent tool call and its child session".
    THE LINK:
    - On the `subagent_update` of a child: `_meta.sah.agentRun = { toolCallId }`, the id of the `agents` tool call that started the child (the SDK tool call id; the Router record has it as `agentSpawn.parentToolCallId`).
    - On the `tool_call` / `tool_call_update` of that `agents` call: `_meta.sah.agentRun = { sessionId }`, the child session id.
    THE REMOVAL RULE: a finished child is removed. ACP has no removal message. The agent sends none. The CLIENT removes a child from the tree when its linked tool call reaches a final status (completed, failed or cancelled). The agent must therefore send the final `tool_call_update` AFTER the last update of the child and after its final `state_update` (idle), so the client never drops a child that still has traffic coming.
    AGENT: put the link on both messages; keep the order above; the link is also sent in the replay and in the post-response snapshots of a restored child. A child that has no known tool call (a host-started run) carries no link, and stays until its parent closes.
    CLIENT: read the link; `SessionModel` gets `startedByToolCallId` and a tool call entry gets `childSession`; remove the child (set `isClosed`) when the linked tool call is final; keep the child if the link is missing.
    VIEWS: the `agents` tool row in the parent thread is a link that jumps to the child session while it exists; after removal the row stays as history and shows the result.
    Acceptance criteria to add: the link is on both messages; the child is removed on the final tool call status; no child traffic after its removal; a child without a link is not removed; replay and snapshots carry the link; cancel through `tool_call/cancel` and through `session/cancel` on the child id reach the same run.
  timestamp: 2026-11-03T12:27:29.414378+00:00
- actor: claude-code
  id: 01m6gr2tk0p6d94e9k71gr9vff
  text: 'Split on 2026-11-03 into 01M6GR0P93GSSX2D63SJ6RGWZ3 (fixtures), 01M6GR1APG5GDGEJHC4KKY18P6 (breadcrumb), 01M6GR1RR24763YSQ7QRYZEW6G (commands and jump), 01M6GR29M97NTFGJYQXNWT0Y44 (accessibility and acceptance). Decision record: Docs/decisions/sub-agent-sessions.md. Use the new cards.'
  timestamp: 2026-11-03T13:02:55.584041+00:00
position_column: todo
position_ordinal: '80'
title: 'Show a session and its nested sub-sessions: N-level breadcrumb in AgentInfoHeader, commands, jump, and nested test fixtures'
---
## What
Show a session and its sub-sessions in AgentViewKit as a hierarchy that the user moves in with a breadcrumb. The agent will announce each sub-agent as an ACP v2 child session (RFD "Subagent Sessions"). The client model (FoundationModelsACPClient card `01M6GH6FH41C6VSFC3QRT8H1FS`) will give `SessionModel` the fields `parent`, `children`, `ancestors`, `siblings`, `descendants`, `workState`, and `needsAttention`. This card depends on that card (a dependency across boards cannot be set; start after it is done). The views read those fields and keep no copy.

### 1. N-level breadcrumb
Extend `Sources/AgentViewKit/Connections/AgentInfoHeader.swift`. Today it is "Agent > Session", and the host gives `sessionTitle` as text. It floats on glass in the top bar of `AgentThreadView` (`.safeAreaBar(edge: .top)`, `.floatingGlass()`).
- Replace `sessionTitle: String?` with the `SessionModel` that the thread shows. The crumbs are the agent, then `ancestors`, then the session.
- Each crumb has a dropdown (a menu) with the siblings at that level, like the org/repo path bar of GitHub. Each choice shows `title`, `workState`, and the pending request count (`PendingRequestCountBadge`).
- A crumb shows a state mark when `needsAttention` is true, so a question from a deep sub-agent shows on its ancestors.
- A long path: the middle crumbs collapse to "..." with a dropdown. The agent segment keeps the higher layout priority.
- Which session a window shows is VIEW state (in the host or in `AgentThreadView`), not model state. Two windows can show different children of one connection.
- If the session you show is removed, fall back to its parent.
- `StateBanner` follows the shown session. When a descendant of the shown session needs the user, the banner says so and has a button that jumps to it.
- Keep the accessibility rules of the header: one header element, a label that names the path, and each dropdown reachable with VoiceOver.

### 2. EditorKit commands and jump
Follow `Sources/AgentViewKit/Lists/AgentRowListCommands.swift` and `Sources/AgentViewKit/Commands/` (EditorCommands scopes, `nav.*`, `FocusPath`, `AgentKeymap`).
- The breadcrumb gets its own command scope, so the crumbs take keyboard focus.
- Commands: go to parent, open child, next sibling, previous sibling, and jump.
- Jump is a quick-open list over `descendants` (and the ancestors), filtered by name, that shows the path of each entry, such as "Agent > Reviewer > Linter".
- Add the new commands to `AgentCommands`, `AgentKeymap`, and the command placement (menus), and give each an accessibility name.

### 3. Nested fixtures and acceptance tests
The fixtures are flat today: `ScriptedSession` (`Sources/AgentViewKitTestSupport/ScriptedSession.swift`) has one session id; `RecordedSessionsScenario` lists sessions flat; the demo agents script one session.
- `ScriptedSession`: helpers for `subagent_update`, child events with the child id, child `state_update`, and a child permission request. These need the wire types from FoundationModelsACP (not done yet; being decided in a separate session).
- `DemoAgent` / `ScriptedWireAgent` (`Sources/AgentViewKitDemoSupport/`): a script with a root, a child, and a grandchild, for the gallery and the UI tests.
- `RecordedSessionsScenario`: a recording whose Router record has `agentSpawn` (the FoundationModelsACPAgent board has a task for the replay, tag `subagents`), to test resume with replay.

## Acceptance Criteria
- [ ] The breadcrumb shows the full path of a chain of three sessions, and collapses the middle crumbs when the path does not fit the width of the bar.
- [ ] Each dropdown lists the siblings at its level with state and request count.
- [ ] A question from a grandchild marks the crumbs of its ancestors, and answering it clears the mark.
- [ ] Go to parent, open child, next and previous sibling, and jump work with the keyboard and from the menus.
- [ ] Jump lists all descendants with their paths and opens the chosen one.
- [ ] A removed child that is shown sends the view to its parent.
- [ ] The banner of the root tells of a waiting descendant and its button jumps to it.
- [ ] VoiceOver reads the path, and each dropdown is reachable.

## Tests
- [ ] `Tests/AgentViewKitTests/Sessions`: breadcrumb path, collapse, dropdown content, removal fallback, with the nested demo agent.
- [ ] `Tests/AgentViewKitTests/Commands`: the five commands, the scope focus, the jump list and filter.
- [ ] `Tests/AgentViewKitTests/Status`: needsAttention marks and the banner button.
- [ ] `Tests/AgentViewKitTests/Accessibility`: the label and value of the header for a chain of three sessions.
- [ ] Run the package test command (`swift test --filter "Sessions|Commands|Status|Accessibility"`). All pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Note on size
This card is large (three concerns). When the client card is done, split it along sections 1, 2, and 3 with `depends_on`: the fixtures first, then the breadcrumb, then the commands. #subagents