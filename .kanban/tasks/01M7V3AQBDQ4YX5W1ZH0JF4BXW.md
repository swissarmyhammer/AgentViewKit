---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Navigation verbs of a thread in the unavailable state (D208 i)
---
Found during ^rnrfc8w. While a thread shows the unavailable message of the host (`threadUnavailable(_:)`), no list shows. The verbs of the group `navigate` that act on the list stay available: Next Prompt, Previous Prompt, Scroll to Bottom and Expand or Collapse All. They run on a list that does not show, so the user sees no result.

Decide with the host (testudoapp-9a) if these verbs also get the reason "The session is not available." in the unavailable state. If yes: add them to the gate in `AgentCommandTarget.unavailableSessionReason(of:)`, add a unit test for each verb, and update ARCHITECTURE.md "Read-only thread". The session verbs (Go to Parent Session and the others) act on the session tree, not on the list.