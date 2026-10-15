---
assignees:
- claude-code
depends_on:
- 01M4ZQTYBRCAQQP8V7VWF0YM0J
position_column: todo
position_ordinal: '8380'
title: 'Mail step 7 T3: Close the other accepted gaps of T0, and make the demo agents follow the new ACPAgent order'
---
Close the other gaps of T0 that the step owner accepts. Make one change for each gap, with a fixed-order test for each (no clock wait, sleep or poll).

The demo agents (ScriptedWireAgent, InMemoryDemoACPAgent) follow the new order where they model ACPAgent: the prompt response at once with its messageId, then the user_message echo, then running, then the work; running and idle also with no prompt open; an idle with no stop reason after background work only; no requires_action; the cancelled idle can come after the prompt response; $/cancel_request for an ended question; the /compact entry can come after the prompt ended.

Keep the general behavior for other ACP agents (for example the .requiresAction display).

Ask the step owner before a decision that is not in the plan. Commit with AgentViewKit green. Report after the task. Write all text in STE. #mail-step-7