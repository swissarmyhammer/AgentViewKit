---
assignees:
- claude-code
depends_on:
- 01M51BCMH8VHWE68GXDERGVEFT
position_column: todo
position_ordinal: 9f80
title: 'Elicitation task 39: show who asks on each deck card'
---
elicitation-plan.md task 39 (who asks). Before this card, the design card ^aqqthfk said that task 39 waits for phase 4. Write all text in STE.

## Data (ACPClient main 6e2332b, from the step owner)
- `PendingElicitation.agentPath: [String]`. It is empty when the agent sends no path. The agent adds no root, so the deck adds its own root label, for example "root › reviewer".
- `PendingElicitation.source: String?`: "runCode", or an MCP server name. MCP names come later from Multitool.
- New: `SessionModel.withdrawnRequests` and `ConnectionModel.withdrawnRequests: [WithdrawnRequest]` (id, request, reason), and `dismissWithdrawn(_:)`, for a request that the agent withdrew.
- The pending lists are now in wire order. The hosted deck tests can keep their one-by-one sends.

## To do
- [ ] Update the ACPClient dependency to 6e2332b or later. First make sure that its CI is green.
- [ ] Write the design for the "who asks" line on each card (agent path with the root label of the deck, and the source), and send it to the step owner before any code.
- [ ] Decide whether the deck shows a short notice for a withdrawn request, or whether a new card does it. Tell the step owner.
- [ ] Tests with the step 7 rules: fixed order; no clock wait, sleep, poll, retry or timeLimit; render() and event waits.

Do this card after cards 38, 40 and 41.

#elicitation-phase-6