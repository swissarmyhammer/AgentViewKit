---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4zyg6aqa38hv0d8tpnbhgdz
  text: |-
    ### Decisions from the step owner (after T0) — the accepted gaps for T3
    - G4: show Send and Stop together while cancel is available, so that the user can send a second prompt while the agent runs (DefaultPromptAccessory.swift:44-65).
    - G5: remove the turn words, and show the pending-request text when the session is idle with pending requests (StateBanner.swift:188-192,125-126,216-220).
    - G6: no change in step 7. It stays for ACPClient task 32.
    - G7: ScriptedWireAgent default order: the response first, then the user_message echo, then running.
    - G8: InMemoryDemoAgent wire form in the new order. Change the test theInMemoryAgentGivesAMessageIdAndOneEchoBeforeTheResult to the new order. Delete nothing.
    - G9: InMemoryDemoACPAgent cancel sends the cancelled idle and $/cancel_request for its open requests; correct the doc comment.
    - G10: add one ACPAgent-like gallery session (idle with pending requests). Keep the requires_action sessions for other agents.
    - G11: fixed-order tests for running and idle with no prompt open, an idle after background work only, two open prompts that one idle ends, a compaction entry after the prompt ended.
    One change for each gap, each with a fixed-order test.
  timestamp: 2026-10-15T14:12:17.879463+00:00
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