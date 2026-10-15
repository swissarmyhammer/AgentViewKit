---
assignees:
- claude-code
depends_on:
- 01M4ZQTNC75QAVM51C2DBMNHSV
- 01M4ZYC293BWWZQ4N2JW8BPYHN
position_column: todo
position_ordinal: '8180'
title: 'Mail step 7 T1: Let the user cancel an idle session that has pending requests (elicitation-plan task 47)'
---
elicitation-plan.md task 47 (section 4, last item).

The user can cancel when the state is idle and the session has pending requests. Today AgentCommandTarget enables cancel only for running and requiresAction. ACPAgent reports idle while open questions and their runs exist, so the user must be able to cancel then.

Do not enable cancel for an idle session with no pending requests, because other ACP agents also use AgentViewKit.

Tests: one test for each case (idle with pending requests: cancel enabled; idle with no pending requests: cancel disabled). The tests use a fixed order, with no clock wait, sleep or poll.

Commit with AgentViewKit green. Report after the task. Write all text in STE. #mail-step-7