---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffd580
title: Background tool call stays live until its real end
---
Defect from the user (OpenTestudo): a background tool call shows the green check when the tool returns the pending envelope. The call is done only when the background work ends. Root fix is in FoundationModelsACPAgent (foundationmodelsacpagent-30): the call stays `in_progress` with `_meta.sah.backgroundRun = {"completionToken": ...}` until the final status on the same toolCallId.

AVK work (start when the agent confirms the `_meta` shape):
- Caption "Running in the background" while the call has the background marker and is not final.
- No live spinner for a stale call (the agent connection ended, or the session is idle and the call is not in the `background` list of agentState). Show the unknown/lost mark.
- BackgroundRunScript: a background call that stays in_progress through `idle`, then becomes completed or failed.
- Unit test first: after the idle the row is inProgress and live; after the final update it shows completed (or failed).
- FoundationModelsACPClient has no `ToolCallEntry.backgroundRun` or `isStale` yet. Stopgap: compute them in AVK from `ToolCallEntry.meta` and `SessionModel.agentState?.background`. #bug