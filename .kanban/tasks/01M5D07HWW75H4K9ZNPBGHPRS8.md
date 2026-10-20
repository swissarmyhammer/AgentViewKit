---
assignees:
- claude-code
position_column: todo
position_ordinal: '8180'
title: AVK-7b Live subject on each agent scope
---
Design: AVK-7, D105 (b). Step 5 work.

Today the scopes call `.commandScope(segment:)` with no subject (Commands/AgentCommandScope.swift:70, Commands/AgentItemScope.swift:28). `AgentCommand.payload(at:)` (Commands/AgentCommands.swift:208) reads the item from the text of the segment id.

Do:
- Each scope gives its live object with `.commandScope(segment:subject:)`: the thread scope gives the `SessionModel`, a message scope gives its transcript entry, a request scope gives its `PendingPermissionRequest`.
- The agent commands read the item with `@FromTarget` (or the context subject), not from the segment id text. Keep the payload keys for hosts that dispatch by id.
- Keep the behavior of AVK-1: Copy Message copies the message of its scope, Approve and Reject answer the request of their scope.

Acceptance: the AgentCommandPlacementTests still pass; a new test shows that a command registered by another module (a test scope) reads the message entry through `@FromTarget` at an `agentMessage` path. #avk-7