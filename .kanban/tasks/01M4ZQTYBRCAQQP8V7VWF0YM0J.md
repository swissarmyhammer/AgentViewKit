---
assignees:
- claude-code
depends_on:
- 01M4ZQTVZC2TE4TJBSADH5H115
position_column: todo
position_ordinal: '8280'
title: 'Mail step 7 T2: Announce "Response complete" only for the idle that ends a user prompt (elicitation-plan task 48)'
---
elicitation-plan.md task 48 (needs ACPAgent task 49, which is done).

Announce "Response complete" only for the first idle after the user_message echo of a user prompt (find the prompt by its messageId). Do not announce on each change to idle (ThreadAccessibility.turnAnnouncement).

An idle from background work (no user prompt ended) announces nothing.

Tests: a fixed-order test for each case (the first idle after the echo of a user prompt announces; an idle from background work does not announce; a later idle with no new prompt does not announce). No clock wait, sleep or poll.

Commit with AgentViewKit green. Report after the task. Write all text in STE. #mail-step-7